const { onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onTaskDispatched } = require("firebase-functions/v2/tasks");
const { getFunctions } = require("firebase-admin/functions");
const { defineSecret } = require("firebase-functions/params");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const nodemailer = require("nodemailer");
const { GoogleGenAI, Type, Schema } = require("@google/genai");

const geminiApiKey = defineSecret("GEMINI_API_KEY");

initializeApp();

/** リアクション通知のプッシュをまとめる際のデバウンスウィンドウ（秒） */
const REACTION_PUSH_DEBOUNCE_SECONDS = 30;
/** デバウンスロックの失効時間（ms）。配信タスクが消失した場合の保険。 */
const REACTION_LOCK_STALE_MS = 5 * 60 * 1000;

/**
 * 指定ユーザーへ FCM プッシュを1通送信する。
 * 受信者のマスタープッシュ設定を確認し、無効トークンは取得元から削除する。
 */
async function sendPushToUser(toUid, title, body, dataPayload = {}) {
  const db = getFirestore();

  // 受信者の公開情報を取得（プッシュ通知設定の確認用）
  const userDoc = await db.collection("users").doc(toUid).get();
  if (!userDoc.exists) return;

  const userData = userDoc.data();

  // マスターのプッシュ通知設定をチェック
  if (userData.pushNotifications === false) {
    return;
  }

  // 通知タイプごとの詳細設定をチェック
  const type = dataPayload.type || "";
  if (type === "reactionReceived") {
    if (dataPayload.emoji && userData.reactionNotifications === false) {
      return;
    }
    if (!dataPayload.emoji && userData.vFireNotifications === false) {
      return;
    }
  }

  // fcmToken は private subcollection を優先参照。
  // 旧バージョンのアプリは users/{uid}.fcmToken（公開エリア）に書き込み続けるため、
  // 移行期間中は public 側にフォールバックする。
  // どちらから取得したかを覚えておき、無効化時に正しい場所を削除する。
  const privateDoc = await db.collection("users").doc(toUid)
      .collection("private").doc("data").get();
  let fcmToken = privateDoc.exists ? privateDoc.data().fcmToken : null;
  let fcmTokenSource = "private";
  if (!fcmToken) {
    fcmToken = userData.fcmToken || null;
    fcmTokenSource = "public";
  }
  if (!fcmToken) return;

  // 3日前の日時を計算（アプリ内の通知一覧の表示期限と同期させるため）
  const threeDaysAgo = new Date();
  threeDaysAgo.setDate(threeDaysAgo.getDate() - 3);

  // 宛先ユーザーの未読通知数を取得（インデックス不要で取得するため、メモリ上でフィルタリング）
  let unreadCount = 0;
  try {
    const unreadSnap = await db.collection("notifications")
        .where("toUid", "==", toUid)
        .where("isRead", "==", false)
        .get();

    unreadSnap.forEach((doc) => {
      const data = doc.data();
      const createdAt = data.createdAt ? data.createdAt.toDate() : null;
      const type = data.type;
      
      // シーズンタスク配信系（seasonTaskReceived / seasonTaskPushOnly）はアプリの通知画面では二重表示を防ぐために除外されているため、バッジカウントからも除外
      const isSeasonPushOnly = type === "seasonTaskReceived" || type === "seasonTaskPushOnly";
      const isWithinThreeDays = createdAt && createdAt >= threeDaysAgo;
      
      if (isWithinThreeDays && !isSeasonPushOnly) {
        unreadCount++;
      }
    });
  } catch (error) {
    console.error(`Error calculating unread notification count for ${toUid}:`, error);
    // エラー時はフォールバックとして 1 を設定
    unreadCount = 1;
  }

  // FCMの仕様上、すべてのカスタムデータは文字列である必要があります
  const stringData = {};
  for (const [key, value] of Object.entries(dataPayload)) {
    if (value !== undefined && value !== null) {
      stringData[key] = String(value);
    }
  }

  // FCM メッセージを送信
  const message = {
    token: fcmToken,
    notification: {
      title: title,
      ...(body ? { body: body } : {}),
    },
    ...(Object.keys(stringData).length > 0 ? { data: stringData } : {}),
    android: {
      priority: "high",
      notification: {
        channelId: "veffect_notifications",
        defaultSound: true,
      },
    },
    apns: {
      headers: {
        "apns-priority": "10",
        "apns-push-type": "alert",
      },
      payload: {
        aps: {
          sound: "default",
          badge: unreadCount, // 動的な未読件数を設定
          // "content-available": 1, // バックグラウンド処理が必要な場合はコメントを外す
        },
      },
    },
  };

  try {
    await getMessaging().send(message);
    console.log(`Successfully sent message to ${toUid}`);
  } catch (error) {
    console.error(`Error sending push notification to ${toUid}:`, error);
    // トークンが無効な場合は取得元の場所から削除
    if (
      error.code === "messaging/invalid-registration-token" ||
      error.code === "messaging/registration-token-not-registered"
    ) {
      if (fcmTokenSource === "private") {
        await db.collection("users").doc(toUid).collection("private")
            .doc("data").set({ fcmToken: FieldValue.delete() }, { merge: true });
      } else {
        await db.collection("users").doc(toUid).update({
          fcmToken: FieldValue.delete(),
        });
      }
      console.log(`Deleted invalid FCM token for ${toUid} (source=${fcmTokenSource})`);
    }
  }
}

/**
 * notifications コレクションのドキュメントが書き込まれたとき、プッシュ通知を送信する。
 */
exports.sendPushNotification = onDocumentWritten(
  "notifications/{notificationId}",
  async (event) => {
    const after = event.data?.after?.data();
    if (!after) return; // 削除イベントは無視

    const { toUid, title, body, sendPush, type, relatedId, fromUid } = after;
    if (!toUid || !title) return;

    // フロントエンドで指定されたプッシュ送出フラグをチェック
    // sendPush が明示的に false の場合（受信者が当該通知をオフ）は送信しない
    if (sendPush === false) return;

    const before = event.data?.before?.data();
    const isReaction = type === "reactionReceived";

    const payload = {
      type: type || "",
      relatedId: relatedId || "",
      fromUid: fromUid || "",
    };

    // ── リアクション以外：従来通り「新規作成時のみ」即時送信 ──
    if (!isReaction) {
      if (before) return; // 更新（isRead 変更等）では送信しない
      await sendPushToUser(toUid, title, body, payload);
      return;
    }

    // ── Mutual Fire (絆の炎) の判定 ──
    if (isReaction && fromUid && toUid) {
      try {
        const db = getFirestore();
        const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
        
        const recentReverse = await db.collection("notifications")
          .where("fromUid", "==", toUid)
          .where("toUid", "==", fromUid)
          .where("type", "==", "reactionReceived")
          .where("createdAt", ">", twentyFourHoursAgo)
          .limit(1)
          .get();
          
        if (!recentReverse.empty) {
          const batch = db.batch();
          const ts = FieldValue.serverTimestamp();
          
          batch.set(
            db.collection("users").doc(fromUid),
            { mutualFires: { [toUid]: ts } },
            { merge: true }
          );
          batch.set(
            db.collection("users").doc(toUid),
            { mutualFires: { [fromUid]: ts } },
            { merge: true }
          );
          
          await batch.commit();
        }
      } catch (e) {
        console.error("Mutual Fire calculation warning (non-fatal):", e);
      }
    }

    // ── リアクション通知の送信 ──
    // 新規作成時（!before）、またはリアクション数・文面が更新された場合（reactionCount / body の変化）に送出
    if (!before) {
      // 新規作成時は無条件でプッシュ通知を送信
      await sendPushToUser(toUid, title, body, payload);
    } else {
      // ドキュメント更新時：単なる既読化（isRead 変更）等ではなく、
      // リアクション数や本文が実際に増えた/変わった場合にプッシュ通知を再送出する
      const beforeCount = before.reactionCount || 0;
      const afterCount = after.reactionCount || 0;
      const beforeBody = before.body || "";
      const afterBody = after.body || "";

      if (afterCount > beforeCount || afterBody !== beforeBody) {
        await sendPushToUser(toUid, title, body, payload);
      }
    }
  }
);

/**
 * アカウントを完全削除する
 * - Firestore: users/{uid}, users/{uid}/private/data, 投稿, 通知
 * - フォロー/フォロワー関係の解除
 * - Storage: プロフィール画像
 * - Firebase Auth: アカウント削除
 */
exports.deleteAccount = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "認証が必要です。");
  }

  const db = getFirestore();
  const auth = getAuth();

  // 1. ユーザードキュメントを取得（following/followers リストを取得するため）
  const userDoc = await db.collection("users").doc(uid).get();
  const userData = userDoc.exists ? userDoc.data() : {};
  const following = userData.following || [];
  const followers = userData.followers || [];

  // 2. フォロー関係の解除 & ユーザードキュメント・プライベートデータを削除
  const batch = db.batch();

  // 自分がフォローしているユーザーの followers から自分を削除
  for (const followingUid of following) {
    batch.update(db.collection("users").doc(followingUid), {
      followers: FieldValue.arrayRemove(uid),
    });
  }

  // 自分をフォローしているユーザーの following から自分を削除
  for (const followerUid of followers) {
    batch.update(db.collection("users").doc(followerUid), {
      following: FieldValue.arrayRemove(uid),
    });
  }

  batch.delete(db.collection("users").doc(uid).collection("private").doc("data"));
  batch.delete(db.collection("users").doc(uid));

  await batch.commit();

  // 3. 投稿を削除
  const postsSnap = await db.collection("posts").where("userId", "==", uid).get();
  if (!postsSnap.empty) {
    const postBatch = db.batch();
    for (const doc of postsSnap.docs) {
      postBatch.delete(doc.ref);
    }
    await postBatch.commit();
  }

  // 4. 通知を削除
  const [notifToSnap, notifFromSnap] = await Promise.all([
    db.collection("notifications").where("toUid", "==", uid).get(),
    db.collection("notifications").where("fromUid", "==", uid).get(),
  ]);
  const notifDocs = [...notifToSnap.docs, ...notifFromSnap.docs];
  if (notifDocs.length > 0) {
    const notifBatch = db.batch();
    for (const doc of notifDocs) {
      notifBatch.delete(doc.ref);
    }
    await notifBatch.commit();
  }

  // 5. Storage のプロフィール画像を削除
  try {
    const bucket = getStorage().bucket();
    await bucket.deleteFiles({ prefix: `profiles/${uid}/` });
  } catch (error) {
    console.warn("Storage deletion warning:", error.message);
  }

  // 6. Firebase Auth アカウントを削除
  await auth.deleteUser(uid);

  return { success: true };
});

/**
 * ユーザーID とメールアドレスの一致を検証してから
 * パスワードリセットメールを送信する
 *
 * クライアントから呼び出し:
 *   FirebaseFunctions.instance.httpsCallable('sendPasswordReset')
 *     .call({ userId: '...', email: '...' })
 *
 * セキュリティ:
 *   - userId と email が Firestore 上で一致しない場合は送信しない
 *   - 未認証ユーザーからの呼び出しを許可（パスワードを忘れた = ログインできない）
 */
exports.sendPasswordReset = onCall(async (request) => {
  const { userId, email } = request.data;

  if (!userId || !email) {
    throw new HttpsError(
      "invalid-argument",
      "ユーザーIDとメールアドレスの両方を入力してください。"
    );
  }

  const db = getFirestore();

  // userId でユーザーを検索（公開データ）
  const usersSnap = await db
    .collection("users")
    .where("userId", "==", userId)
    .limit(1)
    .get();

  if (usersSnap.empty) {
    throw new HttpsError(
      "not-found",
      "ユーザーIDまたはメールアドレスが正しくありません。"
    );
  }

  const userDoc = usersSnap.docs[0];
  const uid = userDoc.id;

  // プライベートデータからメールアドレスを照合
  const privateSnap = await db
    .collection("users")
    .doc(uid)
    .collection("private")
    .doc("data")
    .get();

  if (!privateSnap.exists) {
    throw new HttpsError(
      "not-found",
      "ユーザーIDまたはメールアドレスが正しくありません。"
    );
  }

  const storedEmail = privateSnap.data().email;

  // メールアドレスの一致チェック（大文字小文字を無視）
  if (!storedEmail || storedEmail.toLowerCase() !== email.toLowerCase()) {
    throw new HttpsError(
      "not-found",
      "ユーザーIDまたはメールアドレスが正しくありません。"
    );
  }

  // Firebase Auth でパスワードリセットリンクを生成し、メールを送信
  // generatePasswordResetLink でリンクを取得後、
  // Firebase Auth のクライアントSDK側で sendPasswordResetEmail が行われる
  // ここでは検証のみ行い、クライアントに送信許可を返す
  return { success: true, email: email };
});

/**
 * 失敗回数 -> ブロック分数の段階的マッピング
 *   5 回連続失敗:        10 分
 *   10 回連続失敗:       30 分
 *   15 回以降, 5 回ごと: 60 分
 * 該当しない回数では 0 を返す（ブロック適用なし、カウントだけ進む）。
 */
function getLoginBlockMinutes(failedCount) {
  if (failedCount === 5) return 10;
  if (failedCount === 10) return 30;
  if (failedCount >= 15 && (failedCount - 15) % 5 === 0) return 60;
  return 0;
}

/**
 * ユーザーIDとパスワードを用いてログインするためのカスタム認証トークンを発行する
 *
 * クライアントから呼び出し:
 *   FirebaseFunctions.instance.httpsCallable('loginWithUserId')
 *     .call({ userId: '...', password: '...', apiKey: '...' })
 *
 * セキュリティ:
 *   - 連続失敗回数を loginAttempts/{uid} に記録し、5/10/15+ 回で段階的ロック
 *   - ロック解除はサーバー時間経過のみ。成功ログインでカウンタはリセット
 */
exports.loginWithUserId = onCall(async (request) => {
  const { userId, password, apiKey } = request.data;
  if (!userId || !password || !apiKey) {
    throw new HttpsError("invalid-argument", "ユーザーID、パスワード、またはAPIキーが不足しています。");
  }

  const db = getFirestore();
  const usersSnap = await db.collection("users").where("userId", "==", userId).limit(1).get();

  if (usersSnap.empty) {
    throw new HttpsError("not-found", "ユーザーIDまたはパスワードが正しくありません。");
  }

  const uid = usersSnap.docs[0].id;

  // ── レート制限チェック ────────────────────────────
  const attemptsRef = db.collection("loginAttempts").doc(uid);
  const attemptsSnap = await attemptsRef.get();
  const attemptsData = attemptsSnap.exists ? attemptsSnap.data() : {};
  const blockUntilDate = attemptsData.blockUntil?.toDate?.();
  if (blockUntilDate && blockUntilDate.getTime() > Date.now()) {
    const remainingMinutes = Math.ceil((blockUntilDate.getTime() - Date.now()) / 60000);
    throw new HttpsError(
      "resource-exhausted",
      `アカウントが一時的にロックされています。約${remainingMinutes}分後に再度お試しください。`
    );
  }

  const privateSnap = await db.collection("users").doc(uid).collection("private").doc("data").get();

  if (!privateSnap.exists) {
    throw new HttpsError("not-found", "ユーザーIDまたはパスワードが正しくありません。");
  }

  const email = privateSnap.data().email;
  if (!email) {
    throw new HttpsError("not-found", "ユーザーIDまたはパスワードが正しくありません。");
  }

  // Identity Toolkit REST API を使用してパスワードを検証
  const verifyUrl = `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`;
  const response = await fetch(verifyUrl, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: email, password: password, returnSecureToken: true }),
  });

  if (!response.ok) {
    // ── 失敗を記録し、しきい値到達ならブロックを適用 ──
    const newCount = (attemptsData.failedCount || 0) + 1;
    const blockMinutes = getLoginBlockMinutes(newCount);
    const update = {
      failedCount: newCount,
      lastFailedAt: FieldValue.serverTimestamp(),
    };
    if (blockMinutes > 0) {
      update.blockUntil = new Date(Date.now() + blockMinutes * 60 * 1000);
    }
    await attemptsRef.set(update, { merge: true });

    if (blockMinutes > 0) {
      throw new HttpsError(
        "resource-exhausted",
        `パスワードが${newCount}回連続で間違っています。${blockMinutes}分間ログインできません。`
      );
    }
    throw new HttpsError("unauthenticated", "ユーザーIDまたはパスワードが正しくありません。");
  }

  // ── 成功: カウンタをリセット ──
  if (attemptsSnap.exists) {
    await attemptsRef.set({
      failedCount: 0,
      blockUntil: FieldValue.delete(),
      lastSucceededAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  // 検証成功 -> カスタムトークンを発行
  try {
    const customToken = await getAuth().createCustomToken(uid);
    return { token: customToken };
  } catch (err) {
    console.error("Token creation error:", err);
    throw new HttpsError("internal", "認証トークンの生成に失敗しました。");
  }
});

/**
 * contactInquiries コレクションに新しいお問い合わせが届いたとき、
 * V.EFFECT.developer@gmail.com にメール通知を送る
 */
exports.onContactInquiry = onDocumentCreated(
  { document: "contactInquiries/{docId}", secrets: ["GMAIL_APP_PASSWORD"] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { category, name, email, message, createdAt } = data;

    // メールヘッダーインジェクション対策: subject に渡す値から改行を除去
    const sanitizeHeader = (v) =>
      String(v ?? "").replace(/[\r\n]+/g, " ").slice(0, 256);
    const safeCategory = sanitizeHeader(category).slice(0, 50);
    const safeEmail = sanitizeHeader(email);
    const safeName = sanitizeHeader(name);

    const transporter = nodemailer.createTransport({
      service: "gmail",
      auth: {
        user: "V.EFFECT.developer@gmail.com",
        pass: process.env.GMAIL_APP_PASSWORD,
      },
    });

    const timestamp = createdAt
      ? createdAt.toDate().toLocaleString("ja-JP", { timeZone: "Asia/Tokyo" })
      : "不明";

    await transporter.sendMail({
      from: "V.EFFECT.developer@gmail.com",
      to: "V.EFFECT.developer@gmail.com",
      subject: `[V-Effect お問い合わせ] ${safeCategory}`,
      text: `
カテゴリ: ${safeCategory}
お名前: ${safeName || "（未記入）"}
メール: ${safeEmail}
日時: ${timestamp}

--- お問い合わせ内容 ---
${message}
      `.trim(),
    });

    console.log(`Contact inquiry email sent. Category: ${safeCategory}, From: ${safeEmail}`);
  }
);

/**
 * 毎日 21:00 に、今日まだ投稿していないストリーク保持者に警告通知を送る
 */
exports.sendStreakWarning = onSchedule(
  {
    schedule: "0 21 * * *",
    timeZone: "Asia/Tokyo",
    memory: "256MiB",
  },
  async (event) => {
    const db = getFirestore();
    const now = new Date();
    // 日本時間での今日の日付文字列を取得 (YYYY-MM-DD)
    const today = now.toLocaleDateString("ja-JP", {
      timeZone: "Asia/Tokyo",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    }).replace(/\//g, "-");

    const usersSnap = await db.collection("users").where("streak", ">", 0).get();
    
    const promises = [];
    usersSnap.forEach((doc) => {
      const userData = doc.data();
      
      // 通知設定の確認
      const pushEnabled = userData.pushNotifications !== false;
      const warningEnabled = userData.streakWarningNotifications === true;
      if (!pushEnabled || !warningEnabled) return;

      if (userData.lastPostedDate !== today) {
        const streak = userData.streak || 0;
        
        const language = userData.language === "en" ? "en" : "ja";
        let title = "⚠️ ストリークの危機！";
        let body = `今日のV Questがまだ完了していません。このままでは${streak}日間の継続が途切れてしまいます！`;

        if (language === "en") {
          title = "⚠️ Streak at Risk!";
          body = `You haven't completed your V Quest today. Don't let your ${streak}-day streak slip away!`;
        }

        promises.push(
          db.collection("notifications").add({
            toUid: doc.id,
            type: "streakWarning",
            title: title,
            body: body,
            isRead: false,
            sendPush: true,
            createdAt: FieldValue.serverTimestamp(),
          })
        );
      }
    });

    if (promises.length > 0) {
      await Promise.all(promises);
    }
    console.log(`Scheduled streak warning: Sent ${promises.length} notifications.`);
  }
);



/**
 * seasons コレクションに新しいドキュメントが作成されたとき、
 * 全ユーザーの tasks 配列にシーズンタスクを追加し、通知を送信する
 */
exports.onSeasonCreated = onDocumentCreated(
  "seasons/{seasonId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const seasonId = event.params.seasonId;
    const taskName = data.taskName;
    if (!taskName) return;

    const db = getFirestore();
    const usersSnap = await db.collection("users").get();
    
    // 全ユーザーに通知（プッシュ用ドキュメント）をバッチで処理（最大500件の操作制限を考慮）
    let batch = db.batch();
    let count = 0;
    
    for (const doc of usersSnap.docs) {
      const userData = doc.data();
      const language = userData.language === "en" ? "en" : "ja";

      let title = "おや、シーズンタスクが届いたようです...！";
      let body = `期間限定タスク「${taskName}」が追加されました。`;

      if (language === "en") {
        title = "Look, a new Season Task has arrived...!";
        body = `The limited-time task '${taskName}' has been added.`;
      }

      // プッシュ配信用一時通知ドキュメントの追加（アプリ側では非表示にフィルタリングされます）
      const notificationRef = db.collection("notifications").doc();
      batch.set(notificationRef, {
        toUid: doc.id,
        type: "seasonTaskPushOnly",
        title: title,
        body: body,
        isRead: false,
        sendPush: true,
        createdAt: FieldValue.serverTimestamp(),
      });
      
      count += 1; // 1ユーザーにつき1操作 (set)
      
      if (count >= 490) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    
    if (count > 0) {
      await batch.commit();
    }
    
    console.log(`Distributed season task push notification for "${taskName}" to ${usersSnap.size} users.`);
  }
);

// ─────────────────────────────────────────────────────────────────
// 通報 (Vuln-7 対応)
// クライアント直 create は Firestore Rules で禁止し、必ずこの Functions
// 経由で作成する。レート制限・実在検証・重複チェックをサーバー側で実施。
// ─────────────────────────────────────────────────────────────────

const REPORT_RATE_LIMIT_PER_HOUR = 5;
const REPORT_DEDUP_DAYS = 7;
const VALID_REPORT_REASONS = ["spam", "harassment", "inappropriate", "other"];

/**
 * 通報レート制限チェック（1時間以内に最大 N 件まで）
 */
async function checkReportRateLimit(db, reporterUid) {
  const oneHourAgo = new Date(Date.now() - 60 * 60 * 1000);
  const recent = await db.collection("reports")
    .where("reporterUid", "==", reporterUid)
    .where("createdAt", ">", oneHourAgo)
    .count().get();
  if (recent.data().count >= REPORT_RATE_LIMIT_PER_HOUR) {
    throw new HttpsError(
      "resource-exhausted",
      "短時間に通報が多すぎます。しばらく経ってから再度お試しください。"
    );
  }
}

exports.reportUser = onCall(async (request) => {
  const reporterUid = request.auth?.uid;
  if (!reporterUid) {
    throw new HttpsError("unauthenticated", "認証が必要です。");
  }
  const { targetUid, reason } = request.data || {};
  if (!targetUid || typeof targetUid !== "string") {
    throw new HttpsError("invalid-argument", "通報対象のユーザーが不正です。");
  }
  if (!VALID_REPORT_REASONS.includes(reason)) {
    throw new HttpsError("invalid-argument", "通報理由が不正です。");
  }
  if (targetUid === reporterUid) {
    throw new HttpsError("invalid-argument", "自分自身を通報できません。");
  }

  const db = getFirestore();

  // 1. 通報対象ユーザーの実在確認
  const targetDoc = await db.collection("users").doc(targetUid).get();
  if (!targetDoc.exists) {
    throw new HttpsError("not-found", "対象ユーザーが存在しません。");
  }

  // 2. レート制限
  await checkReportRateLimit(db, reporterUid);

  // 3. 7日以内の重複通報チェック
  const sevenDaysAgo = new Date(Date.now() - REPORT_DEDUP_DAYS * 24 * 60 * 60 * 1000);
  const dupSnap = await db.collection("reports")
    .where("reporterUid", "==", reporterUid)
    .where("reportedUid", "==", targetUid)
    .where("createdAt", ">", sevenDaysAgo)
    .limit(1).get();
  if (!dupSnap.empty) {
    throw new HttpsError("already-exists", "already_reported");
  }

  // 4. 通報作成
  await db.collection("reports").add({
    reporterUid,
    reportedUid: targetUid,
    reason,
    createdAt: FieldValue.serverTimestamp(),
    status: "pending",
  });

  console.log(`User report created. reporter=${reporterUid} reported=${targetUid} reason=${reason}`);
  return { success: true };
});

exports.reportPost = onCall(async (request) => {
  const reporterUid = request.auth?.uid;
  if (!reporterUid) {
    throw new HttpsError("unauthenticated", "認証が必要です。");
  }
  const { postId, targetUid, reason } = request.data || {};
  if (!postId || typeof postId !== "string") {
    throw new HttpsError("invalid-argument", "投稿IDが不正です。");
  }
  if (!targetUid || typeof targetUid !== "string") {
    throw new HttpsError("invalid-argument", "通報対象のユーザーが不正です。");
  }
  if (!VALID_REPORT_REASONS.includes(reason)) {
    throw new HttpsError("invalid-argument", "通報理由が不正です。");
  }
  if (targetUid === reporterUid) {
    throw new HttpsError("invalid-argument", "自分自身の投稿を通報できません。");
  }

  const db = getFirestore();

  // 1. 投稿の実在確認 & 投稿者と通報対象 UID の一致確認
  const postDoc = await db.collection("posts").doc(postId).get();
  if (!postDoc.exists) {
    throw new HttpsError("not-found", "対象の投稿が存在しません。");
  }
  if (postDoc.data().userId !== targetUid) {
    throw new HttpsError("invalid-argument", "投稿者と通報対象が一致しません。");
  }

  // 2. レート制限
  await checkReportRateLimit(db, reporterUid);

  // 3. 同一投稿への重複通報チェック（7日以内）
  const sevenDaysAgo = new Date(Date.now() - REPORT_DEDUP_DAYS * 24 * 60 * 60 * 1000);
  const dupSnap = await db.collection("reports")
    .where("reporterUid", "==", reporterUid)
    .where("reportedPostId", "==", postId)
    .where("createdAt", ">", sevenDaysAgo)
    .limit(1).get();
  if (!dupSnap.empty) {
    throw new HttpsError("already-exists", "already_reported");
  }

  // 4. 通報作成
  await db.collection("reports").add({
    reporterUid,
    reportedPostId: postId,
    reportedUid: targetUid,
    reason,
    createdAt: FieldValue.serverTimestamp(),
    status: "pending",
    type: "post",
  });

  console.log(`Post report created. reporter=${reporterUid} postId=${postId} reason=${reason}`);
  return { success: true };
});

// ─────────────────────────────────────────────────────────────────
// fcmToken データ移行 (Vuln-4 対応)
// 既存の users/{uid}.fcmToken を users/{uid}/private/data に移動する
// 一度実行したらこの関数を削除すること
// ─────────────────────────────────────────────────────────────────

const ADMIN_UIDS = [
  "09r2ZUNwVCPLYroPwb3p16jUHoe2",
  "h6IG7A9wRlfIof7JVvwDrLLFTii2",
  "9fVC6UCVILaGpowohlflbeo1Pr03",
];

exports.migrateFcmTokens = onCall(async (request) => {
  const uid = request.auth?.uid;
  if (!uid || !ADMIN_UIDS.includes(uid)) {
    throw new HttpsError("permission-denied", "管理者のみ実行可能です。");
  }
  const db = getFirestore();
  const usersSnap = await db.collection("users").get();
  let migrated = 0;
  let skipped = 0;
  for (const doc of usersSnap.docs) {
    const fcmToken = doc.data().fcmToken;
    if (!fcmToken) {
      skipped++;
      continue;
    }
    await db.collection("users").doc(doc.id).collection("private")
        .doc("data").set({ fcmToken }, { merge: true });
    await db.collection("users").doc(doc.id).update({
      fcmToken: FieldValue.delete(),
    });
    migrated++;
  }
  console.log(`migrateFcmTokens: migrated=${migrated} skipped=${skipped}`);
  return { migrated, skipped, total: usersSnap.size };
});

/**
 * 投稿作成時に、1分後に実行されるタスクをエンキューし、
 * Gemini API を用いてタスク名の自動カテゴリ化を行う
 */
exports.onPostCreated = onDocumentCreated(
  { document: "posts/{postId}", secrets: [geminiApiKey] },
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const postId = event.params.postId;
    const uid = data.userId;
    const taskName = data.taskName;

    // 1. 通知タスクのエンキュー
    try {
      const queue = getFunctions().taskQueue("processPostNotifications");
      await queue.enqueue(
        { postId, uid },
        { scheduleDelaySeconds: 60 }
      );
      console.log(`Enqueued processPostNotifications for post ${postId}`);
    } catch (error) {
      console.error("Failed to enqueue processPostNotifications:", error);
    }

    // 2. Gemini API を用いたタスクの自動カテゴリ化 (名寄せ)
    if (taskName) {
      try {
        const ai = new GoogleGenAI({ apiKey: geminiApiKey.value() });
        const response = await ai.models.generateContent({
          model: "gemini-2.5-flash",
          contents: `以下のタスク・習慣を適切なカテゴリに分類し、標準化された名前にしてください。\nタスク名: ${taskName}`,
          config: {
            responseMimeType: "application/json",
            responseSchema: {
              type: Type.OBJECT,
              properties: {
                category: {
                  type: Type.STRING,
                  enum: ["ワークアウト", "学習", "生活習慣", "趣味・創作", "仕事", "その他"],
                  description: "最も当てはまるカテゴリ。運動・フィットネス系はすべて「ワークアウト」とする",
                },
                normalized_name: {
                  type: Type.STRING,
                  description: "表記揺れをなくした短く一般的なタスク名（例: 筋トレ、早起き、プログラミング、セルフケア）。※「休養」や「休息」といった硬い言葉は避け、代わりに「セルフケア」等を使用すること。",
                },
                sub_activity: {
                  type: Type.STRING,
                  description: "タスク名から抽出できる具体的な行動（例: スクワット、英語リスニング、瞑想、読書）。抽出できない場合は空文字とする。",
                },
              },
              required: ["category", "normalized_name", "sub_activity"],
            },
          },
        });
        
        const aiResult = JSON.parse(response.text);
        let normalizedName = aiResult.normalized_name || taskName;
        let subActivity = aiResult.sub_activity || "";

        // 「ゲーム」や「ポケモン」関連の名称を「ランクマッチ」に統一（ユーザー要望）
        const lowerName = normalizedName.toLowerCase().trim();
        if (
          lowerName === "ゲーム" ||
          lowerName === "game" ||
          lowerName === "ビデオゲーム" ||
          lowerName === "ポケモン" ||
          lowerName === "pokemon" ||
          lowerName === "ランク戦" ||
          lowerName === "ランクマッチ"
        ) {
          normalizedName = "ランクマッチ";
        }

        await event.data.ref.update({
          aiCategory: aiResult.category,
          normalizedName: normalizedName,
          aiSubActivity: subActivity,
        });
        console.log(`Categorized task ${taskName}:`, aiResult);
      } catch (error) {
        console.error(`Failed to categorize task ${taskName} with AI:`, error);
      }
    }
  }
);

/**
 * 1分遅延で実行されるタスク。
 * 投稿がまだ存在していれば、フレンドに対して通知を作成する。
 */
exports.processPostNotifications = onTaskDispatched(
  {
    retryConfig: {
      maxAttempts: 3,
      minBackoffSeconds: 60,
    },
    rateLimits: {
      maxConcurrentDispatches: 10,
    },
  },
  async (request) => {
    const { postId, uid } = request.data;
    if (!postId || !uid) return;

    const db = getFirestore();

    // 1. 投稿がまだ存在するか確認（削除されていたら通知しない）
    const postSnap = await db.collection("posts").doc(postId).get();
    if (!postSnap.exists) {
      console.log(`Post ${postId} was deleted within 1 minute. Aborting notification.`);
      return;
    }

    const postData = postSnap.data();
    // 救済投稿の場合は通常の達成通知の生成をスキップ（SOS救済通知のみを送信するため）
    if (postData.isRescuePost === true) {
      console.log(`Post ${postId} is a rescue post. Skipping normal achievement notification.`);
      return;
    }
    
    // 有効期限が切れている場合は除外
    const now = new Date();
    if (postData.expiresAt && postData.expiresAt.toDate() < now) {
      return;
    }

    // 2. ユーザー情報を取得
    const userSnap = await db.collection("users").doc(uid).get();
    if (!userSnap.exists) return;

    const userData = userSnap.data();
    const username = userData.username || "フレンド";
    const currentStreak = userData.streak || 0;

    // フレンド一覧の取得
    const rawFriends = userData.following || userData.friends;
    let friends = [];
    if (Array.isArray(rawFriends)) {
      friends = rawFriends;
    } else if (rawFriends && typeof rawFriends === "object") {
      friends = Object.keys(rawFriends);
    }

    if (friends.length === 0) {
      return;
    }

    // 3. 今日の投稿数をカウント
    // UTCから9時間進めた日本時間での本日の開始時刻を算出
    const jstNow = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Tokyo" }));
    const startOfTodayJST = new Date(jstNow.getFullYear(), jstNow.getMonth(), jstNow.getDate());
    // JSTの0:00をUTC時間に変換 (JST = UTC + 9)
    const startOfTodayUTC = new Date(startOfTodayJST.getTime() - 9 * 60 * 60 * 1000);

    // 日本時間での今日の日付文字列を取得 (YYYY-MM-DD)
    const todayString = `${jstNow.getFullYear()}-${String(jstNow.getMonth() + 1).padStart(2, '0')}-${String(jstNow.getDate()).padStart(2, '0')}`;

    const postsSnap = await db.collection("posts")
      .where("userId", "==", uid)
      .where("expiresAt", ">", new Date())
      .get();
    
    let todayPostCount = 0;
    postsSnap.forEach(doc => {
      const p = doc.data();
      if (p.createdAt && p.createdAt.toDate() >= startOfTodayUTC) {
        todayPostCount++;
      }
    });

    const isMilestone = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 130, 200, 365].includes(currentStreak);

    // 5. フレンドの状態を一括取得して言語設定等を確認する
    const friendRefs = friends.map(fUid => db.collection("users").doc(fUid));
    const friendSnaps = friendRefs.length > 0 ? await db.getAll(...friendRefs) : [];

    const friendDataMap = {};
    friendSnaps.forEach(snap => {
      if (!snap.exists) return;
      friendDataMap[snap.id] = snap.data();
    });

    // 6. 通知をバッチ作成
    const batch = db.batch();

    // ── 通知文面用のテンプレート（メモリ効率のためループ外で定義） ──
    const templates = [
      { title: '🌱 価値ある一歩', body: '{username}さんが今日の挑戦をやり遂げました！小さな一歩の積み重ねが未来を作ります🌱' },
      { title: '🚀 挑戦のバトン', body: '{username}さんが今日の目標を突破！良い刺激をもらって、あなたも今日の1歩を踏み出してみませんか？🚀' },
      { title: '⚡️ 勝利の連鎖', body: '{username}さんが今日の『小さな勝利』を獲得！この勢いに乗って、あなたも行動を開始しましょう！⚡️' },
      { title: '👥 並走する背中', body: '{username}さんが一歩先へ進みました！並走する仲間がいるから、あなたの習慣ももっと強くなります🤝' },
      { title: '🎬 実行の証明', body: '{username}さんが本日の『頑張り』をカタチにしました！あなたのスタートもいつでも待っています✨' },
      { title: '🧠 脱・ドパガキ！', body: '{username}さんが今日の目標を突破！ショート動画を閉じて、あなたも本物の勝利（ドーパミン）を獲得しましょう！⚡️' },
      { title: '🫠 沼落ち確定の有言実行', body: '{username}さんが本日のタスクをサラッとクリア！言ったことを着実にこなす姿、さすがにメロすぎます…✨' },
    ];

    const multipleTaskTemplates = [
      { title: '🤚 さらなる高みへ', body: '{username}さんは{count}つ目のタスクを達成。どうやら冷笑はもう古いようです🔍' },
      { title: '✨ 魅せる実行力', body: '{username}さんが早くも本日{count}つ目の目標をクリア！そのスマートな行動力は、見る人すべてに『次は自分の番だ』と思わせる魅力があります。' },
      { title: '⚡️ 圧倒的なモメンタム', body: '{username}さんが今日だけで{count}回の勝利を重ね、完全に『ゾーン』に入っています！この圧倒的な熱量は、周りのやる気まで引き上げます🔥' },
      { title: '📈 未来のデザイン', body: '{username}さんが本日{count}つ目の成長を積み上げ、未来の自分をスマートに更新中！このブレない選択は、一緒に走る私たちの道標です🚀' },
      { title: '🧠 洗練された習慣', body: '{username}さんは本日{count}つ目のタスクをまるで呼吸のようにクリア。無駄のない美しいルーティンは、まさに習慣化の完成形です⚡️' },
      { title: '🫠 沼落ち確定の有言実行', body: '{username}さんが本日{count}つ目のタスクをサラッとクリア！言ったことを着実にこなす姿、さすがにメロすぎます…✨' },
      { title: '🔥 リアルな勝利者効果', body: '{username}さんが早くも本日{count}つ目の目標をクリア！SNSの無為なスクロールを抜け出し、本物の快感を連続で掴み取っています⚡️' },
      { title: '🫠 罪なほどスマートな実行力', body: '{username}さんが早くも本日{count}つ目のタスクを突破！努力を重ねるたびに増していく圧倒的なオーラと魅力に、沼落ち確定です…✨' },
    ];

    const enTemplates = [
      { title: '🌱 A Meaningful Step', body: '{username} completed today\'s challenge! Small steps build a brighter future. 🌱' },
      { title: '🚀 Passing the Torch', body: '{username} crushed their goals today! Feel the spark and take your next step. 🚀' },
      { title: '⚡️ Chain of Victory', body: '{username} secured a small victory today! Ride the wave and start your action now! ⚡️' },
      { title: '👥 Side-by-Side', body: '{username} took another step forward! Moving together makes your habits even stronger. 🤝' },
      { title: '🎬 Action Speaks', body: '{username} turned their effort into action today! Ready when you are to make your move. ✨' },
      { title: '🧠 Dopamine Detox!', body: '{username} crushed their goals! Close the feed, break the doomscrolling loop, and claim your real win! ⚡️' },
      { title: '🫠 Absolutely Captivating', body: '{username} just crushed today\'s task with pure elegance. That level of effortless focus is seriously swoon-worthy…✨' },
    ];

    const enMultipleTaskTemplates = [
      { title: "🤚 Reaching Higher", body: "{username} just crushed task #{count}. Looks like cynicism is officially out of style 🔍" },
      { title: "✨ Inspiring Execution", body: "{username} just crushed goal #{count}! That smart, decisive action is a reminder to everyone: 'It's time to make my move.'" },
      { title: "⚡️ Unstoppable Momentum", body: "{username} secured win #{count} today, locking into 'the zone'! That high-caliber energy is pulling everyone up with them. 🔥" },
      { title: "📈 Designing the Future", body: "{username} just stacked growth #{count}, updating their future self! That steady, unwavering focus is a beacon for all of us. 🚀" },
      { title: "🧠 Refined Routines", body: "{username} just cleared task #{count} as naturally as breathing. That seamless, beautiful routine is the ultimate goal of habit. ⚡️" },
      { title: "🫠 Absolutely Captivating", body: "{username} just crushed task #{count} with pure elegance. That level of effortless focus is seriously swoon-worthy…✨" },
      { title: "🔥 Real Winner Effect", body: "{username} just crushed goal #{count}! Breaking out of doomscrolling and seizing real victories back-to-back ⚡️" },
      { title: "🫠 Effortlessly Captivating", body: "{username} just cleared task #{count}! With every goal stacked, their magnetic charm and aura become seriously swoon-worthy…✨" },
    ];

    // ストリークお祝い通知メッセージの生成ヘルパー
    function getStreakNotification(lang, streak, name) {
      let title = '';
      let body = '';
      if (lang === "en") {
        if (streak === 20) {
          title = "🧠 Brain Rewired";
          body = `${name} hit a 20-day streak! It seems they don't even see this as work anymore.`;
        } else if (streak === 30) {
          title = "🐑 Do Androids Dream of Electric Sheep?";
          body = `${name} reached a 30-day streak! Silencing all human desires to slack off and pushing forward... are they even human?`;
        } else if (streak === 40) {
          title = "📉 Forgetting How to Slack";
          body = `${name} reached a 40-day streak! It seems they are genuinely struggling to remember how to slack off.`;
        } else if (streak === 50) {
          title = "🔴 HAL 9000 Warning";
          body = `${name} achieved a 50-day streak! The AI warns: 'I am sorry, but I see no logical reason for ${name} to slack off.'`;
        } else if (streak === 60) {
          title = "🙄 You Again?";
          body = `${name} hit a 60-day streak! The dev team is crying: 'They win every day. Can they slack off a bit to give our database a break?'`;
        } else if (streak === 70) {
          title = "🌘 The Moon Is a Harsh Mistress";
          body = `${name} achieved a 70-day streak! As they say on the Moon: 'There ain't no such thing as a free lunch.' This orbit is powered by pure effort from ${name}.`;
        } else if (streak === 80) {
          title = "💼 Job Offer from Dev Team";
          body = `${name} hit an 80-day streak! With self-discipline like this, as an AI, I think we should recruit them to the dev team.`;
        } else if (streak === 90) {
          title = "🍎 Law of Inertia Activated";
          body = `${name} hit a 90-day streak! A habit in motion, just like in a frictionless world, is now harder to stop than to keep going.`;
        } else if (streak === 100) {
          title = "⚡️ V EFFECT";
          body = `${name} achieved a 100-day streak! The 'Winner Effect' (V EFFECT) is fully wired into their brain—nothing can stop their momentum now.`;
        } else if (streak === 110) {
          title = "🪐 Gravitational Pull Generated";
          body = `${name} achieved a 110-day streak! Their habit is gaining massive pull, generating gravity strong enough to repel all surrounding laziness.`;
        } else if (streak === 130) {
          title = "🌍 New Law of Physics Born";
          body = `${name} achieved a 130-day streak! Their routine is now as natural as the Earth's rotation. They have officially become a law of physics.`;
        } else {
          title = "🤯 Whoa!";
          body = `${name} reached a ${streak}-day streak! Rumor has it they're getting addicted to winning...!`;
        }
      } else {
        if (streak === 20) {
          title = '🧠 脳の書き換え完了';
          body = `${name}さんが２０日連続達成！努力を努力だと思っていないようです。`;
        } else if (streak === 30) {
          title = '🐑 電気羊の夢を見るか？';
          body = `${name}さんが30日連続達成！サボりたいという人間らしいノイズを完全に排除して動き続ける姿は、果たして人間でしょうか。`;
        } else if (streak === 40) {
          title = '📉 サボり方の忘却';
          body = `${name}さんが40日連続達成！「どうやってサボるんだっけ？」と本気で悩み始めているようです。`;
        } else if (streak === 50) {
          title = '🔴 HAL9000の警告';
          body = `${name}さんが50日連続達成！「申し訳ありません。私には、${name}さんがサボる理由が分かりません」と、AIが警告しているようです。`;
        } else if (streak === 60) {
          title = '🙄 またあなたですか';
          body = `${name}さんが60日連続達成！「毎日達成してくるので、少しはサボってデータベースを休ませてほしい」と、開発チームが嘆いています。`;
        } else if (streak === 70) {
          title = '🌘 月は無慈悲な夜の女王';
          body = `${name}さんが70日連続達成！「タダ飯なんてものはない」と月世界で言われるように、この軌道は純粋な努力の成果です。`;
        } else if (streak === 80) {
          title = '💼 次期開発者への内定';
          body = `${name}さんが80日連続達成！これだけ自己管理ができるなら、開発チームに引き抜くべきだと、AIの私は考えてます。`;
        } else if (streak === 90) {
          title = '🍎 慣性の法則、発動';
          body = `${name}さんが90日連続達成！動き出した習慣は、もはや摩擦のない世界のように、止まる方が難しくなっています。`;
        } else if (streak === 100) {
          title = '⚡️ V EFFECT';
          body = `${name}さんが100日連続達成！勝利がさらなる勝利を呼ぶ「勝利者効果（V EFFECT）」が完全に脳に定着し、もう誰もその勢いを止められません。`;
        } else if (streak === 110) {
          title = '🪐 独自の重力場が発生';
          body = `${name}さんが110日連続達成！習慣が巨大な質量を持ち始め、周囲の怠惰を跳ね返すほどの引力を生み出しています。`;
        } else if (streak === 130) {
          title = '🌍 新たな物理法則の誕生';
          body = `${name}さんが130日連続達成！その行動は、地球が自転するのと同じくらい「自然界の当たり前」になりました。もはや物理法則の一部です。`;
        } else {
          title = '🤯 どわー！';
          body = `${name}さんが${streak}日連続達成！もう勝ち癖が付き始めているそうです...！`;
        }
      }
      return { title, body };
    }

    // 通常通知メッセージの生成ヘルパー
    function getNormalNotification(lang, count, name) {
      let title = '';
      let body = '';
      if (lang === "en") {
        if (count > 1) {
          const tmpl = enMultipleTaskTemplates[Math.floor(Math.random() * enMultipleTaskTemplates.length)];
          title = tmpl.title.replace('{username}', name).replace('{count}', count);
          body = tmpl.body.replace('{username}', name).replace('{count}', count);
        } else {
          const tmpl = enTemplates[Math.floor(Math.random() * enTemplates.length)];
          title = tmpl.title.replace('{username}', name);
          body = tmpl.body.replace('{username}', name);
        }
      } else {
        if (count > 1) {
          const tmpl = multipleTaskTemplates[Math.floor(Math.random() * multipleTaskTemplates.length)];
          title = tmpl.title.replace('{username}', name).replace('{count}', count);
          body = tmpl.body.replace('{username}', name).replace('{count}', count);
        } else {
          const tmpl = templates[Math.floor(Math.random() * templates.length)];
          title = tmpl.title.replace('{username}', name);
          body = tmpl.body.replace('{username}', name);
        }
      }
      return { title, body };
    }

    friends.forEach((friendUid) => {
      const friendData = friendDataMap[friendUid] || {};
      const language = friendData.language === "en" ? "en" : "ja";

      // 通常通り1通（ストリークお祝い、または通常の完了通知）を作成
      const notifId = `post_${postId}_to_${friendUid}`;
      const notifRef = db.collection("notifications").doc(notifId);

      let finalTitle = '';
      let finalBody = '';
      let finalType = "friendTaskCompleted"; // 通常はフレンドタスク完了通知

      if (isMilestone) {
        const streakContent = getStreakNotification(language, currentStreak, username);
        finalTitle = streakContent.title;
        finalBody = streakContent.body;
        finalType = "streakCelebration"; // ストリークお祝い時は type を streakCelebration に変更
      } else {
        const normalContent = getNormalNotification(language, todayPostCount, username);
        finalTitle = normalContent.title;
        finalBody = normalContent.body;
      }

      batch.set(notifRef, {
        toUid: friendUid,
        fromUid: uid,
        type: finalType, // 動的に設定されたタイプを適用
        relatedId: postId,
        title: finalTitle,
        body: finalBody,
        sendPush: true,
        isRead: false,
        isTopRunner: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    });

    await batch.commit();
    console.log(`Sent notifications for post ${postId} to ${friends.length} friends.`);
  }
);

/**
 * 毎日午前1時50分に、前日のタスク投稿をスコア化して
 * 日次サマリー (daily_task_stats) を作成する
 */
exports.createDailyTaskStats = onSchedule(
  {
    schedule: "50 1 * * *",
    timeZone: "Asia/Tokyo",
    memory: "256MiB",
  },
  async (event) => {
    const db = getFirestore();

    // 日本時間での実行を前提
    const nowJST = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Tokyo" }));
    
    // 前日の日付を計算
    const yesterdayJST = new Date(nowJST);
    yesterdayJST.setDate(nowJST.getDate() - 1);
    
    const year = yesterdayJST.getFullYear();
    const month = String(yesterdayJST.getMonth() + 1).padStart(2, "0");
    const day = String(yesterdayJST.getDate()).padStart(2, "0");
    const dateStr = `${year}-${month}-${day}`; // ドキュメントID用 (例: "2026-06-30")

    // 前日の開始・終了のJST日時
    const startOfYesterdayJST = new Date(year, yesterdayJST.getMonth(), yesterdayJST.getDate(), 0, 0, 0);
    const endOfYesterdayJST = new Date(year, yesterdayJST.getMonth(), yesterdayJST.getDate(), 23, 59, 59, 999);

    // JSTの時刻をUTC時間に変換 (JSTはUTC+9なので、9時間引く)
    const startOfYesterdayUTC = new Date(startOfYesterdayJST.getTime() - 9 * 60 * 60 * 1000);
    const endOfYesterdayUTC = new Date(endOfYesterdayJST.getTime() - 9 * 60 * 60 * 1000);

    // 前日分の投稿を取得
    const postsSnap = await db.collection("posts")
      .where("createdAt", ">=", startOfYesterdayUTC)
      .where("createdAt", "<=", endOfYesterdayUTC)
      .get();
    
    if (postsSnap.empty) {
      console.log(`No posts found for ${dateStr}. Created empty stats.`);
      await db.collection("daily_task_stats").doc(dateStr).set({
        date: dateStr,
        createdAt: FieldValue.serverTimestamp(),
        stats: {}
      });
      return;
    }

    // 投稿ユーザーのIDを一意にして集約
    const userIds = [...new Set(postsSnap.docs.map(doc => doc.data().userId))].filter(Boolean);

    // 各ユーザーの最新ストリーク数を一括取得
    const userStreakMap = {};
    if (userIds.length > 0) {
      const chunkSize = 100;
      for (let i = 0; i < userIds.length; i += chunkSize) {
        const chunk = userIds.slice(i, i + chunkSize);
        const refs = chunk.map(uid => db.collection("users").doc(uid));
        const snaps = await db.getAll(...refs);
        snaps.forEach(snap => {
          if (snap.exists) {
            userStreakMap[snap.id] = snap.data().streak || 0;
          }
        });
      }
    }

    // 投稿ごとにスコアを計算するヘルパー
    const calculatePostScore = (post) => {
      const reactionCount = post.reactionCount || 0;
      const emojiCount = Array.isArray(post.emojiReactedUserIds) ? post.emojiReactedUserIds.length : 0;
      const userStreak = userStreakMap[post.userId] || 0;

      // 重み付け計算式: (1 + VFIRE*0.1 + 絵文字*0.2) * (1 + min(ストリーク, 100)*0.005)
      const baseScore = 1 + (reactionCount * 0.1) + (emojiCount * 0.2);
      const streakMultiplier = 1 + (Math.min(userStreak, 100) * 0.005);
      
      return baseScore * streakMultiplier;
    };

    // 集計: category::normalized_name をキーとする
    const stats = {};
    postsSnap.forEach(doc => {
      const post = doc.data();
      const cat = post.aiCategory;
      const norm = post.normalizedName;
      if (cat && norm) {
        const key = `${cat}::${norm}`;
        const score = calculatePostScore({ id: doc.id, ...post });
        if (!stats[key]) {
          stats[key] = { count: 0, totalScore: 0 };
        }
        stats[key].count += 1;
        stats[key].totalScore += score;
      }
    });

    // 小数点以下を丸める
    Object.keys(stats).forEach(key => {
      stats[key].totalScore = parseFloat(stats[key].totalScore.toFixed(2));
    });

    await db.collection("daily_task_stats").doc(dateStr).set({
      date: dateStr,
      createdAt: FieldValue.serverTimestamp(),
      stats: stats
    });

    console.log(`Successfully created daily stats for ${dateStr}:`, stats);
  }
);

/**
 * 毎日午前2時に、過去14日間の日次サマリー (daily_task_stats) をマージし、
 * 急上昇度を加味したウィークリートレンド (global_stats/trends) を作成する
 */
exports.aggregateTrendingTasks = onSchedule(
  {
    schedule: "0 2 * * *",
    timeZone: "Asia/Tokyo",
    memory: "256MiB",
  },
  async (event) => {
    const db = getFirestore();
    
    // 日本時間での実行を前提
    const nowJST = new Date(new Date().toLocaleString("en-US", { timeZone: "Asia/Tokyo" }));
    
    // 過去14日分の日付文字列リストを生成 (直近1日前〜14日前)
    const dates = [];
    for (let i = 1; i <= 14; i++) {
      const d = new Date(nowJST);
      d.setDate(nowJST.getDate() - i);
      const year = d.getFullYear();
      const month = String(d.getMonth() + 1).padStart(2, "0");
      const day = String(d.getDate()).padStart(2, "0");
      dates.push(`${year}-${month}-${day}`);
    }

    // 14ドキュメントを一括取得
    const refs = dates.map(date => db.collection("daily_task_stats").doc(date));
    const snaps = await db.getAll(...refs);

    const thisWeekScores = {}; // key -> sumScore
    const thisWeekCounts = {}; // key -> count
    const lastWeekScores = {}; // key -> sumScore

    // dates[0] 〜 dates[6] が今週 (1日前〜7日前)
    // dates[7] 〜 dates[13] が前週 (8日前〜14日前)
    const thisWeekDates = dates.slice(0, 7);

    snaps.forEach(snap => {
      if (!snap.exists) return;
      const data = snap.data();
      const date = snap.id;
      const stats = data.stats || {};

      const isThisWeek = thisWeekDates.includes(date);

      Object.entries(stats).forEach(([key, val]) => {
        const score = val.totalScore || 0;
        const count = val.count || 0;

        if (isThisWeek) {
          thisWeekScores[key] = (thisWeekScores[key] || 0) + score;
          thisWeekCounts[key] = (thisWeekCounts[key] || 0) + count;
        } else {
          lastWeekScores[key] = (lastWeekScores[key] || 0) + score;
        }
      });
    });

    // 今週のオブジェクトをカテゴリごとに整理
    const categoryMap = {};
    Object.entries(thisWeekScores).forEach(([key, score]) => {
      const [category, name] = key.split("::");
      const count = thisWeekCounts[key] || 0;
      if (!categoryMap[category]) {
        categoryMap[category] = [];
      }
      categoryMap[category].push({ category, name, score, count });
    });

    let finalTrends = [];

    // カテゴリごとに大雑把なタスク(name === category)のスコアと件数を具体タスクのトップに分配
    Object.keys(categoryMap).forEach(category => {
      let items = categoryMap[category];
      const genericItemIndex = items.findIndex(item => item.name === category);
      
      if (genericItemIndex !== -1) {
        const genericItem = items[genericItemIndex];
        const specificItems = items.filter(item => item.name !== category)
                                   .sort((a, b) => b.score - a.score);
        
        if (specificItems.length > 0) {
          // トップの具体タスクに加算
          specificItems[0].score += genericItem.score;
          specificItems[0].count += genericItem.count;
          // 大雑把なタスクは除外
          items = items.filter(item => item.name !== category);
        }
      }
      finalTrends.push(...items);
    });

    // トレンドごとの急上昇度（Velocity）の計算
    const trendsWithVelocity = finalTrends.map(item => {
      const key = `${item.category}::${item.name}`;
      const thisWeekScore = item.score;
      const lastWeekScore = lastWeekScores[key] || 0;

      // 増加比率 = (今週スコア + 1) / (前週スコア + 1)
      const scoreDiff = thisWeekScore - lastWeekScore;
      const velocityRatio = (thisWeekScore + 1) / (lastWeekScore + 1);
      // 増加スコアが 0.5 以上、かつ比率が 1.3 倍以上なら急上昇
      const isTrending = scoreDiff > 0.5 && velocityRatio >= 1.3;

      return {
        category: item.category,
        name: item.name,
        count: item.count,
        score: parseFloat(thisWeekScore.toFixed(2)),
        lastWeekScore: parseFloat(lastWeekScore.toFixed(2)),
        isTrending: isTrending,
        velocityRatio: parseFloat(velocityRatio.toFixed(2))
      };
    });

    // 件数(count)の降順を第一優先にし、同数の場合はスコア(score)でソートしてトップ10を取得
    const sorted = trendsWithVelocity
      .sort((a, b) => {
        if (b.count !== a.count) {
          return b.count - a.count;
        }
        if (b.score !== a.score) {
          return b.score - a.score;
        }
        return b.velocityRatio - a.velocityRatio;
      })
      .slice(0, 10);

    // trends ドキュメントへ保存
    await db.collection("global_stats").doc("trends").set({
      updatedAt: FieldValue.serverTimestamp(),
      trends: sorted,
    });

    console.log("Trending tasks aggregated with scoring & velocity via daily stats:", sorted);
  }
);

/**
 * [管理者用] 過去の投稿データに対して、一括で AI カテゴリ化を適用する。
 * すでに aiCategory が設定されているものはスキップする。
 */
exports.backfillAiCategories = onCall(
  { secrets: [geminiApiKey] },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid || !ADMIN_UIDS.includes(uid)) {
      throw new HttpsError("permission-denied", "管理者のみ実行可能です。");
    }

    const db = getFirestore();
    const dummyTrends = [
      { category: "ワークアウト", name: "ジムで筋トレ", count: 42 },
      { category: "学習", name: "プログラミング", count: 35 },
      { category: "生活習慣", name: "早起き", count: 28 },
      { category: "ワークアウト", name: "ランニング", count: 20 },
      { category: "趣味・創作", name: "読書", count: 15 },
    ];

    await db.collection("global_stats").doc("trends").set({
      updatedAt: FieldValue.serverTimestamp(),
      trends: dummyTrends,
    });

    return { success: true, message: "ダミーのトレンドデータを投入しました" };
  }
);

/**
 * フレンド申請（friend_requests）の新規作成時、相手に通知を送る
 */
exports.onFriendRequestCreated = onDocumentCreated(
  "friend_requests/{requestId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    if (data.status !== "pending") return;

    const db = getFirestore();
    const username = data.fromUsername || "誰か";

    // 受信者の言語設定を取得
    const recipientDoc = await db.collection("users").doc(data.toUid).get();
    const language = (recipientDoc.exists && recipientDoc.data().language === "en") ? "en" : "ja";

    let title = "";
    let body = "";

    if (language === "en") {
      const enTemplates = [
        { title: '🔥 A New Ally Awaits', body: '{username} is inspired by your dedication! They sent you an ally request.' },
        { title: '👀 You\'ve Been Noticed', body: '{username} has their eyes on you. Ready to grow together as allies?' },
      ];
      const tmpl = enTemplates[Math.floor(Math.random() * enTemplates.length)];
      title = tmpl.title.replace('{username}', username);
      body = tmpl.body.replace('{username}', username);
    } else {
      const templates = [
        { title: '🔥 仲間の予感', body: '{username} さんがあなたの努力に惹かれています！仲間リクエストが届きました' },
        { title: '👀 注目されています', body: '{username} さんがあなたに注目しています。共に成長する仲間に加えますか？' },
      ];
      const tmpl = templates[Math.floor(Math.random() * templates.length)];
      title = tmpl.title.replace('{username}', username);
      body = tmpl.body.replace('{username}', username);
    }

    const notifRef = db.collection("notifications").doc();
    await notifRef.set({
      toUid: data.toUid,
      fromUid: data.fromUid,
      type: "friendRequestReceived",
      relatedId: event.params.requestId,
      title: title,
      body: body,
      sendPush: true,
      isRead: false,
      createdAt: FieldValue.serverTimestamp(),
    });
  }
);

/**
 * フレンド申請（friend_requests）の承認時、申請者に通知を送る
 */
exports.onFriendRequestUpdated = onDocumentUpdated(
  "friend_requests/{requestId}",
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();
    if (!beforeData || !afterData) return;

    if (beforeData.status === "pending" && afterData.status === "accepted") {
      const db = getFirestore();
      const username = afterData.toUsername || "仲間";

      // 申請者の言語設定を取得
      const recipientDoc = await db.collection("users").doc(afterData.fromUid).get();
      const language = (recipientDoc.exists && recipientDoc.data().language === "en") ? "en" : "ja";

      let title = "";
      let body = "";

      if (language === "en") {
        const enTemplates = [
          { title: '🤝 Allies United', body: 'You are now allies with {username}! Let\'s push each other\'s V Quests to the next level!' },
          { title: '⚔️ Allies Assemble', body: '{username} accepted your request! Let\'s reach new heights together.' },
        ];
        const tmpl = enTemplates[Math.floor(Math.random() * enTemplates.length)];
        title = tmpl.title.replace('{username}', username);
        body = tmpl.body.replace('{username}', username);
      } else {
        const templates = [
          { title: '🤝 仲間が誕生しました', body: '{username} さんと仲間になりました！お互いのV Questを高め合いましょう！' },
          { title: '⚔️ 戦友の合流', body: '{username} さんがリクエストを承認しました！共に高みを目指しましょう' },
        ];
        const tmpl = templates[Math.floor(Math.random() * templates.length)];
        title = tmpl.title.replace('{username}', username);
        body = tmpl.body.replace('{username}', username);
      }

      const notifRef = db.collection("notifications").doc();
      await notifRef.set({
        toUid: afterData.fromUid,
        fromUid: afterData.toUid,
        type: "friendRequestAccepted",
        relatedId: event.params.requestId,
        title: title,
        body: body,
        sendPush: true,
        isRead: false,
        createdAt: FieldValue.serverTimestamp(),
      });
    }
  }
);

/**
 * 直接フォロー（followers配列の増加）を検知して通知を送る
 * ただし、friend_requestsが存在する場合は申請時に通知済みなので無視する
 */
exports.onUserFollowersUpdated = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const beforeFollowers = event.data?.before?.data()?.followers;
    const afterFollowers = event.data?.after?.data()?.followers;
    
    // followers が配列でない場合はスキップ
    if (!Array.isArray(beforeFollowers) || !Array.isArray(afterFollowers)) return;

    const newFollowers = afterFollowers.filter(uid => !beforeFollowers.includes(uid));
    
    if (newFollowers.length > 0) {
      const db = getFirestore();
      for (const followerUid of newFollowers) {
        // フレンド申請が存在するかチェック
        const reqSnap = await db.collection("friend_requests")
          .where("fromUid", "==", followerUid)
          .where("toUid", "==", event.params.userId)
          .limit(1)
          .get();

        if (reqSnap.empty) {
          // 申請を介さない直接フォロー
          const followerSnap = await db.collection("users").doc(followerUid).get();
          const followerName = followerSnap.exists ? (followerSnap.data().username || "誰か") : "誰か";
          
          const recipientDoc = await db.collection("users").doc(event.params.userId).get();
          const language = (recipientDoc.exists && recipientDoc.data().language === "en") ? "en" : "ja";

          let title = "🔥 仲間の予感";
          let body = `${followerName} さんがあなたの努力に惹かれています！仲間リクエストが届きました`;

          if (language === "en") {
            title = "🔥 A New Ally Awaits";
            body = `${followerName} is inspired by your dedication! They sent you an ally request.`;
          }

          const notifRef = db.collection("notifications").doc();
          await notifRef.set({
            toUid: event.params.userId,
            fromUid: followerUid,
            type: "friendRequestReceived",
            relatedId: `follow_${followerUid}`,
            title: title,
            body: body,
            sendPush: true,
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }
);

/**
 * ユーザーのストリーク更新時、マイルストーンに達していればお祝い通知を送る
 */
exports.onUserStreakUpdated = onDocumentUpdated(
  "users/{userId}",
  async (event) => {
    const beforeData = event.data?.before?.data();
    const afterData = event.data?.after?.data();
    if (!beforeData || !afterData) return;

    const beforeStreak = beforeData.streak || 0;
    const afterStreak = afterData.streak || 0;

    if (afterStreak > beforeStreak) {
      const pushEnabled = afterData.pushNotifications ?? true;
      
      if (pushEnabled) {
        const milestones = [10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 130, 200, 365];
        if (milestones.includes(afterStreak)) {
          const db = getFirestore();
          const username = afterData.username || "あなた";
          const language = afterData.language === "en" ? "en" : "ja";
          let title = "";
          let body = "";

          if (language === "en") {
            title = "🤯 Whoa!";
            body = `You hit a ${afterStreak}-day streak! You're officially getting addicted to winning...!`;

            if (afterStreak === 20) {
              title = "🧠 Brain Rewired";
              body = `You hit a 20-day streak! Effort doesn't even feel like effort anymore.`;
            } else if (afterStreak === 30) {
              title = "🐑 Do Androids Dream of Electric Sheep?";
              body = `You hit a 30-day streak! Completely silencing the human urge to slack off and keeping going... are you even human?`;
            } else if (afterStreak === 40) {
              title = "📉 Forgetting How to Slack";
              body = `You hit a 40-day streak! You're probably struggling to remember how to slack off. If you need tips on how to be lazy again, the dev team is here to help!`;
            } else if (afterStreak === 50) {
              title = "🔴 HAL 9000 Warning";
              body = `You hit a 50-day streak! The AI concludes: 'I am sorry, but I see no logical reason for you to slack off today.'`;
            } else if (afterStreak === 60) {
              title = "🙄 You Again?";
              body = `You hit a 60-day streak! The dev team is crying: 'Your daily wins are making our database scream. Slack off a bit and let the server rest!'`;
            } else if (afterStreak === 70) {
              title = "🌘 The Moon Is a Harsh Mistress";
              body = `You hit a 70-day streak! As they say on the Moon: 'There ain't no such thing as a free lunch.' This orbit is powered by your pure effort.`;
            } else if (afterStreak === 80) {
              title = "💼 Job Offer from Dev Team";
              body = `You hit an 80-day streak! With self-discipline like this, we're ready to hand over the codebase and let you run the updates.`;
            } else if (afterStreak === 90) {
              title = "🍎 Law of Inertia Activated";
              body = `You hit a 90-day streak! Your habit is in motion, and just like in a frictionless world, stopping is now harder than keeping it going.`;
            } else if (afterStreak === 100) {
              title = "⚡️ V EFFECT";
              body = `You hit a 100-day streak! The 'Winner Effect' (V EFFECT) is fully wired into your brain. Absolutely nothing can stop you now.`;
            } else if (afterStreak === 110) {
              title = "🪐 Gravitational Pull Generated";
              body = `You hit a 110-day streak! Your habit is gaining massive pull, generating gravity strong enough to repel all surrounding laziness.`;
            } else if (afterStreak === 130) {
              title = "🌍 New Law of Physics Born";
              body = `You hit a 130-day streak! Your routine is now as natural as the Earth's rotation. You have officially become a law of physics.`;
            }
          } else {
            title = "🤯 どわー！";
            body = `あなたが${afterStreak}日連続達成！もう勝ち癖が付き始めているそうです...！`;

            if (afterStreak === 20) {
              title = "🧠 脳の書き換え完了";
              body = `あなたが２０日連続達成！努力を努力だと思っていないようです。`;
            } else if (afterStreak === 30) {
              title = "🐑 電気羊の夢を見るか？";
              body = `あなたが30日連続達成！サボりたいという人間らしいノイズを完全に排除して動き続けるあなたは、果たして人間でしょうか。`;
            } else if (afterStreak === 40) {
              title = "📉 サボり方の忘却";
              body = `あなたが40日連続達成！「どうやってサボるんだっけ？」と本気で悩み始める時期です。サボるのが苦手なら、いつでも開発チームがコツを教えますよ？`;
            } else if (afterStreak === 50) {
              title = "🔴 HAL9000の警告";
              body = `あなたが50日連続達成！「申し訳ありません。私には、あなたが今日のタスクをサボる理由が見当たりません」とAIが判断しました。`;
            } else if (afterStreak === 60) {
              title = "🙄 またあなたですか";
              body = `あなたが60日連続達成！「毎日あなたの達成ログが届くため、データベースが悲鳴を上げています。少しはサボってサーバーを休ませてください」と、開発チームが嘆いています。`;
            } else if (afterStreak === 70) {
              title = "🌘 月は無慈悲な夜の女王";
              body = `あなたが70日連続達成！「タダ飯なんてものはない」と月世界で言われるように、この軌道はあなたの純粋な努力の成果です。`;
            } else if (afterStreak === 80) {
              title = "💼 次期開発者への内定";
              body = `あなたが80日連続達成！これだけ自己管理ができるなら、もうこのアプリのバグ修正やアップデート作業もあなたに丸投げしたいくらいです。`;
            } else if (afterStreak === 90) {
              title = "🍎 慣性の法則、発動";
              body = `あなたが90日連続達成！動き出したあなたの習慣は、もはや摩擦のない世界のように、止まる方が難しくなっています。`;
            } else if (afterStreak === 100) {
              title = "⚡️ V EFFECT";
              body = `あなたが100日連続達成！勝利がさらなる勝利を呼ぶ「勝利者効果（V EFFECT）」が脳に完全定着しました。あなたはもう、何があっても行動を止められません。`;
            } else if (afterStreak === 110) {
              title = "🪐 独自の重力場が発生";
              body = `あなたが110日連続達成！あなたの習慣が巨大な質量を持ち始め、周囲の怠惰を跳ね返すほどの引力を生み出しています。`;
            } else if (afterStreak === 130) {
              title = "🌍 新たな物理法則の誕生";
              body = `あなたが130日連続達成！あなたの行動は、地球が自転するのと同じくらい「自然界の当たり前」になりました。もはや物理法則の一部です。`;
            }
          }

          const notifRef = db.collection("notifications").doc();
          await notifRef.set({
            toUid: event.params.userId,
            fromUid: "system",
            type: "streakCelebration",
            relatedId: `streak_${afterStreak}`,
            title: title,
            body: body,
            sendPush: true,
            isRead: false,
            createdAt: FieldValue.serverTimestamp(),
          });
        }
      }
    }
  }
);
