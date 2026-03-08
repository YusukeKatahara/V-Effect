const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { initializeApp } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getMessaging } = require("firebase-admin/messaging");
const { getAuth } = require("firebase-admin/auth");

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

    const { toUid, title, body } = data;
    if (!toUid || !title) return;

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
          fcmToken: require("firebase-admin/firestore").FieldValue.delete(),
        });
      }
    }
  }
);

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
