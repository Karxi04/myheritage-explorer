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

function normalise(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function categoryProfile(vendorCategory, task) {
  const text = normalise(
    `${vendorCategory} ${task.title} ${task.description} ` +
    `${task.category} ${task.requiredPhotoCategory}`,
  );

  if (
    text.includes('food') ||
    text.includes('cafe') ||
    text.includes('restaurant') ||
    text.includes('dish') ||
    text.includes('drink')
  ) {
    return {
      category: 'Food Heritage',
      categoryCode: 'food_heritage',
      taskType: 'Local Dish Discovery',
      difficulty: 'Easy',
      requiredPhotoCategory: 'local_food_or_drink',
      evidenceType: 'photo_and_text',
      rewardPoints: 100,
      learningOutcome:
        'Recognise a Penang dish, ingredient or preparation tradition.',
      titlePrefix: 'Penang Food Heritage Discovery',
      description:
        'Photograph a local dish or drink offered by the registered vendor. Identify one ingredient, preparation method or cultural connection.',
    };
  }

  if (
    text.includes('craft') ||
    text.includes('workshop') ||
    text.includes('maker') ||
    text.includes('handmade') ||
    text.includes('batik')
  ) {
    return {
      category: 'Traditional Craft',
      categoryCode: 'traditional_craft',
      taskType: 'Craft Process Observation',
      difficulty: 'Medium',
      requiredPhotoCategory: 'craft_material_or_result',
      evidenceType: 'photo_and_text',
      rewardPoints: 150,
      learningOutcome:
        'Understand one material or technique used by a Penang maker.',
      titlePrefix: 'Traditional Craft Discovery',
      description:
        'Photograph a craft material, process or completed item. Explain one technique demonstrated by the registered vendor.',
    };
  }

  if (
    text.includes('nature') ||
    text.includes('eco') ||
    text.includes('garden') ||
    text.includes('conservation') ||
    text.includes('outdoor')
  ) {
    return {
      category: 'Nature & Conservation',
      categoryCode: 'nature_and_conservation',
      taskType: 'Conservation Observation',
      difficulty: 'Medium',
      requiredPhotoCategory: 'nature_or_conservation_feature',
      evidenceType: 'photo_and_text',
      rewardPoints: 150,
      learningOutcome:
        'Recognise one Penang habitat or conservation practice.',
      titlePrefix: 'Penang Nature Conservation Discovery',
      description:
        'Photograph a plant, habitat or conservation feature connected to the registered vendor. Explain why it should be protected.',
    };
  }

  if (
    text.includes('heritage') ||
    text.includes('history') ||
    text.includes('historic') ||
    text.includes('museum')
  ) {
    return {
      category: 'Heritage & History',
      categoryCode: 'heritage_and_history',
      taskType: 'Heritage Story Discovery',
      difficulty: 'Easy',
      requiredPhotoCategory: 'heritage_feature',
      evidenceType: 'photo_and_text',
      rewardPoints: 120,
      learningOutcome:
        'Learn one verified fact about Penang history or built heritage.',
      titlePrefix: 'Penang Heritage Story',
      description:
        'Photograph a heritage feature linked to the registered vendor. Write one historical or cultural fact learned during the visit.',
    };
  }

  if (
    text.includes('culture') ||
    text.includes('art') ||
    text.includes('gallery') ||
    text.includes('performance') ||
    text.includes('tradition')
  ) {
    return {
      category: 'Arts & Performance',
      categoryCode: 'arts_and_performance',
      taskType: 'Cultural Art Appreciation',
      difficulty: 'Medium',
      requiredPhotoCategory: 'cultural_art_or_object',
      evidenceType: 'photo_and_text',
      rewardPoints: 140,
      learningOutcome:
        'Identify the cultural meaning of an artwork, object or performance.',
      titlePrefix: 'Penang Living Culture Discovery',
      description:
        'Photograph an artwork, cultural object or demonstration. Describe its meaning respectfully using information from the registered vendor.',
    };
  }

  return {
    category: 'Community & Local Business',
    categoryCode: 'community_and_local_business',
    taskType: 'Local Product Discovery',
    difficulty: 'Easy',
    requiredPhotoCategory: 'local_product_or_service',
    evidenceType: 'photo_and_text',
    rewardPoints: 100,
    learningOutcome:
      'Learn how a Penang local product or service supports the community.',
    titlePrefix: 'Support a Penang Local Business',
    description:
      'Photograph a locally made product or service experience. Explain how the registered vendor contributes to Penang’s local community.',
  };
}

function minimumVoucherCost(vendorCategory) {
  const value = normalise(vendorCategory);

  if (value.includes('food') || value.includes('cafe')) return 100;
  if (value.includes('retail')) return 100;
  if (value.includes('heritage')) return 120;
  if (value.includes('culture')) return 140;
  if (value.includes('nature')) return 150;
  if (value.includes('craft')) return 150;
  if (value.includes('workshop')) return 180;

  return 100;
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

async function commitInChunks(changes) {
  for (let start = 0; start < changes.length; start += 400) {
    const batch = db.batch();

    for (const change of changes.slice(start, start + 400)) {
      batch.update(change.ref, change.data);
    }

    await batch.commit();
  }
}

async function main() {
  const [
    vendorSnapshot,
    voucherSnapshot,
    taskSnapshot,
  ] = await Promise.all([
    db.collection('vendors').get(),
    db.collection('vouchers').get(),
    db.collection('cultural_tasks').get(),
  ]);

  const vendors = new Map(
    vendorSnapshot.docs.map((doc) => [doc.id, doc.data()]),
  );

  const backup = {
    createdAt: new Date().toISOString(),
    vouchers: voucherSnapshot.docs.map((doc) => ({
      id: doc.id,
      data: serialise(doc.data()),
    })),
    culturalTasks: taskSnapshot.docs.map((doc) => ({
      id: doc.id,
      data: serialise(doc.data()),
    })),
  };

  const backupPath = path.join(
    __dirname,
    `backup_vouchers_tasks_${Date.now()}.json`,
  );

  fs.writeFileSync(
    backupPath,
    JSON.stringify(backup, null, 2),
    'utf8',
  );

  const voucherChanges = [];
  let repairedVoucherCosts = 0;

  for (const document of voucherSnapshot.docs) {
    const voucher = document.data();
    const vendorId = String(voucher.vendorId || '');
    const vendor = vendors.get(vendorId) || {};
    const currentCost = Number(voucher.pointCost || 0);

    if (currentCost <= 0) {
      repairedVoucherCosts += 1;

      voucherChanges.push({
        ref: document.ref,
        data: {
          pointCost: minimumVoucherCost(
            voucher.vendorCategory ||
              vendor.businessCategory,
          ),
          repairedInvalidPointCost: true,
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
    }
  }

  const taskChanges = [];

  for (const document of taskSnapshot.docs) {
    const task = document.data();
    const vendorId = String(task.vendorId || '');
    const vendor = vendors.get(vendorId) || {};
    const vendorName =
      task.vendorName ||
      vendor.businessName ||
      vendor.displayName ||
      'Registered Vendor';

    const profile = categoryProfile(
      task.vendorCategory ||
        vendor.businessCategory,
      task,
    );

    const genericTitle =
      task.seededForTesting === true ||
      normalise(task.title).includes('discovery at');

    taskChanges.push({
      ref: document.ref,
      data: {
        category: profile.category,
        categoryCode: profile.categoryCode,
        taskType: profile.taskType,
        difficulty: profile.difficulty,
        evidenceType: profile.evidenceType,
        requiredPhotoCategory:
          profile.requiredPhotoCategory,
        learningOutcome: profile.learningOutcome,
        rewardPoints:
          Number(task.rewardPoints || 0) > 0
            ? Number(task.rewardPoints)
            : profile.rewardPoints,
        ...(genericTitle
          ? {
              title:
                `${profile.titlePrefix} at ${vendorName}`,
              description: profile.description,
            }
          : {}),
        vendorCategory:
          vendor.businessCategory ||
          task.vendorCategory ||
          '',
        categoryUpdatedAt:
          FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
  }

  await commitInChunks(voucherChanges);
  await commitInChunks(taskChanges);

  console.log('');
  console.log('Voucher and cultural-task repair completed.');
  console.log(`Backup: ${backupPath}`);
  console.log(
    `Zero/invalid voucher costs repaired: ` +
      `${repairedVoucherCosts}`,
  );
  console.log(
    `Cultural tasks categorised: ${taskChanges.length}`,
  );
  console.log('');
  console.log(
    'No users, vendors, reviews, vouchers or tasks were deleted.',
  );
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Repair failed.');
    console.error(error);
    process.exit(1);
  });
