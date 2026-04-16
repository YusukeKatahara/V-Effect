const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");
const { getStorage } = require("firebase-admin/storage");

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

    // 受信者の FCM トークンを取得
    const userDoc = await db.collection("users").doc(toUid).get();
    if (!userDoc.exists) return;

    const fcmToken = userDoc.data().fcmToken;
    if (!fcmToken) return;

    // FCM メッセージを送信
    const message = {
      token: fcmToken,
      notification: {
        title: title,
        body: body || "",
      },
      android: {
        priority: "high",
        notification: {
          channelId: "veffect_notifications",
          defaultSound: true,
        },
      },
      apns: {
        payload: {
          aps: {
            sound: "default",
            badge: 1,
          },
        },
      },
    };

    try {
      await getMessaging().send(message);
    } catch (error) {
      // トークンが無効な場合は削除
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(toUid).update({
          fcmToken: FieldValue.delete(),
        });
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
 * ユーザーIDとパスワードを用いてログインするためのカスタム認証トークンを発行する
 *
 * クライアントから呼び出し:
 *   FirebaseFunctions.instance.httpsCallable('loginWithUserId')
 *     .call({ userId: '...', password: '...', apiKey: '...' })
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
    throw new HttpsError("unauthenticated", "ユーザーIDまたはパスワードが正しくありません。");
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
