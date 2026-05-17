import { PrismaClient } from '@prisma/client';
import { getFirebaseAuth, getFirebaseAdminApp } from '../src/firebase/firebase-admin.provider';
import * as admin from 'firebase-admin';

async function main() {
  const prisma = new PrismaClient();
  const auth = getFirebaseAuth();
  const app = getFirebaseAdminApp(); // ✅ use same initialized app
  const db = app.firestore();

  const email = process.env.ADMIN_EMAIL;
  if (!email) throw new Error('Missing ADMIN_EMAIL');

  // 1) Find existing firebase user
  const fb = await auth.getUserByEmail(email);

  // 2) Upsert dashboard user in Postgres
  const user = await prisma.dashboardUser.upsert({
    where: { firebaseUid: fb.uid },
    create: {
      firebaseUid: fb.uid,
      email: (fb.email ?? email).toLowerCase(),
      name: fb.displayName ?? null,
      role: 'SUPER_ADMIN',
      isActive: true,
      permissions: { create: [{ key: 'ADMIN_USERS_MANAGE' }] },
    },
    update: {
      email: (fb.email ?? email).toLowerCase(),
      role: 'SUPER_ADMIN',
      isActive: true,
    },
    include: { permissions: true },
  });

  // 3) Ensure permission exists
  await prisma.dashboardPermission.upsert({
    where: {
      dashboardUserId_key: {
        dashboardUserId: user.id,
        key: 'ADMIN_USERS_MANAGE',
      },
    },
    create: {
      dashboardUserId: user.id,
      key: 'ADMIN_USERS_MANAGE',
    },
    update: {},
  });

  // ✅ 4) Create/Update Firestore admins/{uid}
  await db.collection('admins').doc(fb.uid).set(
    {
      email: (fb.email ?? email).toLowerCase(),
      role: 'SUPER_ADMIN',
      active: true,
      dashboardUserId: user.id,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true }
  );

  // ✅ 5) Set custom claims (if dashboard checks token claims)
  await auth.setCustomUserClaims(fb.uid, {
    admin: true,
    role: 'SUPER_ADMIN',
  });

  console.log('✅ SUPER_ADMIN ready:', user.email);
  console.log('   UID:', fb.uid);
  console.log('   Firestore doc: admins/' + fb.uid);
  console.log('   Custom claims set');

  await prisma.$disconnect();
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});