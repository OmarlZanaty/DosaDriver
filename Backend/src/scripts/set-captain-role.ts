#!/usr/bin/env ts-node
/**
 * Admin script: Set a Firebase user's Custom Claim role to CAPTAIN or RIDER.
 * Run: ts-node src/scripts/set-captain-role.ts <uid> <CAPTAIN|RIDER|ADMIN>
 *
 * This is the ONLY way roles should be assigned — never via client Firestore writes.
 */
import * as admin from 'firebase-admin';
import * as path from 'path';

const [, , uid, role] = process.argv;

if (!uid || !role) {
  console.error('Usage: ts-node set-captain-role.ts <uid> <CAPTAIN|RIDER|ADMIN>');
  process.exit(1);
}

const validRoles = ['CAPTAIN', 'RIDER', 'ADMIN'];
if (!validRoles.includes(role.toUpperCase())) {
  console.error(`Invalid role. Must be one of: ${validRoles.join(', ')}`);
  process.exit(1);
}

const saPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH
  ?? path.join(__dirname, '../../serviceAccount.json.json');

const serviceAccount = require(saPath);
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

(async () => {
  await admin.auth().setCustomUserClaims(uid, { role: role.toUpperCase() });
  console.log(`✅ Set role=${role.toUpperCase()} for uid=${uid}`);
  console.log('ℹ️  User must sign out and sign in again for the new token to take effect.');
  process.exit(0);
})();
