'use strict';

const fs = require('fs');
const path = require('path');

const {
  initializeApp,
  cert,
} = require('firebase-admin/app');

const {
  getAuth,
} = require('firebase-admin/auth');

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
const auth = getAuth();

const uniqueLabels = [
  '',
  'Central',
  'Harbour',
  'Garden',
  'Market',
  'Courtyard',
  'Old Town',
  'Seaside',
  'Village',
  'Hill',
  'Arcade',
  'Lane',
  'Square',
  'Quarter',
];

const relatedCollections = [
  'reviews',
  'cultural_tasks',
  'task_submissions',
  'vouchers',
  'claimed_vouchers',
  'redemptions',
  'notifications',
  'place_content',
  'places',
  'itineraries',
  'shared_itineraries',
];

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

function stripTrailingVendorNumber(value) {
  return cleanText(value)
    .replace(/\s+\d{2,5}\s*$/g, '')
    .trim();
}

function replaceAllLiteral(text, oldValue, newValue) {
  if (
    typeof text !== 'string' ||
    !oldValue ||
    oldValue === newValue
  ) {
    return text;
  }

  return text.split(oldValue).join(newValue);
}

function recursivelyRepair(
  value,
  vendorNamesById,
  oldToNew,
  currentVendorId = '',
) {
  if (typeof value === 'string') {
    let result = cleanText(value);

    if (
      currentVendorId &&
      vendorNamesById.has(currentVendorId)
    ) {
      const mapping = vendorNamesById.get(currentVendorId);
      result = replaceAllLiteral(
        result,
        mapping.oldName,
        mapping.newName,
      );
    }

    for (const [oldName, newName] of oldToNew.entries()) {
      result = replaceAllLiteral(
        result,
        oldName,
        newName,
      );
    }

    return cleanText(result);
  }

  if (Array.isArray(value)) {
    return value.map((item) =>
      recursivelyRepair(
        item,
        vendorNamesById,
        oldToNew,
        currentVendorId,
      ),
    );
  }

  if (
    value &&
    typeof value === 'object' &&
    typeof value.toDate !== 'function' &&
    typeof value.latitude !== 'number'
  ) {
    const vendorId = String(
      value.vendorId ||
      value.uid ||
      currentVendorId ||
      '',
    );

    const repaired = Object.fromEntries(
      Object.entries(value).map(
        ([key, item]) => [
          key,
          recursivelyRepair(
            item,
            vendorNamesById,
            oldToNew,
            vendorId,
          ),
        ],
      ),
    );

    if (
      vendorId &&
      vendorNamesById.has(vendorId)
    ) {
      const newName =
        vendorNamesById.get(vendorId).newName;

      for (const field of [
        'vendorName',
        'businessName',
      ]) {
        if (field in repaired) {
          repaired[field] = newName;
        }
      }

      if (
        repaired.source === 'registered_vendor' ||
        repaired.source === 'vendor' ||
        String(repaired.placeId || '') ===
          `vendor_${vendorId}`
      ) {
        if ('name' in repaired) {
          repaired.name = newName;
        }
        if ('placeName' in repaired) {
          repaired.placeName = newName;
        }
      }
    }

    return repaired;
  }

  return value;
}

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

async function commitOperations(operations) {
  for (
    let start = 0;
    start < operations.length;
    start += 300
  ) {
    const batch = db.batch();

    for (
      const operation of operations.slice(
        start,
        start + 300,
      )
    ) {
      if (operation.type === 'set') {
        batch.set(
          operation.reference,
          operation.data,
          { merge: true },
        );
      } else if (operation.type === 'update') {
        batch.update(
          operation.reference,
          operation.data,
        );
      } else {
        batch.delete(operation.reference);
      }
    }

    await batch.commit();
  }
}

async function buildVendorNameMap(vendorSnapshot) {
  const grouped = new Map();

  for (const document of vendorSnapshot.docs) {
    const data = document.data();
    const currentName = cleanText(
      data.businessName ||
      data.displayName ||
      'Penang Local Vendor',
    );
    const baseName =
      stripTrailingVendorNumber(currentName) ||
      'Penang Local Vendor';

    if (!grouped.has(baseName)) {
      grouped.set(baseName, []);
    }

    grouped.get(baseName).push({
      id: document.id,
      oldName: currentName,
      data,
    });
  }

  const vendorNamesById = new Map();
  const oldToNew = new Map();

  for (const [baseName, vendors] of grouped.entries()) {
    vendors.sort((first, second) =>
      first.id.localeCompare(second.id),
    );

    vendors.forEach((vendor, index) => {
      const label =
        uniqueLabels[index] ||
        `Branch ${String.fromCharCode(
          65 + (index % 26),
        )}`;

      const newName = cleanText(
        label ? `${baseName} ${label}` : baseName,
      );

      vendorNamesById.set(vendor.id, {
        oldName: vendor.oldName,
        newName,
      });

      if (vendor.oldName !== newName) {
        oldToNew.set(vendor.oldName, newName);
      }
    });
  }

  return {
    vendorNamesById,
    oldToNew,
  };
}

async function repairAdmin(adminEmail) {
  const operations = [];
  let adminUid = '';

  if (adminEmail) {
    const authUser =
      await auth.getUserByEmail(adminEmail);

    adminUid = authUser.uid;

    let merged = {};
    for (const source of [
      'users',
      'travelers',
      'vendors',
      'admins',
    ]) {
      const snapshot =
        await db.collection(source)
          .doc(adminUid)
          .get();

      if (snapshot.exists) {
        merged = {
          ...merged,
          ...snapshot.data(),
        };
      }
    }

    operations.push({
      type: 'set',
      reference:
        db.collection('admins').doc(adminUid),
      data: {
        ...merged,
        uid: adminUid,
        email: adminEmail,
        displayName:
          merged.displayName ||
          authUser.displayName ||
          'System Administrator',
        role: 'admin',
        status: 'active',
        emailVerified: authUser.emailVerified,
        updatedAt: FieldValue.serverTimestamp(),
      },
    });

    for (const source of [
      'users',
      'travelers',
      'vendors',
    ]) {
      operations.push({
        type: 'delete',
        reference:
          db.collection(source).doc(adminUid),
      });
    }
  }

  for (const source of [
    'users',
    'travelers',
    'vendors',
  ]) {
    const snapshot =
      await db.collection(source).get();

    for (const document of snapshot.docs) {
      const data = document.data();

      if (
        String(data.role || '').toLowerCase() !==
        'admin'
      ) {
        continue;
      }

      operations.push({
        type: 'set',
        reference:
          db.collection('admins').doc(document.id),
        data: {
          ...data,
          uid: document.id,
          role: 'admin',
          status: data.status || 'active',
          updatedAt: FieldValue.serverTimestamp(),
        },
      });

      operations.push({
        type: 'delete',
        reference: document.ref,
      });
    }
  }

  await commitOperations(operations);

  return adminUid;
}

async function main() {
  const adminEmail =
    String(
      process.env.MYHERITAGE_ADMIN_EMAIL || '',
    )
      .trim()
      .toLowerCase();

  const snapshots = {};
  snapshots.vendors =
    await db.collection('vendors').get();

  for (const name of relatedCollections) {
    snapshots[name] =
      await db.collection(name).get();
  }

  snapshots.admins =
    await db.collection('admins').get();
  snapshots.travelers =
    await db.collection('travelers').get();
  snapshots.users =
    await db.collection('users').get();

  const backup = {
    createdAt: new Date().toISOString(),
  };

  for (const [name, snapshot] of Object.entries(
    snapshots,
  )) {
    backup[name] = snapshot.docs.map(
      (document) => ({
        id: document.id,
        data: serialise(document.data()),
      }),
    );
  }

  const backupPath = path.join(
    __dirname,
    `backup_before_vendor_name_symbol_admin_${Date.now()}.json`,
  );

  fs.writeFileSync(
    backupPath,
    JSON.stringify(backup, null, 2),
    'utf8',
  );

  const {
    vendorNamesById,
    oldToNew,
  } = await buildVendorNameMap(snapshots.vendors);

  const operations = [];
  let renamedVendors = 0;
  let repairedDocuments = 0;

  for (const document of snapshots.vendors.docs) {
    const data = document.data();
    const mapping =
      vendorNamesById.get(document.id);

    if (!mapping) continue;

    const repaired = recursivelyRepair(
      data,
      vendorNamesById,
      oldToNew,
      document.id,
    );

    repaired.businessName = mapping.newName;
    repaired.displayName = mapping.newName;
    repaired.vendorName = mapping.newName;
    repaired.updatedAt =
      FieldValue.serverTimestamp();

    operations.push({
      type: 'update',
      reference: document.ref,
      data: repaired,
    });

    if (mapping.oldName !== mapping.newName) {
      renamedVendors += 1;

      try {
        await auth.updateUser(
          document.id,
          {
            displayName: mapping.newName,
          },
        );
      } catch (error) {
        console.warn(
          `Could not update Auth displayName for ` +
          `${document.id}: ${error.message}`,
        );
      }
    }
  }

  for (const name of relatedCollections) {
    for (const document of snapshots[name].docs) {
      const original = document.data();
      const vendorId = String(
        original.vendorId || '',
      );

      const repaired = recursivelyRepair(
        original,
        vendorNamesById,
        oldToNew,
        vendorId,
      );

      const before =
        JSON.stringify(serialise(original));
      const after =
        JSON.stringify(serialise(repaired));

      if (before !== after) {
        operations.push({
          type: 'update',
          reference: document.ref,
          data: {
            ...repaired,
            repairedDisplayTextAt:
              FieldValue.serverTimestamp(),
          },
        });

        repairedDocuments += 1;
      }
    }
  }

  await commitOperations(operations);

  const adminUid = await repairAdmin(adminEmail);

  const adminCount =
    (await db.collection('admins').get()).size;

  console.log('');
  console.log('Repair completed.');
  console.log(`Backup: ${backupPath}`);
  console.log(
    `Vendor names cleaned: ${renamedVendors}`,
  );
  console.log(
    `Related documents repaired: ` +
    `${repairedDocuments}`,
  );
  console.log(
    `Administrators in admins/: ${adminCount}`,
  );

  if (adminUid) {
    console.log(
      `Requested Admin UID: ${adminUid}`,
    );
  }

  console.log('');
  console.log(
    'No vendor, traveler, review, task, voucher or itinerary was deleted.',
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Repair failed.');
    console.error(error);
    process.exit(1);
  });
