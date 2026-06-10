const { initializeApp } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp();
const db = getFirestore();

async function main() {
  const notifs = await db.collection('notifications')
    .where('type', '==', 'reactionReceived')
    .orderBy('createdAt', 'desc')
    .limit(5)
    .get();
  
  if (notifs.empty) {
    console.log("No reactionReceived notifications found.");
  } else {
    notifs.forEach(doc => console.log(doc.id, doc.data()));
  }
}
main().catch(console.error);
