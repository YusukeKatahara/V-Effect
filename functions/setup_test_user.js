const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "veffect"
});

const db = admin.firestore();

async function main() {
  console.log("Searching for user @ilikeu / rennsub...");
  const snap = await db.collection("users").where("userId", "==", "ilikeu").get();
  
  if (snap.empty) {
    console.log("User @ilikeu not found via userId, searching by username...");
    const snap2 = await db.collection("users").where("username", "==", "rennsub").get();
    if (snap2.empty) {
      console.error("User not found!");
      return;
    }
    updateUser(snap2.docs[0]);
  } else {
    updateUser(snap.docs[0]);
  }
}

async function updateUser(doc) {
  const uid = doc.id;
  const data = doc.data();
  console.log(`Found user ${data.username} (@${data.userId}) with UID: ${uid}`);

  await db.collection("users").doc(uid).update({
    isRescueActive: true,
    prevStreak: 10,
    streak: 1,
    lastPostedDate: "2026-07-21", // 一昨日に設定して救済中状態にする
  });

  console.log("SUCCESS! Test state updated for @ilikeu:");
  console.log("- isRescueActive: true");
  console.log("- prevStreak: 10");
  console.log("- lastPostedDate: 2026-07-21");
}

main().catch(console.error);
