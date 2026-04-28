const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onCall, HttpsError, onRequest } = require("firebase-functions/v2/https");
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
      // トークンが無効な場合は削除
      if (
        error.code === "messaging/invalid-registration-token" ||
        error.code === "messaging/registration-token-not-registered"
      ) {
        await db.collection("users").doc(toUid).update({
          fcmToken: FieldValue.delete(),
        });
        console.log(`Deleted invalid FCM token for ${toUid}`);
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

// =============================================================================
// OGP 招待カード画像生成エンドポイント
// GET /inviteCard?userId=<userId>
//
// SNS (LINE, X, Instagram等) がリンクプレビューを要求してきたとき、
// そのユーザーの最新情報（名前・ストリーク）を反映した名刺デザインの
// PNG 画像を動的に生成して返す。
// =============================================================================
exports.inviteCard = onRequest(
  { region: "asia-northeast1", cors: true },
  async (req, res) => {
    const userId = req.query.userId;
    if (!userId) {
      res.status(400).send("userId is required");
      return;
    }

    const db = getFirestore();

    // Firestore からユーザー情報を取得（userId フィールドで検索）
    let username = "V EFFECT User";
    let userIdDisplay = userId;
    let streak = 0;

    try {
      const snap = await db
        .collection("users")
        .where("userId", "==", userId)
        .limit(1)
        .get();

      if (!snap.empty) {
        const data = snap.docs[0].data();
        username = data.username || username;
        userIdDisplay = data.userId || userId;
        streak = data.streak || 0;
      }
    } catch (e) {
      console.warn("Firestore fetch error:", e.message);
    }

    // ---- 名刺デザインを SVG テキストとして定義 ----
    // Satori は JSX 風の JS オブジェクトを受け取るが、
    // ここでは依存を最小にするため、直接 SVG 文字列を生成する。
    const W = 1200;
    const H = 630;

    // ストリーク数の桁数に応じてフォントサイズを調整
    const streakStr = String(streak);
    const streakFontSize = streak >= 1000 ? 28 : 36;

    const svg = `
<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}"
     xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
  <defs>
    <linearGradient id="bg" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#0D0D0D"/>
      <stop offset="100%" stop-color="#1A1A1A"/>
    </linearGradient>
    <!-- ゴールドの光彩グラデーション（カード枠） -->
    <linearGradient id="gold" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%"   stop-color="#C9A84C"/>
      <stop offset="50%"  stop-color="#F0D080"/>
      <stop offset="100%" stop-color="#A07820"/>
    </linearGradient>
    <filter id="glow">
      <feGaussianBlur in="SourceGraphic" stdDeviation="8" result="blur"/>
      <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <!-- 角丸クリップ -->
    <clipPath id="card-clip">
      <rect x="0" y="0" width="${W}" height="${H}" rx="32" ry="32"/>
    </clipPath>
  </defs>

  <!-- カード背景 -->
  <rect width="${W}" height="${H}" fill="url(#bg)" rx="32" ry="32"/>

  <!-- ゴールド枠線 -->
  <rect x="2" y="2" width="${W - 4}" height="${H - 4}"
        fill="none" stroke="url(#gold)" stroke-width="2.5" rx="30" ry="30"/>

  <!-- 右上の微光 -->
  <circle cx="${W}" cy="0" r="280" fill="#C9A84C" opacity="0.07"/>

  <!-- 左下の微光 -->
  <circle cx="0" cy="${H}" r="200" fill="#C9A84C" opacity="0.05"/>

  <!-- ===== ヘッダー部 ===== -->
  <!-- V ロゴ（シンプルなテキストで代替） -->
  <text x="64" y="88"
        font-family="Georgia, serif"
        font-size="52"
        font-weight="bold"
        fill="url(#gold)"
        filter="url(#glow)">V</text>

  <!-- EFFECT テキスト -->
  <text x="112" y="88"
        font-family="'Helvetica Neue', Arial, sans-serif"
        font-size="38"
        font-weight="800"
        letter-spacing="6"
        fill="#FFFFFF">EFFECT</text>

  <!-- 区切り線（ゴールド） -->
  <line x1="64" y1="108" x2="${W - 64}" y2="108"
        stroke="url(#gold)" stroke-width="0.8" opacity="0.5"/>

  <!-- ===== 右上 ストリーク ===== -->
  <!-- 炎アイコン（Unicode） -->
  <text x="${W - 64 - streakStr.length * streakFontSize * 0.6 - 44}" y="84"
        font-size="40"
        text-anchor="start">🔥</text>
  <text x="${W - 64}" y="84"
        font-family="'Helvetica Neue', Arial, sans-serif"
        font-size="${streakFontSize}"
        font-weight="700"
        fill="url(#gold)"
        text-anchor="end">${streakStr}</text>

  <!-- ===== 中央 ユーザー情報 ===== -->
  <!-- ユーザー名 -->
  <text x="${W / 2}" y="${H / 2 - 40}"
        font-family="Georgia, 'Times New Roman', serif"
        font-size="96"
        font-weight="bold"
        fill="#FFFFFF"
        text-anchor="middle"
        dominant-baseline="middle">${_truncate(username, 14)}</text>

  <!-- ユーザーID -->
  <text x="${W / 2}" y="${H / 2 + 60}"
        font-family="'Helvetica Neue', Arial, sans-serif"
        font-size="36"
        fill="#888888"
        letter-spacing="2"
        text-anchor="middle"
        dominant-baseline="middle">@${_truncate(userIdDisplay, 20)}</text>

  <!-- ===== フッター ===== -->
  <!-- 区切り線 -->
  <line x1="64" y1="${H - 108}" x2="${W - 64}" y2="${H - 108}"
        stroke="url(#gold)" stroke-width="0.8" opacity="0.5"/>

  <!-- フレンドからの招待テキスト -->
  <text x="${W / 2}" y="${H - 58}"
        font-family="'Helvetica Neue', Arial, sans-serif"
        font-size="28"
        letter-spacing="4"
        fill="url(#gold)"
        text-anchor="middle"
        dominant-baseline="middle">フレンドからの招待</text>
</svg>`;

    // ---- SVG → PNG 変換 ----
    try {
      const { Resvg } = require("@resvg/resvg-js");
      const resvg = new Resvg(svg, {
        fitTo: { mode: "width", value: W },
        font: { loadSystemFonts: true },
      });
      const pngData = resvg.render();
      const pngBuffer = pngData.asPng();

      // 24時間キャッシュ（CDN でもキャッシュ）
      res.set("Cache-Control", "public, max-age=86400, s-maxage=86400");
      res.set("Content-Type", "image/png");
      res.status(200).send(pngBuffer);
    } catch (e) {
      console.error("PNG render error:", e);
      res.status(500).send("Image generation failed");
    }
  }
);

/** テキストを指定文字数で切り詰める */
function _truncate(str, maxLen) {
  if (!str) return "";
  return str.length > maxLen ? str.slice(0, maxLen) + "…" : str;
}

// =============================================================================
// ユーザー招待ページ（OGP 動的生成 + ディープリンク ディスパッチャー）
// /u/:userId または /u?id=userId
//
// - SNS bot (LINE, X, Slack等) が UA を見て判定されたとき:
//     → OGP メタタグと og:image (inviteCard Function の URL) を含む HTML を返す
// - 一般ユーザー (ブラウザ) の場合:
//     → アプリ起動ディープリンク + App Store フォールバックを含む HTML を返す
// =============================================================================
exports.userInvitePage = onRequest(
  { region: "asia-northeast1" },
  async (req, res) => {
    // /u/yusuke → yusuke を抽出
    const pathParts = req.path.replace(/^\/u\/?/, "").split("/").filter(Boolean);
    const userId = pathParts[0] || req.query.id || "";

    const db = getFirestore();
    let username = "V EFFECT User";
    let streak   = 0;

    if (userId) {
      try {
        const snap = await db
          .collection("users")
          .where("userId", "==", userId)
          .limit(1)
          .get();
        if (!snap.empty) {
          const d = snap.docs[0].data();
          username = d.username || username;
          streak   = d.streak   || 0;
        }
      } catch (e) {
        console.warn("Firestore fetch error:", e.message);
      }
    }

    // Cloud Functions のベース URL
    const region   = "asia-northeast1";
    const projectId = process.env.GCLOUD_PROJECT || "veffect";
    const fnBaseUrl = `https://${region}-${projectId}.cloudfunctions.net`;

    // og:image は inviteCard Function に向ける
    const ogImageUrl = `${fnBaseUrl}/inviteCard?userId=${encodeURIComponent(userId)}`;
    const pageUrl    = `https://veffect.web.app/u/${encodeURIComponent(userId)}`;
    const deepLink   = `veffect://user/${encodeURIComponent(userId)}`;
    const appStoreUrl   = "https://apps.apple.com/app/YOUR_APP_STORE_ID";
    const playStoreUrl  = "https://play.google.com/store/apps/details?id=com.veffect.app";

    const escapedUsername = username.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    const escapedUserId   = userId.replace(/&/g, "&amp;");

    const html = `<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width, initial-scale=1.0"/>
  <title>${escapedUsername} | V EFFECT – フレンドからの招待</title>
  <meta name="description" content="${escapedUsername} (@${escapedUserId}) があなたをV EFFECTに招待しています。🔥 ${streak}日連続ストリーク中！"/>

  <!-- OGP -->
  <meta property="og:site_name"    content="V EFFECT"/>
  <meta property="og:type"         content="profile"/>
  <meta property="og:url"          content="${pageUrl}"/>
  <meta property="og:title"        content="${escapedUsername} | V EFFECT – フレンドからの招待"/>
  <meta property="og:description"  content="🔥 ${streak}日連続ストリーク中！V EFFECTでフレンドになろう。"/>
  <meta property="og:image"        content="${ogImageUrl}"/>
  <meta property="og:image:width"  content="1200"/>
  <meta property="og:image:height" content="630"/>
  <meta property="og:image:type"   content="image/png"/>

  <!-- Twitter Card -->
  <meta name="twitter:card"        content="summary_large_image"/>
  <meta name="twitter:title"       content="${escapedUsername} | V EFFECT – フレンドからの招待"/>
  <meta name="twitter:description" content="🔥 ${streak}日連続ストリーク中！V EFFECTでフレンドになろう。"/>
  <meta name="twitter:image"       content="${ogImageUrl}"/>

  <!-- LINE -->
  <meta property="og:locale" content="ja_JP"/>

  <style>
    *{margin:0;padding:0;box-sizing:border-box}
    body{font-family:-apple-system,'Helvetica Neue',Arial,sans-serif;background:#0D0D0D;color:#fff;min-height:100vh;display:flex;flex-direction:column;align-items:center;justify-content:center;padding:24px}
    .card{background:linear-gradient(135deg,#141414,#1F1F1F);border:1.5px solid rgba(201,168,76,.35);border-radius:24px;padding:48px 56px;max-width:480px;width:100%;text-align:center;box-shadow:0 0 60px rgba(201,168,76,.1)}
    .logo{font-size:13px;letter-spacing:6px;color:#C9A84C;margin-bottom:32px;font-weight:700}
    .logo span{font-size:22px;font-weight:900;margin-right:4px}
    .username{font-size:42px;font-weight:800;margin-bottom:8px}
    .userid{font-size:16px;color:#666;letter-spacing:1px;margin-bottom:12px}
    .streak{font-size:14px;color:#C9A84C;margin-bottom:36px;letter-spacing:1px}
    .tag{font-size:12px;letter-spacing:4px;color:#C9A84C;margin-bottom:36px;text-transform:uppercase}
    .btn{display:inline-block;background:linear-gradient(135deg,#C9A84C,#F0D080,#A07820);color:#000;font-weight:700;font-size:16px;padding:16px 40px;border-radius:50px;text-decoration:none;letter-spacing:.5px;transition:opacity .2s;cursor:pointer;border:none;width:100%}
    .btn:hover{opacity:.85}
    .store{margin-top:20px;font-size:12px;color:#555}
    .store a{color:#777;text-decoration:underline;margin:0 8px}
  </style>
</head>
<body>
  <div class="card">
    <div class="logo"><span>V</span>EFFECT</div>
    <div class="username">${escapedUsername}</div>
    <div class="userid">@${escapedUserId}</div>
    <div class="streak">🔥 ${streak} 日連続ストリーク</div>
    <div class="tag">フレンドからの招待</div>
    <button class="btn" onclick="openApp()">V EFFECTで開く</button>
    <div class="store">
      <a href="${appStoreUrl}">App Store</a>
      <a href="${playStoreUrl}">Google Play</a>
    </div>
  </div>
  <script>
    function openApp() {
      const deepLink = '${deepLink}';
      const fallback = /iPhone|iPad|iPod/.test(navigator.userAgent)
        ? '${appStoreUrl}'
        : '${playStoreUrl}';
      window.location.href = deepLink;
      setTimeout(() => { window.location.href = fallback; }, 1500);
    }
  </script>
</body>
</html>`;

    res.set("Cache-Control", "public, max-age=300, s-maxage=300");
    res.set("Content-Type",  "text/html; charset=utf-8");
    res.status(200).send(html);
  }
);
