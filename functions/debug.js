const admin = require('firebase-admin');
admin.initializeApp({ projectId: 'veffect' });
const db = admin.firestore();

async function run() {
  const users = await db.collection('users').get();
  for (const doc of users.docs) {
    const tasks = doc.data().tasks;
    if (tasks && tasks.some(t => t.title && t.title.includes('感謝'))) {
      console.log('USER:', doc.id, doc.data().displayName);
      console.log('TASKS:', JSON.stringify(tasks, null, 2));
      
      const posts = await db.collection('posts').where('userId', '==', doc.id).get();
      console.log(`POSTS for ${doc.id}:`);
      for (const p of posts.docs) {
        if (p.data().taskName && p.data().taskName.includes('感謝')) {
          console.log(p.id, p.data().taskName, p.data().createdAt?.toDate());
        }
      }
    }
  }
  
  const seasons = await db.collection('seasons').get();
  console.log('SEASONS:');
  for (const doc of seasons.docs) {
    console.log(doc.id, doc.data().taskName, doc.data().startDate?.toDate(), doc.data().endDate?.toDate());
  }
}

run().catch(console.error);
