const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");
const nodemailer = require("nodemailer");

initializeApp();

/**
 * notifications コレクションに新しいドキュメントが作成されたとき、
 * 受信者の FCM トークンを取得してプッシュ通知を送信する
 */
exports.sendPushNotification = onDocumentCreated(
  "notifications/{notificationId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;

    const { toUid, title, body, sendPush } = data;
    if (!toUid || !title) return;

    // フロントエンドで指定されたプッシュ送出フラグをチェック
    // sendPush が明示的に false の場合（V FIREリアクション等）は送信しない
    if (sendPush === false) {
      return;
    }

    const db = getFirestore();

    // 受信者の公開情報を取得（プッシュ通知設定の確認用）
    const userDoc = await db.collection("users").doc(toUid).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();

    // マスターのプッシュ通知設定をチェック
    if (userData.pushNotifications === false) {
      return;
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

    // FCM メッセージを送信
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        ...(body ? { body: body } : {}),
      },
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
            badge: 1,
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
      const warningEnabled = userData.streakWarningNotifications !== false;
      if (!pushEnabled || !warningEnabled) return;

      if (userData.lastPostedDate !== today) {
        const streak = userData.streak || 0;
        
        const title = "⚠️ ストリークの危機！";
        const body = `今日のV Questがまだ完了していません。このままでは${streak}日間の継続が途切れてしまいます！`;

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
    
    // 全ユーザーに通知とタスク追加をバッチで処理（最大500件の操作制限を考慮）
    let batch = db.batch();
    let count = 0;
    
    const newTask = {
      title: taskName,
      isOneTime: false,
      isSeason: true,
      seasonId: seasonId,
    };

    for (const doc of usersSnap.docs) {
      const userRef = doc.ref;
      
      // タスク追加
      batch.update(userRef, {
        tasks: FieldValue.arrayUnion(newTask)
      });
      
      // 通知追加
      const notificationRef = db.collection("notifications").doc();
      batch.set(notificationRef, {
        toUid: doc.id,
        type: "seasonTaskReceived",
        title: "おや、シーズンタスクが届いたようです...！",
        body: `期間限定タスク「${taskName}」が追加されました。`,
        isRead: false,
        sendPush: true,
        createdAt: FieldValue.serverTimestamp(),
      });
      
      count += 2; // 1ユーザーにつき update と set の2操作
      
      if (count >= 490) {
        await batch.commit();
        batch = db.batch();
        count = 0;
      }
    }
    
    if (count > 0) {
      await batch.commit();
    }
    
    console.log(`Distributed season task "${taskName}" to ${usersSnap.size} users.`);
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
