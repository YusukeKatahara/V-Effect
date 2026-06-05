const admin = require("firebase-admin");

admin.initializeApp({
  projectId: "veffect"
});

const db = admin.firestore();

async function main() {
  console.log("Fetching past posts...");
  const postsSnap = await db.collection("posts").get();
  
  const counts = {};
  postsSnap.forEach(doc => {
    const data = doc.data();
    const taskName = data.taskName;
    if (taskName) {
      // 過去データは AIカテゴリがないので、そのままタスク名を使用する
      // 便宜上、カテゴリは「その他」にしておく
      const cat = "その他";
      const key = `${cat}::${taskName}`;
      counts[key] = (counts[key] || 0) + 1;
    }
  });

  console.log("Aggregating...");
  const sorted = Object.entries(counts)
    .map(([key, count]) => {
      const [category, name] = key.split("::");
      return { category, name, count };
    })
    .sort((a, b) => b.count - a.count)
    .slice(0, 10); // 上位10件

  console.log("Top trends:", sorted);

  await db.collection("global_stats").doc("trends").set({
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    trends: sorted,
  });

  console.log("Done! Trends saved to Firestore.");
}

main().catch(console.error);
