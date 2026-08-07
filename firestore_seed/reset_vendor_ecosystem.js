'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const {
  getFirestore,
  FieldValue,
  GeoPoint,
  Timestamp,
} = require('firebase-admin/firestore');

const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');
if (!fs.existsSync(serviceAccountPath)) {
  console.error('Missing firestore_seed/serviceAccountKey.json');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);
initializeApp({ credential: cert(serviceAccount) });

const db = getFirestore();
const auth = getAuth();
const CONFIRM_TOKEN = 'RESET_VENDOR_ECOSYSTEM';
const confirmed = process.argv.includes('--confirm') &&
  process.argv.includes(CONFIRM_TOKEN);
const geoapifyKey = String(process.env.GEOAPIFY_API_KEY || '').trim();
const defaultPassword = String(
  process.env.SEED_VENDOR_PASSWORD || 'Vendor123!',
);

const areas = [
  { name: 'George Town', lat: 5.4141, lng: 100.3288 },
  { name: 'Air Itam', lat: 5.4028, lng: 100.2784 },
  { name: 'Batu Ferringhi', lat: 5.4700, lng: 100.2453 },
  { name: 'Tanjung Bungah', lat: 5.4645, lng: 100.2964 },
  { name: 'Tanjung Tokong', lat: 5.4580, lng: 100.3060 },
  { name: 'Teluk Bahang', lat: 5.4594, lng: 100.2142 },
  { name: 'Balik Pulau', lat: 5.3500, lng: 100.2330 },
  { name: 'Bayan Lepas', lat: 5.2975, lng: 100.2590 },
  { name: 'Bayan Baru', lat: 5.3234, lng: 100.2850 },
  { name: 'Sungai Ara', lat: 5.3210, lng: 100.2670 },
  { name: 'Jelutong', lat: 5.3900, lng: 100.3140 },
  { name: 'Gelugor', lat: 5.3650, lng: 100.3000 },
  { name: 'Pulau Tikus', lat: 5.4320, lng: 100.3100 },
  { name: 'Gurney', lat: 5.4385, lng: 100.3090 },
  { name: 'Butterworth', lat: 5.3990, lng: 100.3630 },
  { name: 'Bukit Mertajam', lat: 5.3655, lng: 100.4580 },
  { name: 'Seberang Jaya', lat: 5.3970, lng: 100.4020 },
  { name: 'Kepala Batas', lat: 5.5150, lng: 100.4260 },
  { name: 'Nibong Tebal', lat: 5.1650, lng: 100.4780 },
  { name: 'Simpang Ampat', lat: 5.2800, lng: 100.4770 },
];

const categoryDefinitions = [
  {
    category: 'Food',
    plannerCategories: ['Food', 'Local Business'],
    names: ['Nyonya Kitchen', 'Penang Flavours', 'Heritage Hawker', 'Spice Table', 'Island Eats'],
    highlight: 'local Penang dishes, clear menu information and a welcoming dining experience',
    task: 'Photograph one local Penang dish and describe the cultural ingredient or preparation method.',
    photoTarget: 'local_food',
    voucher: 'RM10 Dining Discount',
  },
  {
    category: 'Cafe',
    plannerCategories: ['Food', 'Local Business'],
    names: ['Kopi Corner', 'Island Brew House', 'Heritage Coffee Room', 'Penang Bean Lab', 'Local Roast Cafe'],
    highlight: 'locally inspired drinks, comfortable seating and friendly counter service',
    task: 'Photograph a locally inspired drink and identify the ingredient connected to Penang.',
    photoTarget: 'local_drink',
    voucher: 'Free Local Drink Upgrade',
  },
  {
    category: 'Craft',
    plannerCategories: ['Culture', 'Local Business'],
    names: ['Batik & Craft Studio', 'Island Artisan House', 'Penang Handmade Gallery', 'Heritage Craft Corner', 'Local Maker Studio'],
    highlight: 'handmade products, local materials and explanations of the making process',
    task: 'Photograph a handmade item and explain the local craft technique used to create it.',
    photoTarget: 'local_craft',
    voucher: '15% Craft Purchase Discount',
  },
  {
    category: 'Workshop',
    plannerCategories: ['Culture', 'Art', 'Local Business'],
    names: ['Cultural Workshop', 'Creative Heritage Lab', 'Penang Maker Class', 'Artisan Learning Space', 'Community Craft Workshop'],
    highlight: 'guided hands-on activities, clear instructions and cultural learning',
    task: 'Complete one workshop step, photograph the result and describe what you learned.',
    photoTarget: 'workshop_result',
    voucher: 'Workshop Fee Rebate',
  },
  {
    category: 'Heritage',
    plannerCategories: ['Heritage', 'Culture', 'Local Business'],
    names: ['Heritage Story House', 'Penang History Studio', 'Local Heritage Centre', 'Old Town Culture Shop', 'Living Heritage Gallery'],
    highlight: 'local history, heritage interpretation and place-based storytelling',
    task: 'Photograph a heritage feature and write one fact learned from the vendor.',
    photoTarget: 'heritage_feature',
    voucher: 'Heritage Souvenir Discount',
  },
  {
    category: 'Nature',
    plannerCategories: ['Nature', 'Local Business'],
    names: ['Eco Experience Hub', 'Penang Nature Guide', 'Island Green Adventure', 'Local Eco Discovery', 'Penang Outdoor Studio'],
    highlight: 'nature education, responsible tourism and guided local outdoor experiences',
    task: 'Photograph one plant, landscape or conservation feature and explain why it should be protected.',
    photoTarget: 'nature_feature',
    voucher: 'Eco Experience Discount',
  },
  {
    category: 'Retail',
    plannerCategories: ['Local Business'],
    names: ['Penang Local Products', 'Island Souvenir Market', 'Community Product House', 'Local Made Store', 'Penang Gift Corner'],
    highlight: 'locally produced goods, transparent pricing and helpful product explanations',
    task: 'Photograph a locally made product and identify where or how it was produced.',
    photoTarget: 'local_product',
    voucher: 'RM8 Local Product Discount',
  },
  {
    category: 'Culture',
    plannerCategories: ['Culture', 'Heritage', 'Local Business'],
    names: ['Cultural Experience House', 'Penang Tradition Centre', 'Community Culture Studio', 'Island Heritage Experience', 'Local Culture Gallery'],
    highlight: 'community traditions, cultural demonstrations and respectful visitor learning',
    task: 'Photograph a cultural object or demonstration and describe its meaning respectfully.',
    photoTarget: 'cultural_object',
    voucher: 'Cultural Experience Reward',
  },
];

const reviewerNames = [
  'Aina Rahman', 'Daniel Lim', 'Nur Izzati', 'Marcus Lee', 'Siti Hajar',
  'Wei Jian', 'Farah Nadia', 'Harith Iskandar', 'Mei Ling', 'Jason Tan',
  'Amirah Yusuf', 'Bryan Wong', 'Priya Nair', 'Adam Chong', 'Hui Min',
  'Kavitha Raj', 'Muhammad Aqil', 'Chloe Ng', 'Raymond Goh', 'Nadia Azman',
];

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function seededRandom(index, salt = 0) {
  const x = Math.sin((index + 1) * 12.9898 + salt * 78.233) * 43758.5453;
  return x - Math.floor(x);
}

function coordinateFor(index, area) {
  const latJitter = (seededRandom(index, 1) - 0.5) * 0.018;
  const lngJitter = (seededRandom(index, 2) - 0.5) * 0.018;
  return {
    lat: Number((area.lat + latJitter).toFixed(6)),
    lng: Number((area.lng + lngJitter).toFixed(6)),
  };
}

function staticMapUrl(lat, lng) {
  if (!geoapifyKey) return '';
  const params = new URLSearchParams({
    style: 'osm-bright',
    width: '640',
    height: '420',
    center: `lonlat:${lng},${lat}`,
    zoom: '16',
    scaleFactor: '1',
    format: 'jpeg',
    apiKey: geoapifyKey,
  });
  return `https://maps.geoapify.com/v1/staticmap?${params.toString()}`;
}

function googleMapUrl(lat, lng) {
  return `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
}

function serialize(value) {
  if (value == null) return value;
  if (value instanceof Timestamp) {
    return { __type: 'Timestamp', value: value.toDate().toISOString() };
  }
  if (value instanceof GeoPoint) {
    return { __type: 'GeoPoint', latitude: value.latitude, longitude: value.longitude };
  }
  if (Array.isArray(value)) return value.map(serialize);
  if (typeof value === 'object') {
    const result = {};
    for (const [key, item] of Object.entries(value)) {
      result[key] = serialize(item);
    }
    return result;
  }
  return value;
}

async function backupCollection(collectionRef) {
  const snapshot = await collectionRef.get();
  const output = [];
  for (const doc of snapshot.docs) {
    const subcollections = await doc.ref.listCollections();
    const children = {};
    for (const subcollection of subcollections) {
      children[subcollection.id] = await backupCollection(subcollection);
    }
    output.push({
      id: doc.id,
      data: serialize(doc.data()),
      subcollections: children,
    });
  }
  return output;
}

async function deleteCollection(collectionRef) {
  while (true) {
    const snapshot = await collectionRef.limit(250).get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      const subcollections = await doc.ref.listCollections();
      for (const subcollection of subcollections) {
        await deleteCollection(subcollection);
      }
    }

    const batch = db.batch();
    for (const doc of snapshot.docs) batch.delete(doc.ref);
    await batch.commit();
  }
}

async function backupAndCleanExceptUsers() {
  const collections = await db.listCollections();
  const targets = collections.filter((collection) => collection.id !== 'users');
  const backup = {};

  for (const collection of targets) {
    console.log(`Backing up ${collection.id}...`);
    backup[collection.id] = await backupCollection(collection);
  }

  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
  const backupPath = path.join(__dirname, `backup_before_vendor_reset_${timestamp}.json`);
  fs.writeFileSync(backupPath, JSON.stringify(backup, null, 2), 'utf8');
  console.log(`Backup written to ${backupPath}`);

  for (const collection of targets) {
    console.log(`Deleting ${collection.id}...`);
    await deleteCollection(collection);
  }

  return targets.map((collection) => collection.id);
}

async function ensureVendorAuth(email, displayName) {
  try {
    const existing = await auth.getUserByEmail(email);
    return auth.updateUser(existing.uid, {
      displayName,
      password: defaultPassword,
      disabled: false,
      emailVerified: true,
    });
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    return auth.createUser({
      email,
      password: defaultPassword,
      displayName,
      emailVerified: true,
      disabled: false,
    });
  }
}

function validReviewTexts(vendor, definition) {
  return [
    {
      rating: 5,
      sentiment: 'positive',
      comment: `${vendor.businessName} provided ${definition.highlight}. The visit felt organised and worthwhile.`,
    },
    {
      rating: 4,
      sentiment: 'positive',
      comment: `The team explained the experience clearly and the ${definition.category.toLowerCase()} service matched the description.`,
    },
    {
      rating: 5,
      sentiment: 'positive',
      comment: `A memorable local stop in ${vendor.areaName}. The staff were helpful and the experience felt connected to Penang.`,
    },
    {
      rating: 4,
      sentiment: 'positive',
      comment: `The location was easy to identify and the business offered a pleasant, reliable visitor experience.`,
    },
    {
      rating: 3,
      sentiment: 'neutral',
      comment: `The visit was generally acceptable. The available choices were moderate and the overall experience was average.`,
    },
    {
      rating: 2,
      sentiment: 'negative',
      comment: `The waiting time was longer than expected and some information was unclear during the visit.`,
    },
  ];
}

function mismatchReviews(vendor) {
  return [
    {
      rating: 5,
      sentiment: 'negative',
      comment: `The service at ${vendor.businessName} was slow, the instructions were confusing and I left disappointed.`,
      reason: 'ML sentiment does not match the selected star rating',
      negativeProbability: 0.91,
      positiveProbability: 0.04,
    },
    {
      rating: 1,
      sentiment: 'positive',
      comment: `The staff were excellent, the experience was enjoyable and I would happily visit ${vendor.businessName} again.`,
      reason: 'ML sentiment does not match the selected star rating',
      negativeProbability: 0.03,
      positiveProbability: 0.94,
    },
  ];
}

async function seedVendorEcosystem() {
  const vendors = [];
  const credentials = [['email', 'password', 'businessName', 'uid']];
  const now = new Date();
  const expiry = Timestamp.fromDate(new Date(now.getTime() + 240 * 86400000));
  const deadline = Timestamp.fromDate(new Date(now.getTime() + 180 * 86400000));

  for (let index = 0; index < 120; index += 1) {
    const definition = categoryDefinitions[index % categoryDefinitions.length];
    const area = areas[index % areas.length];
    const coordinate = coordinateFor(index, area);
    const nameBase = definition.names[index % definition.names.length];
    const businessName = `${area.name} ${nameBase} ${String(index + 1).padStart(3, '0')}`;
    const email = `vendor${String(index + 1).padStart(3, '0')}@myheritage.test`;
    const user = await ensureVendorAuth(email, businessName);
    const mapPreview = staticMapUrl(coordinate.lat, coordinate.lng);
    const address = `${10 + (index % 80)}, ${area.name} Local Street, ${area.name}, Penang, Malaysia`;
    const phone = `04-${String(2100000 + index * 37).padStart(7, '0')}`;
    const budget = ['Low', 'Medium', 'Medium', 'High'][index % 4];
    const vendor = {
      uid: user.uid,
      businessName,
      areaName: area.name,
      category: definition.category,
      plannerCategories: definition.plannerCategories,
      lat: coordinate.lat,
      lng: coordinate.lng,
      address,
      phone,
      budget,
      definition,
      imageUrl: mapPreview,
    };
    vendors.push(vendor);
    credentials.push([email, defaultPassword, businessName, user.uid]);

    await db.collection('users').doc(user.uid).set({
      uid: user.uid,
      email,
      displayName: businessName,
      businessName,
      ownerName: `Owner ${String(index + 1).padStart(3, '0')}`,
      businessCategory: definition.category,
      plannerCategories: definition.plannerCategories,
      contactNumber: phone,
      shopLocation: address,
      businessHours: index % 3 === 0
        ? 'Mon-Sun 09:00-21:00'
        : 'Tue-Sun 10:00-19:00',
      businessDescription: `${businessName} is a registered MyHeritage vendor offering ${definition.highlight}.`,
      role: 'vendor',
      status: 'active',
      vendorStatus: 'verified',
      emailVerified: true,
      verificationDocumentUrl: 'seeded-admin-verification',
      location: new GeoPoint(coordinate.lat, coordinate.lng),
      latitude: coordinate.lat,
      longitude: coordinate.lng,
      state: 'Penang',
      country: 'Malaysia',
      mapUrl: googleMapUrl(coordinate.lat, coordinate.lng),
      imageUrl: mapPreview,
      fallbackImageUrl: mapPreview,
      mapPreviewUrl: mapPreview,
      imageType: 'map_preview',
      budgetLevel: budget,
      seededForTesting: true,
      seededVendorNumber: index + 1,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  }

  const reviewBatchSize = 350;
  let pendingWrites = [];
  async function flush() {
    if (pendingWrites.length === 0) return;
    const batch = db.batch();
    for (const write of pendingWrites) batch.set(write.ref, write.data);
    await batch.commit();
    pendingWrites = [];
  }

  let validReviews = 0;
  let flaggedReviews = 0;
  let taskCount = 0;
  let voucherCount = 0;

  for (let index = 0; index < vendors.length; index += 1) {
    const vendor = vendors[index];
    const definition = vendor.definition;
    const placeId = `vendor_${vendor.uid}`;
    const placeNameKey = normalize(vendor.businessName);

    const validReviewsForVendor = validReviewTexts(vendor, definition);
    const flaggedForVendor = mismatchReviews(vendor);
    const reviews = [...validReviewsForVendor, ...flaggedForVendor];

    for (let reviewIndex = 0; reviewIndex < reviews.length; reviewIndex += 1) {
      const review = reviews[reviewIndex];
      const flagged = reviewIndex >= validReviewsForVendor.length;
      const createdAt = Timestamp.fromDate(
        new Date(now.getTime() - (index * 2 + reviewIndex + 5) * 86400000),
      );
      const ref = db.collection('reviews').doc(
        `vendor_seed_${String(index + 1).padStart(3, '0')}_${reviewIndex + 1}`,
      );
      pendingWrites.push({
        ref,
        data: {
          userId: `seed_traveler_${(index + reviewIndex) % 60 + 1}`,
          reviewerName: reviewerNames[(index + reviewIndex) % reviewerNames.length],
          vendorId: vendor.uid,
          placeId,
          placeName: vendor.businessName,
          placeNameKey,
          source: 'vendor_seed',
          rating: review.rating,
          comment: review.comment,
          status: flagged ? 'flagged' : 'valid',
          flagReason: flagged ? review.reason : null,
          flagReasons: flagged ? [review.reason] : [],
          mlModelVersion: 'tfidf_sentiment_suspicious_v2',
          mlSentiment: review.sentiment,
          mlSentimentConfidence: flagged ? 0.92 : 0.86,
          mlNegativeProbability: review.negativeProbability ?? (review.sentiment === 'negative' ? 0.84 : 0.07),
          mlNeutralProbability: review.sentiment === 'neutral' ? 0.76 : 0.08,
          mlPositiveProbability: review.positiveProbability ?? (review.sentiment === 'positive' ? 0.86 : 0.08),
          mlRatingMismatch: flagged,
          mlSuspiciousProbability: flagged ? 0.91 : 0.12,
          mlDecision: flagged ? 'flagged' : 'valid',
          seededForTesting: true,
          createdAt,
          updatedAt: Timestamp.now(),
        },
      });
      if (flagged) flaggedReviews += 1;
      else validReviews += 1;
      if (pendingWrites.length >= reviewBatchSize) await flush();
    }

    const taskRef = db.collection('cultural_tasks').doc(
      `vendor_task_${String(index + 1).padStart(3, '0')}`,
    );
    pendingWrites.push({
      ref: taskRef,
      data: {
        vendorId: vendor.uid,
        vendorName: vendor.businessName,
        placeId,
        title: `${definition.category} Discovery at ${vendor.businessName}`,
        description: definition.task,
        category: definition.plannerCategories[0],
        locationName: vendor.businessName,
        location: new GeoPoint(vendor.lat, vendor.lng),
        mapUrl: googleMapUrl(vendor.lat, vendor.lng),
        requiredPhotoCategory: definition.photoTarget,
        rewardPoints: 80 + (index % 6) * 20,
        deadline,
        status: 'active',
        optional: true,
        seededForTesting: true,
        createdBy: 'system_seed',
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
    taskCount += 1;

    const voucherRef = db.collection('vouchers').doc(
      `vendor_voucher_${String(index + 1).padStart(3, '0')}_1`,
    );
    pendingWrites.push({
      ref: voucherRef,
      data: {
        vendorId: vendor.uid,
        vendorName: vendor.businessName,
        vendorCategory: definition.category,
        vendorAddress: vendor.address,
        title: definition.voucher,
        description: `Reward available only at ${vendor.businessName}.`,
        terms: 'One redemption per traveler. Present the in-app QR code before payment.',
        pointCost: 100 + (index % 5) * 40,
        inventoryLimit: 80,
        inventoryRemaining: 80,
        claimCount: 0,
        expiresAt: expiry,
        location: new GeoPoint(vendor.lat, vendor.lng),
        notificationRadiusMeters: 900,
        status: 'active',
        seededForTesting: true,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      },
    });
    voucherCount += 1;

    if (index % 3 === 0) {
      const secondVoucherRef = db.collection('vouchers').doc(
        `vendor_voucher_${String(index + 1).padStart(3, '0')}_2`,
      );
      pendingWrites.push({
        ref: secondVoucherRef,
        data: {
          vendorId: vendor.uid,
          vendorName: vendor.businessName,
          vendorCategory: definition.category,
          vendorAddress: vendor.address,
          title: `Bonus Reward at ${vendor.businessName}`,
          description: 'A second vendor reward for travelers who earn additional cultural-task points.',
          terms: 'Subject to inventory. One claim per account.',
          pointCost: 220 + (index % 4) * 40,
          inventoryLimit: 40,
          inventoryRemaining: 40,
          claimCount: 0,
          expiresAt: expiry,
          location: new GeoPoint(vendor.lat, vendor.lng),
          notificationRadiusMeters: 900,
          status: 'active',
          seededForTesting: true,
          createdAt: FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
      });
      voucherCount += 1;
    }

    if (pendingWrites.length >= reviewBatchSize) await flush();
  }
  await flush();

  const csvPath = path.join(__dirname, 'seeded_vendor_accounts.csv');
  fs.writeFileSync(
    csvPath,
    credentials.map((row) => row.map((item) => `"${String(item).replace(/"/g, '""')}"`).join(',')).join('\n'),
    'utf8',
  );

  return {
    vendors: vendors.length,
    validReviews,
    flaggedReviews,
    tasks: taskCount,
    vouchers: voucherCount,
    credentialsPath: csvPath,
  };
}

async function main() {
  const collections = (await db.listCollections()).map((item) => item.id);
  console.log('Current top-level collections:');
  console.log(collections.length ? collections.join(', ') : '(none)');
  console.log('The users collection will be preserved.');

  if (!confirmed) {
    console.log('');
    console.log('DRY RUN ONLY. Nothing was deleted or created.');
    console.log(`Run with: node reset_vendor_ecosystem.js --confirm ${CONFIRM_TOKEN}`);
    return;
  }

  if (!geoapifyKey) {
    console.warn('Warning: GEOAPIFY_API_KEY is empty. Vendors will still have coordinates, but seeded imageUrl values will be blank.');
  }

  const deletedCollections = await backupAndCleanExceptUsers();
  const result = await seedVendorEcosystem();

  console.log('');
  console.log('Vendor-only Penang ecosystem created successfully.');
  console.log(`Collections removed before seeding: ${deletedCollections.join(', ') || '(none)'}`);
  console.log(`Registered/verified vendors: ${result.vendors}`);
  console.log(`Valid vendor reviews: ${result.validReviews}`);
  console.log(`Flagged vendor reviews: ${result.flaggedReviews}`);
  console.log(`Total vendor reviews: ${result.validReviews + result.flaggedReviews}`);
  console.log(`Optional cultural tasks: ${result.tasks}`);
  console.log(`Vendor-linked vouchers: ${result.vouchers}`);
  console.log(`Vendor login list: ${result.credentialsPath}`);
  console.log(`Default vendor password: ${defaultPassword}`);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Vendor ecosystem reset failed.');
    console.error(error);
    process.exit(1);
  });
