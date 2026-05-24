const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault()
});

const db = admin.firestore();

async function fixNotifications() {
  const notificationsSnap = await db.collection('notifications')
    .where('type', '==', 'friendRequestReceived')
    .where('isProcessed', '==', false)
    .get();

  console.log(`Found ${notificationsSnap.size} unprocessed friend request notifications.`);

  let fixedCount = 0;
  const batch = db.batch();
  let batchCount = 0;

  for (const doc of notificationsSnap.docs) {
    const data = doc.data();
    if (!data.relatedId) continue;

    const reqSnap = await db.collection('friend_requests').doc(data.relatedId).get();
    
    // If the request doesn't exist, or status is NOT 'pending', it means it's already processed.
    if (!reqSnap.exists || reqSnap.data().status !== 'pending') {
      console.log(`Fixing notification ${doc.id} (request ${data.relatedId} is ${reqSnap.exists ? reqSnap.data().status : 'deleted'})`);
      batch.update(doc.ref, { isProcessed: true });
      fixedCount++;
      batchCount++;

      if (batchCount >= 400) {
        await batch.commit();
        batchCount = 0;
        console.log('Committed batch of 400');
      }
    }
  }

  if (batchCount > 0) {
    await batch.commit();
    console.log(`Committed final batch of ${batchCount}`);
  }

  console.log(`Successfully fixed ${fixedCount} notifications.`);
}

fixNotifications().catch(console.error);
