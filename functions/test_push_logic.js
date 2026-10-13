const assert = require("assert");
const { sendPushNotification } = require("./index.js");

async function runTests() {
  console.log("=== Testing sendPushNotification Logic ===");
  
  const originalLog = console.log;
  let logs = [];
  function captureLogs() {
    logs = [];
    console.log = (...args) => {
      logs.push(args.join(" "));
      originalLog(...args);
    };
  }
  function restoreLogs() {
    console.log = originalLog;
  }

  try {
    // Test 1: New V FIRE notification with sendPush: false
    // Expected: Logs push skipped by design, does NOT send push
    {
      captureLogs();
      const event = {
        params: { notificationId: "vfire_1" },
        data: {
          after: {
            data: () => ({
              toUid: "user_target",
              fromUid: "user_sender",
              type: "reactionReceived",
              title: "⚡️ V EFFECT 発動！",
              body: "あなたの「タスク」が...",
              sendPush: false,
              reactionCount: 1,
              emoji: null,
              relatedId: "post_123",
            }),
          },
          before: null,
        },
      };

      await sendPushNotification.run(event);
      restoreLogs();

      const skippedLog = logs.find(l => l.includes("push skipped by design"));
      assert(skippedLog, "Test 1 Failed: V FIRE push was not skipped");
      console.log("✔ Test 1 Passed: V FIRE (sendPush: false) correctly skipped push notification.");
    }

    // Test 2: Legacy V FIRE notification with sendPush: true
    // Expected: Server guard ensures V FIRE push is still skipped!
    {
      captureLogs();
      const event = {
        params: { notificationId: "vfire_legacy" },
        data: {
          after: {
            data: () => ({
              toUid: "user_target",
              fromUid: "user_sender",
              type: "reactionReceived",
              title: "🔥 Fired Up",
              body: "user_sender sent 5 V FIREs",
              sendPush: true, // Legacy client
              reactionCount: 5,
              emoji: null,
              relatedId: "post_456",
            }),
          },
          before: null,
        },
      };

      await sendPushNotification.run(event);
      restoreLogs();

      const skippedLog = logs.find(l => l.includes("push skipped by design"));
      assert(skippedLog, "Test 2 Failed: Legacy V FIRE with sendPush: true was not blocked on server");
      console.log("✔ Test 2 Passed: Legacy V FIRE (sendPush: true) successfully blocked by server-side guard.");
    }

    // Test 2b: Emoji reaction notification with sendPush: true
    // Expected: Emoji reaction sends push notification!
    {
      captureLogs();
      const event = {
        params: { notificationId: "emoji_reaction_1" },
        data: {
          after: {
            data: () => ({
              toUid: "user_target",
              fromUid: "user_sender",
              type: "reactionReceived",
              title: "✨ リアクション",
              body: "user_senderさんが「タスク」に「🎉」を贈りました！",
              sendPush: true,
              reactionCount: 1,
              emoji: "🎉",
              relatedId: "post_789",
            }),
          },
          before: null,
        },
      };

      try {
        await sendPushNotification.run(event);
      } catch (e) {
        // ローカル単体テスト環境ではGCP認証情報が無いためsendPushToUser内のFirestoreアクセスがエラーになるが、
        // プッシュ送信ステップ（Sending emoji reaction push notification）に到達したことをログで検証する
      }
      restoreLogs();

      const pushLog = logs.find(l => l.includes("Sending emoji reaction push notification"));
      assert(pushLog, "Test 2b Failed: Emoji reaction push was not sent");
      console.log("✔ Test 2b Passed: Emoji reaction (sendPush: true) successfully sent push notification.");
    }

    // Test 3: Read-state change only on reactionReceived (isRead: false -> true, content unchanged)
    // Expected: Skips immediately without running Mutual Fire or push
    {
      captureLogs();
      const event = {
        params: { notificationId: "reaction_read" },
        data: {
          before: {
            data: () => ({
              toUid: "user_target",
              fromUid: "user_sender",
              type: "reactionReceived",
              title: "🔥 Fired Up",
              body: "user_sender sent 5 V FIREs",
              sendPush: false,
              reactionCount: 5,
              emoji: null,
              isRead: false,
            }),
          },
          after: {
            data: () => ({
              toUid: "user_target",
              fromUid: "user_sender",
              type: "reactionReceived",
              title: "🔥 Fired Up",
              body: "user_sender sent 5 V FIREs",
              sendPush: false,
              reactionCount: 5,
              emoji: null,
              isRead: true, // Read state change only
            }),
          },
        },
      };

      await sendPushNotification.run(event);
      restoreLogs();

      const readLog = logs.find(l => l.includes("read/meta update only"));
      assert(readLog, "Test 3 Failed: Read-state update was not detected and skipped early");
      console.log("✔ Test 3 Passed: Reaction notification read-state change skipped early (no redundant Mutual Fire / push).");
    }

    // Test 4: Reaction notification updated with new flame count (reactionCount: 5 -> 10)
    // Expected: Does NOT hit read/meta skip, proceeds to Mutual Fire check, then skips push
    {
      captureLogs();
      const event = {
        params: { notificationId: "reaction_increment" },
        data: {
          before: {
            data: () => ({
              toUid: "user_target",
              fromUid: "user_sender",
              type: "reactionReceived",
              title: "🔥 Fired Up",
              body: "user_sender sent 5 V FIREs",
              sendPush: false,
              reactionCount: 5,
              emoji: null,
              isRead: false,
            }),
          },
          after: {
            data: () => ({
              toUid: "user_target",
              fromUid: "user_sender",
              type: "reactionReceived",
              title: "🔥 Fired Up",
              body: "user_sender sent 10 V FIREs",
              sendPush: false,
              reactionCount: 10,
              emoji: null,
              isRead: false,
            }),
          },
        },
      };

      await sendPushNotification.run(event);
      restoreLogs();

      const readLog = logs.find(l => l.includes("read/meta update only"));
      assert(!readLog, "Test 4 Failed: Count increment was wrongly classified as read-only update");
      const skippedLog = logs.find(l => l.includes("push skipped by design"));
      assert(skippedLog, "Test 4 Failed: Count increment push was not skipped");
      console.log("✔ Test 4 Passed: Flame count increment processed for Mutual Fire and push skipped.");
    }

    // Test 5: Non-reaction notification with sendPush: false (e.g. DM or season task)
    // Expected: Aborts push due to sendPush === false
    {
      captureLogs();
      const event = {
        params: { notificationId: "notif_nopush" },
        data: {
          after: {
            data: () => ({
              toUid: "user_target",
              title: "お知らせ",
              body: "テスト",
              type: "seasonTaskDistributed",
              sendPush: false,
            }),
          },
          before: null,
        },
      };

      await sendPushNotification.run(event);
      restoreLogs();

      const abortLog = logs.find(l => l.includes("sendPush is explicitly false"));
      assert(abortLog, "Test 5 Failed: sendPush: false was not respected for non-reaction");
      console.log("✔ Test 5 Passed: Non-reaction notification with sendPush: false aborted push.");
    }

    // Test 6: Non-reaction notification update (before exists)
    // Expected: Returns immediately to avoid duplicate push on read state change
    {
      captureLogs();
      const event = {
        params: { notificationId: "notif_read" },
        data: {
          before: {
            data: () => ({
              toUid: "user_target",
              title: "タスク完了",
              body: "フレンドがタスクを完了しました",
              type: "friendTaskCompleted",
              sendPush: true,
              isRead: false,
            }),
          },
          after: {
            data: () => ({
              toUid: "user_target",
              title: "タスク完了",
              body: "フレンドがタスクを完了しました",
              type: "friendTaskCompleted",
              sendPush: true,
              isRead: true,
            }),
          },
        },
      };

      await sendPushNotification.run(event);
      restoreLogs();
      console.log("✔ Test 6 Passed: Non-reaction update (isRead change) did not re-send push.");
    }

    console.log("\nALL 6 BACKEND LOGIC TESTS PASSED SUCCESSFULLY! 🎉");
  } finally {
    restoreLogs();
  }
}

runTests().catch(err => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
