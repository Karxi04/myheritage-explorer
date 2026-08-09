'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const {
  getFirestore,
  FieldValue,
} = require('firebase-admin/firestore');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('Missing firestore_seed/serviceAccountKey.json');
  process.exit(1);
}

initializeApp({
  credential: cert(require(serviceAccountPath)),
});

const auth = getAuth();
const db = getFirestore();
const CONFIRM_TOKEN = 'ENSURE_ADMIN_ACCOUNT';
const confirmed = process.argv.includes('--confirm') &&
  process.argv.includes(CONFIRM_TOKEN);
const email = String(
  process.env.ADMIN_EMAIL || 'admin@myheritage.com',
).trim().toLowerCase();
const password = String(process.env.ADMIN_PASSWORD || 'Admin123!');
const displayName = String(
  process.env.ADMIN_DISPLAY_NAME || 'System Administrator',
).trim();

async function main() {
  let user;

  try {
    user = await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }

  const uid = user?.uid || '(new Firebase Auth user)';
  const adminRef = user ? db.collection('admins').doc(user.uid) : null;
  const profile = adminRef ? await adminRef.get() : null;

  console.log('');
  console.log('Admin account repair');
  console.log(`Email: ${email}`);
  console.log(`UID: ${uid}`);
  console.log(`Auth user exists: ${Boolean(user)}`);
  console.log(`Admin profile exists: ${Boolean(profile?.exists)}`);
  console.log(`Password to set: ${password}`);

  if (!confirmed) {
    console.log('');
    console.log('DRY RUN ONLY. Nothing was changed.');
    console.log(`Run with: node ensure_admin_account.js --confirm ${CONFIRM_TOKEN}`);
    console.log('Optional: set ADMIN_EMAIL, ADMIN_PASSWORD or ADMIN_DISPLAY_NAME.');
    return;
  }

  if (user) {
    user = await auth.updateUser(user.uid, {
      password,
      displayName,
      disabled: false,
      emailVerified: true,
    });
  } else {
    user = await auth.createUser({
      email,
      password,
      displayName,
      disabled: false,
      emailVerified: true,
    });
  }

  await db.collection('admins').doc(user.uid).set({
    uid: user.uid,
    email,
    displayName,
    name: displayName,
    fullName: displayName,
    role: 'admin',
    status: 'active',
    emailVerified: true,
    updatedAt: FieldValue.serverTimestamp(),
    repairedAt: FieldValue.serverTimestamp(),
  }, { merge: true });

  console.log('');
  console.log('Admin account repaired.');
  console.log(`Login email: ${email}`);
  console.log(`Login password: ${password}`);
  console.log(`Admin profile: admins/${user.uid}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Admin account repair failed.');
    console.error(error);
    process.exit(1);
  });
