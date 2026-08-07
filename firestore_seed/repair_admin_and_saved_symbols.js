'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Missing firestore_seed/serviceAccountKey.json');
  process.exit(1);
}

initializeApp({ credential: cert(require(serviceAccountPath)) });
const db = getFirestore();

function cleanText(value) {
  if (typeof value !== 'string') return value;
  return value
    .replaceAll('â€¢', ' - ')
    .replaceAll('â€˘', ' - ')
    .replaceAll('â€¯', ' ')
    .replaceAll('â€“', '-')
    .replaceAll('â€”', '-')
    .replaceAll('â€˜', "'")
    .replaceAll('â€™', "'")
    .replaceAll('â€œ', '"')
    .replaceAll('â€', '"')
    .replaceAll('Â', '')
    .replaceAll('�', '')
    .replaceAll('•', ' - ')
    .replace(/\s+-\s+/g, ' - ')
    .replace(/\s+/g, ' ')
    .trim();
}

function cleanValue(value) {
  if (typeof value === 'string') return cleanText(value);
  if (Array.isArray(value)) return value.map(cleanValue);
  if (
    value &&
    typeof value === 'object' &&
    typeof value.toDate !== 'function' &&
    typeof value.latitude !== 'number'
  ) {
    return Object.fromEntries(
      Object.entries(value).map(([key, item]) => [key, cleanValue(item)]),
    );
  }
  return value;
}

function serialise(value) {
  if (value == null) return value;
  if (typeof value?.toDate === 'function') {
    return { __type: 'Timestamp', value: value.toDate().toISOString() };
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
      Object.entries(value).map(([key, item]) => [key, serialise(item)]),
    );
  }
  return value;
}

async function commitOperations(operations) {
  for (let start = 0; start < operations.length; start += 350) {
    const batch = db.batch();
    for (const operation of operations.slice(start, start + 350)) {
      if (operation.type === 'set') {
        batch.set(operation.reference, operation.data, { merge: true });
      } else if (operation.type === 'update') {
        batch.update(operation.reference, operation.data);
      } else {
        batch.delete(operation.reference);
      }
    }
    await batch.commit();
  }
}

async function repairAdminProfile() {
  const operations = [];
  let moved = 0;

  for (const collection of ['users', 'travelers', 'vendors']) {
    const snapshot = await db.collection(collection).get();
    for (const document of snapshot.docs) {
      const data = document.data();
      if (String(data.role || '').toLowerCase() !== 'admin') continue;

      operations.push({
        type: 'set',
        reference: db.collection('admins').doc(document.id),
        data: {
          ...data,
          uid: document.id,
          role: 'admin',
          status: data.status || 'active',
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
      operations.push({ type: 'delete', reference: document.ref });
      moved += 1;
    }
  }

  const adminEmail = String(process.env.MYHERITAGE_ADMIN_EMAIL || '')
    .trim()
    .toLowerCase();

  if (adminEmail) {
    const authUser = await getAuth().getUserByEmail(adminEmail);
    let merged = {};

    for (const source of ['admins', 'users', 'travelers', 'vendors']) {
      const snapshot = await db.collection(source).doc(authUser.uid).get();
      if (snapshot.exists) merged = { ...merged, ...snapshot.data() };
    }

    operations.push({
      type: 'set',
      reference: db.collection('admins').doc(authUser.uid),
      data: {
        ...merged,
        uid: authUser.uid,
        email: adminEmail,
        displayName:
          merged.displayName || authUser.displayName || 'System Administrator',
        role: 'admin',
        status: 'active',
        emailVerified: authUser.emailVerified,
        updatedAt: FieldValue.serverTimestamp(),
      },
    });

    for (const source of ['users', 'travelers', 'vendors']) {
      operations.push({
        type: 'delete',
        reference: db.collection(source).doc(authUser.uid),
      });
    }
  }

  await commitOperations(operations);
  return {
    moved,
    count: (await db.collection('admins').get()).size,
  };
}

async function repairSymbols() {
  const operations = [];
  let repaired = 0;
  const backup = { createdAt: new Date().toISOString() };

  for (const name of ['itineraries', 'shared_itineraries']) {
    const snapshot = await db.collection(name).get();
    backup[name] = snapshot.docs.map((document) => ({
      id: document.id,
      data: serialise(document.data()),
    }));

    for (const document of snapshot.docs) {
      const original = document.data();
      const cleaned = cleanValue(original);
      if (
        JSON.stringify(serialise(original)) !==
        JSON.stringify(serialise(cleaned))
      ) {
        operations.push({
          type: 'update',
          reference: document.ref,
          data: {
            ...cleaned,
            symbolsCleanedAt: FieldValue.serverTimestamp(),
          },
        });
        repaired += 1;
      }
    }
  }

  const backupPath = path.join(
    __dirname,
    `backup_before_symbol_repair_${Date.now()}.json`,
  );
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  await commitOperations(operations);
  return { repaired, backupPath };
}

async function main() {
  const admin = await repairAdminProfile();
  const symbols = await repairSymbols();

  console.log('');
  console.log('Repair completed.');
  console.log(`Admin profiles moved: ${admin.moved}`);
  console.log(`Administrators in admins/: ${admin.count}`);
  console.log(`Saved itinerary documents cleaned: ${symbols.repaired}`);
  console.log(`Backup: ${symbols.backupPath}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Repair failed.');
    console.error(error);
    process.exit(1);
  });
