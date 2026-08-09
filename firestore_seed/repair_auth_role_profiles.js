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
const CONFIRM_TOKEN = 'REPAIR_AUTH_ROLE_PROFILES';
const confirmed = process.argv.includes('--confirm') &&
  process.argv.includes(CONFIRM_TOKEN);
const defaultPassword = String(
  process.env.REPAIR_DEFAULT_PASSWORD || 'MyHeritage123!',
);

const roleCollections = [
  { name: 'admins', role: 'admin' },
  { name: 'travelers', role: 'traveler' },
  { name: 'vendors', role: 'vendor' },
];

function serialise(value) {
  if (value == null) return value;

  if (typeof value?.toDate === 'function') {
    return {
      __type: 'Timestamp',
      value: value.toDate().toISOString(),
    };
  }

  if (
    typeof value?.latitude === 'number' &&
    typeof value?.longitude === 'number'
  ) {
    return {
      __type: 'GeoPoint',
      latitude: value.latitude,
      longitude: value.longitude,
    };
  }

  if (Array.isArray(value)) return value.map(serialise);

  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(
        ([key, item]) => [key, serialise(item)],
      ),
    );
  }

  return value;
}

function cleanEmail(value) {
  return String(value || '').trim().toLowerCase();
}

function displayNameFor(data, role) {
  if (role === 'vendor') {
    return data.businessName || data.displayName || data.ownerName || 'Vendor';
  }

  return data.displayName || data.fullName || data.name || role;
}

async function listAuthUsers() {
  const byEmail = new Map();
  const byUid = new Map();
  let pageToken;

  do {
    const page = await auth.listUsers(1000, pageToken);

    for (const user of page.users) {
      byUid.set(user.uid, user);
      if (user.email) byEmail.set(cleanEmail(user.email), user);
    }

    pageToken = page.pageToken;
  } while (pageToken);

  return { byEmail, byUid };
}

async function backupAccountCollections(snapshots) {
  const backup = {
    createdAt: new Date().toISOString(),
  };

  for (const { name } of roleCollections) {
    backup[name] = snapshots[name].docs.map((document) => ({
      id: document.id,
      data: serialise(document.data()),
    }));
  }

  const backupPath = path.join(
    __dirname,
    `backup_before_auth_role_repair_${Date.now()}.json`,
  );

  fs.writeFileSync(
    backupPath,
    JSON.stringify(backup, null, 2),
    'utf8',
  );

  return backupPath;
}

async function commitProfileUpdates(updates) {
  for (let start = 0; start < updates.length; start += 350) {
    const batch = db.batch();

    for (const update of updates.slice(start, start + 350)) {
      batch.set(update.ref, update.data, { merge: true });
    }

    await batch.commit();
  }
}

async function main() {
  const snapshots = {};

  for (const { name } of roleCollections) {
    snapshots[name] = await db.collection(name).get();
  }

  const backupPath = await backupAccountCollections(snapshots);
  const authUsers = await listAuthUsers();
  const authCreates = [];
  const profileUpdates = [];
  const uidMismatches = [];
  const missingEmails = [];
  const profileUids = new Set();
  const profileEmails = new Set();
  const authOnlyUsers = [];

  for (const { name, role } of roleCollections) {
    for (const document of snapshots[name].docs) {
      const data = document.data();
      const email = cleanEmail(data.email);
      profileUids.add(document.id);
      if (email) profileEmails.add(email);

      if (!email) {
        missingEmails.push(`${name}/${document.id}`);
        continue;
      }

      const authByUid = authUsers.byUid.get(document.id);
      const authByEmail = authUsers.byEmail.get(email);

      if (authByEmail && authByEmail.uid !== document.id) {
        uidMismatches.push({
          profile: `${name}/${document.id}`,
          email,
          authUid: authByEmail.uid,
        });
        continue;
      }

      if (!authByUid && !authByEmail) {
        authCreates.push({
          uid: document.id,
          email,
          password: defaultPassword,
          displayName: displayNameFor(data, role),
          emailVerified: true,
          disabled: false,
        });
      }

      profileUpdates.push({
        ref: document.ref,
        data: {
          uid: document.id,
          email,
          role,
          status: data.status || 'active',
          authProfileRepairedAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
    }
  }

  for (const user of authUsers.byUid.values()) {
    const email = cleanEmail(user.email);
    if (!email) continue;

    if (!profileUids.has(user.uid) && !profileEmails.has(email)) {
      authOnlyUsers.push({
        uid: user.uid,
        email,
      });
    }
  }

  console.log('');
  console.log('Auth/profile repair scan completed.');
  console.log(`Backup: ${backupPath}`);
  console.log(`Auth accounts to create: ${authCreates.length}`);
  console.log(`Role profiles to normalize: ${profileUpdates.length}`);
  console.log(`Auth users without separated role profile: ${authOnlyUsers.length}`);
  console.log(`Profiles missing email: ${missingEmails.length}`);
  console.log(`Email UID mismatches skipped: ${uidMismatches.length}`);

  if (authOnlyUsers.length) {
    console.log('');
    console.log('Auth users without admins/, travelers/ or vendors/ profile:');
    for (const item of authOnlyUsers) {
      console.log(`- ${item.email} uid=${item.uid}`);
    }
    console.log(
      'These users can retry registration with the same email/password to complete their role profile.',
    );
  }

  if (missingEmails.length) {
    console.log('');
    console.log('Profiles missing email:');
    for (const item of missingEmails) console.log(`- ${item}`);
  }

  if (uidMismatches.length) {
    console.log('');
    console.log('Skipped profiles where Firebase Auth already has this email under another UID:');
    for (const item of uidMismatches) {
      console.log(`- ${item.profile} email=${item.email} authUid=${item.authUid}`);
    }
  }

  if (!confirmed) {
    console.log('');
    console.log('DRY RUN ONLY. Nothing was changed.');
    console.log(`Run with: node repair_auth_role_profiles.js --confirm ${CONFIRM_TOKEN}`);
    console.log('Optional: set REPAIR_DEFAULT_PASSWORD before running.');
    return;
  }

  for (const create of authCreates) {
    await auth.createUser(create);
  }

  await commitProfileUpdates(profileUpdates);

  console.log('');
  console.log('Auth/profile repair completed.');
  console.log(
    `New Auth users can sign in with the repair password: ${defaultPassword}`,
  );
  console.log('Ask users to change their password after first login.');
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Auth/profile repair failed.');
    console.error(error);
    process.exit(1);
  });
