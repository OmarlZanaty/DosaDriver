import * as admin from 'firebase-admin';

function loadServiceAccountJson(): admin.ServiceAccount {
  const raw = process.env.FIREBASE_SERVICE_ACCOUNT_JSON;

  if (!raw || raw.trim().length === 0) {
    throw new Error('Missing FIREBASE_SERVICE_ACCOUNT_JSON env var');
  }

  let s = raw.trim();

  // remove wrapping quotes if present
  if (
    (s.startsWith('"') && s.endsWith('"')) ||
    (s.startsWith("'") && s.endsWith("'"))
  ) {
    s = s.slice(1, -1).trim();
  }

  const obj = JSON.parse(s);

  // fix escaped newlines in private_key
  if (typeof (obj as any).private_key === 'string') {
    (obj as any).private_key = (obj as any).private_key.replace(/\\n/g, '\n');
  }

  return obj as admin.ServiceAccount;
}

export function getFirebaseAdminApp(): admin.app.App {
  if (admin.apps.length) return admin.app();

  const serviceAccount = loadServiceAccountJson();

  return admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
}

export function getFirebaseAuth() {
  return getFirebaseAdminApp().auth();
}

export function getFirestore() {
  return getFirebaseAdminApp().firestore();
}