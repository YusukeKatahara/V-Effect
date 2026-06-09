const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "veffect"
});

const db = admin.firestore();

async function main() {
  const badgeUrl = "assets/icon/gratitude_heart_badge.png";
  const targetUserId = "rennlikeu";
  
  const snapshot = await db.collection("users").where("userId", "==", targetUserId).get();
  
  if (snapshot.empty) {
    console.log("User not found: " + targetUserId);
    return;
  }
  
  const userDoc = snapshot.docs[0];
  const userData = userDoc.data();
  const ownedBadges = userData.ownedBadges || [];
  
  if (!ownedBadges.includes(badgeUrl)) {
    ownedBadges.push(badgeUrl);
    await userDoc.ref.update({ ownedBadges });
    console.log(`Successfully gave badge to ${targetUserId}!`);
  } else {
    console.log(`${targetUserId} already has this badge.`);
  }
}

main().catch(console.error);
