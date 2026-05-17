import * as admin from 'firebase-admin';
import { getFirebaseAdminApp } from '../auth/firebase-admin';

async function run() {
  const app = getFirebaseAdminApp();

  const uid = 'fpX6suHolEVyIdtzlcGOEwSpMfs1'; // <-- your captain uid

  await app.auth().setCustomUserClaims(uid, {
    role: 'CAPTAIN',
  });

  console.log('✅ Role CAPTAIN added to Firebase token for', uid);
}

run().catch(console.error);