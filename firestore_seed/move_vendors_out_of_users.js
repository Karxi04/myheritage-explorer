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
    const output = {};
    for (const [key, item] of Object.entries(value)) {
      output[key] = serialise(item);
    }
    return output;
  }
  return value;
}

function looksLikeVendor(data) {
  return data.role === 'vendor' ||
    data.vendorStatus != null ||
    data.businessName != null ||
    data.businessCategory != null;
}

async function main() {
  const usersSnapshot = await db.collection('users').get();
  const vendorsSnapshot = await db.collection('vendors').get();

  const backup = {
    createdAt: new Date().toISOString(),
    users: usersSnapshot.docs.map((doc) => ({
      id: doc.id,
      data: serialise(doc.data()),
    })),
    vendors: vendorsSnapshot.docs.map((doc) => ({
      id: doc.id,
      data: serialise(doc.data()),
    })),
  };

  const backupName =
    `backup_before_role_separation_${Date.now()}.json`;
  const backupPath = path.join(__dirname, backupName);
  fs.writeFileSync(
    backupPath,
    JSON.stringify(backup, null, 2),
    'utf8',
  );

  const vendorDocuments = usersSnapshot.docs.filter(
    (doc) => looksLikeVendor(doc.data()),
  );

  let moved = 0;

  for (let start = 0; start < vendorDocuments.length; start += 300) {
    const batch = db.batch();
    const chunk = vendorDocuments.slice(start, start + 300);

    for (const document of chunk) {
      const data = document.data();
      const vendorRef = db.collection('vendors').doc(document.id);

      batch.set(
        vendorRef,
        {
          ...data,
          uid: document.id,
          role: 'vendor',
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      batch.delete(document.ref);
      moved += 1;
    }

    await batch.commit();
  }

  const usersAfter = await db.collection('users').get();
  const vendorProfilesLeftInUsers = usersAfter.docs.filter(
    (doc) => looksLikeVendor(doc.data()),
  );

  console.log('');
  console.log('Role separation completed.');
  console.log(`Backup: ${backupPath}`);
  console.log(`Vendor profiles moved to vendors/: ${moved}`);
  console.log(
    `Vendor profiles remaining in users/: ` +
      `${vendorProfilesLeftInUsers.length}`,
  );
  console.log('');
  console.log(
    'Firebase Authentication accounts were not deleted or changed.',
  );
  console.log(
    'Reviews, cultural tasks and vouchers keep the same vendorId UID.',
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Role separation failed.');
    console.error(error);
    process.exit(1);
  });
