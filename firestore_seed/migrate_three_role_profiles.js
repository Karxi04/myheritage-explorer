'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const {
  getFirestore,
  FieldValue,
} = require('firebase-admin/firestore');

const serviceAccountPath = path.join(
  __dirname,
  'serviceAccountKey.json',
);

if (!fs.existsSync(serviceAccountPath)) {
  console.error(
    'Missing firestore_seed/serviceAccountKey.json',
  );
  process.exit(1);
}

initializeApp({
  credential: cert(require(serviceAccountPath)),
});

const db = getFirestore();
const CONFIRM_TOKEN = 'MIGRATE_THREE_ROLE_PROFILES';
const confirmed = process.argv.includes('--confirm') &&
  process.argv.includes(CONFIRM_TOKEN);
const collections = [
  'users',
  'admins',
  'travelers',
  'vendors',
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

  if (Array.isArray(value)) {
    return value.map(serialise);
  }

  if (typeof value === 'object') {
    return Object.fromEntries(
      Object.entries(value).map(
        ([key, item]) => [key, serialise(item)],
      ),
    );
  }

  return value;
}

function looksLikeVendor(data) {
  return data.role === 'vendor' ||
    data.vendorStatus != null ||
    data.businessName != null ||
    data.businessCategory != null;
}

function determineRole(records) {
  const explicit = records
    .map((record) =>
      String(record.data.role || '').toLowerCase(),
    )
    .filter((role) =>
      ['admin', 'traveler', 'vendor'].includes(role),
    );

  if (explicit.includes('admin')) return 'admin';
  if (explicit.includes('vendor')) return 'vendor';
  if (explicit.includes('traveler')) return 'traveler';

  if (records.some((item) => item.source === 'admins')) {
    return 'admin';
  }

  if (
    records.some(
      (item) =>
        item.source === 'vendors' ||
        looksLikeVendor(item.data),
    )
  ) {
    return 'vendor';
  }

  return 'traveler';
}

function mergeForRole(records, role) {
  const order = {
    admin: ['users', 'travelers', 'vendors', 'admins'],
    traveler: ['users', 'admins', 'vendors', 'travelers'],
    vendor: ['users', 'admins', 'travelers', 'vendors'],
  }[role];

  const merged = {};

  for (const source of order) {
    for (const record of records.filter(
      (item) => item.source === source,
    )) {
      Object.assign(merged, record.data);
    }
  }

  return merged;
}

async function commitOperations(operations) {
  for (
    let start = 0;
    start < operations.length;
    start += 350
  ) {
    const batch = db.batch();

    for (
      const operation of operations.slice(
        start,
        start + 350,
      )
    ) {
      if (operation.type === 'set') {
        batch.set(
          operation.reference,
          operation.data,
          { merge: true },
        );
      } else {
        batch.delete(operation.reference);
      }
    }

    await batch.commit();
  }
}

async function main() {
  const snapshots = {};

  for (const name of collections) {
    snapshots[name] =
      await db.collection(name).get();
  }

  const backup = {
    createdAt: new Date().toISOString(),
  };

  for (const name of collections) {
    backup[name] = snapshots[name].docs.map(
      (document) => ({
        id: document.id,
        data: serialise(document.data()),
      }),
    );
  }

  const backupPath = path.join(
    __dirname,
    `backup_before_three_roles_${Date.now()}.json`,
  );

  fs.writeFileSync(
    backupPath,
    JSON.stringify(backup, null, 2),
    'utf8',
  );

  const recordsByUid = new Map();

  for (const source of collections) {
    for (const document of snapshots[source].docs) {
      if (!recordsByUid.has(document.id)) {
        recordsByUid.set(document.id, []);
      }

      recordsByUid.get(document.id).push({
        source,
        data: document.data(),
      });
    }
  }

  const operations = [];
  const counts = {
    admin: 0,
    traveler: 0,
    vendor: 0,
  };

  for (const [uid, records] of recordsByUid.entries()) {
    const role = determineRole(records);
    const target =
      role === 'admin'
        ? 'admins'
        : role === 'vendor'
          ? 'vendors'
          : 'travelers';

    const merged = mergeForRole(records, role);

    operations.push({
      type: 'set',
      reference: db.collection(target).doc(uid),
      data: {
        ...merged,
        uid,
        role,
        migratedToThreeRoles: true,
        migratedAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });

    for (const source of collections) {
      if (source !== target) {
        operations.push({
          type: 'delete',
          reference: db.collection(source).doc(uid),
        });
      }
    }

    counts[role] += 1;
  }

  if (!confirmed) {
    console.log('');
    console.log('DRY RUN ONLY. Nothing was moved or deleted.');
    console.log(`Backup: ${backupPath}`);
    console.log(`Administrators to place in admins/: ${counts.admin}`);
    console.log(`Travelers to place in travelers/: ${counts.traveler}`);
    console.log(`Vendors to place in vendors/: ${counts.vendor}`);
    console.log('');
    console.log(`Run with: node migrate_three_role_profiles.js --confirm ${CONFIRM_TOKEN}`);
    return;
  }

  await commitOperations(operations);

  const sizes = {};
  for (const name of collections) {
    sizes[name] =
      (await db.collection(name).get()).size;
  }

  console.log('');
  console.log('Three-role migration completed.');
  console.log(`Backup: ${backupPath}`);
  console.log(`Administrators: ${counts.admin}`);
  console.log(`Travelers: ${counts.traveler}`);
  console.log(`Vendors: ${counts.vendor}`);
  console.log('');
  console.log('Final collection sizes:');
  console.log(`users: ${sizes.users}`);
  console.log(`admins: ${sizes.admins}`);
  console.log(`travelers: ${sizes.travelers}`);
  console.log(`vendors: ${sizes.vendors}`);
  console.log('');
  console.log(
    'Firebase Authentication and account UIDs were not changed.',
  );
  console.log(
    'Reviews, tasks, vouchers and itineraries were not deleted.',
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Three-role migration failed.');
    console.error(error);
    process.exit(1);
  });
