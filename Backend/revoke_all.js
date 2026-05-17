const admin = require("firebase-admin");
const path = require("path");

// Path to your service account JSON
const serviceAccount = require(path.join(__dirname, "serviceAccount.json"));

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

async function revokeAll(nextPageToken) {
  const result = await admin.auth().listUsers(1000, nextPageToken);
  const users = result.users;

  for (const u of users) {
    await admin.auth().revokeRefreshTokens(u.uid);
    console.log("Revoked:", u.uid, u.email || u.phoneNumber || "");
  }

  if (result.pageToken) {
    await revokeAll(result.pageToken);
  }
}

revokeAll()
  .then(() => {
    console.log("✅ Done revoking all users");
    process.exit(0);
  })
  .catch((e) => {
    console.error("❌ Error:", e);
    process.exit(1);
  });
