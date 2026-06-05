const fs = require('fs');
const file = 'functions/index.js';
let content = fs.readFileSync(file, 'utf8');

// replace the add() with set() using deterministic ID
content = content.replace(
  /const notifRef = db\.collection\("notifications"\)\.doc\(\);/g,
  'const notifId = `post_${postId}_to_${friendUid}`;\n      const notifRef = db.collection("notifications").doc(notifId);'
);

fs.writeFileSync(file, content, 'utf8');
console.log('Updated functions/index.js');
