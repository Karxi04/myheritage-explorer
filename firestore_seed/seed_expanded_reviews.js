'use strict';

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');
initializeApp({ credential: cert(serviceAccount) });
const db = getFirestore();

const locations = [
  ['armenian_street', 'Armenian Street', ['Lebuh Armenian', 'Armenian Street George Town'], 'Heritage'],
  ['cheong_fatt_tze_mansion', 'Cheong Fatt Tze Mansion', ['The Blue Mansion', 'Blue Mansion'], 'Heritage'],
  ['pinang_peranakan_mansion', 'Pinang Peranakan Mansion', ['Penang Peranakan Mansion', 'Peranakan Mansion'], 'Culture'],
  ['clan_jetties', 'Clan Jetties', ['Clan Jetties of Penang', 'Chew Jetty', 'Chew Jetty Penang'], 'Culture'],
  ['khoo_kongsi', 'Khoo Kongsi', ['Leong San Tong Khoo Kongsi'], 'Heritage'],
  ['fort_cornwallis', 'Fort Cornwallis', ['Kota Cornwallis'], 'Heritage'],
  ['kek_lok_si_temple', 'Kek Lok Si Temple', ['Kek Lok Si', 'Temple of Supreme Bliss'], 'Culture'],
  ['penang_hill', 'Penang Hill', ['Bukit Bendera', 'Penang Hill Upper Station'], 'Nature'],
  ['penang_botanic_gardens', 'Penang Botanic Gardens', ['Botanical Garden Penang', 'Penang Botanical Gardens'], 'Nature'],
  ['gurney_drive_hawker_centre', 'Gurney Drive Hawker Centre', ['Gurney Drive Food Court', 'Anjung Gurney'], 'Food'],
  ['new_lane_street_food', 'New Lane Street Foodstalls', ['New Lane Hawker Centre', 'Lorong Baru Food Court'], 'Food'],
  ['wonderfood_museum', 'Wonderfood Museum', ['Wonder Food Museum'], 'Art'],
  ['upside_down_museum', 'Upside Down Museum', ['Upside Down Museum Penang'], 'Art'],
  ['hin_bus_depot', 'Hin Bus Depot', ['Hin Bus Depot Art Centre'], 'Art'],
  ['tropical_spice_garden', 'Tropical Spice Garden', ['Tropical Spice Garden Penang'], 'Nature'],
];

const positiveComments = [
  'The location was easy to find and the visit matched the information shown in the app.',
  'The atmosphere was enjoyable and the staff or local community were welcoming during the visit.',
  'This place added useful cultural context to the itinerary and was worth the travel time.',
  'The surroundings were clean and the main attractions were easy to explore at a comfortable pace.',
  'A memorable stop with clear highlights, good photo opportunities and a convenient location.',
  'The experience was well organised and suitable for travelers visiting the area for the first time.',
];

const flaggedExamples = [
  {
    rating: 5,
    comment: 'Terrible service, poor information and the worst experience during the trip.',
    reasons: ['Possible rating-comment mismatch'],
    probability: 0.94,
  },
  {
    rating: 3,
    comment: 'good good good good good',
    reasons: ['Repeated word or phrase pattern'],
    probability: 0.97,
  },
];

const reviewerNames = [
  'Aina Rahman', 'Daniel Lim', 'Nur Izzati', 'Wei Jian', 'Farah Nadia',
  'Harith Iskandar', 'Mei Ling', 'Jason Tan', 'Amirah Yusuf', 'Bryan Wong',
  'Priya Nair', 'Hui Min', 'Kavitha Raj', 'Muhammad Aqil', 'Chloe Ng',
  'Nadia Azman', 'Kelvin Ooi', 'Shalini Devi', 'Marcus Lee', 'Siti Hajar',
];

async function clearOldData() {
  const snapshot = await db.collection('reviews')
      .where('source', '==', 'initial_content_v2').get();
  for (let start = 0; start < snapshot.docs.length; start += 400) {
    const batch = db.batch();
    for (const doc of snapshot.docs.slice(start, start + 400)) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
  return snapshot.docs.length;
}

async function seed() {
  const removed = await clearOldData();
  const contentBatch = db.batch();
  const reviewBatch = db.batch();
  const now = Date.now();
  let reviewNumber = 0;
  let validCount = 0;
  let flaggedCount = 0;

  for (const [id, name, aliases, category] of locations) {
    contentBatch.set(db.collection('place_content').doc(id), {
      name,
      placeNameKey: name.toLowerCase(),
      aliases,
      category,
      status: 'active',
      updatedAt: Timestamp.now(),
    }, { merge: true });

    for (let index = 0; index < 6; index++) {
      reviewNumber += 1;
      validCount += 1;
      const rating = index < 2 ? 5 : 4;
      const ref = db.collection('reviews').doc(`initial_v2_${id}_valid_${index + 1}`);
      reviewBatch.set(ref, {
        userId: `initial_v2_user_${reviewNumber}`,
        reviewerName: reviewerNames[reviewNumber % reviewerNames.length],
        placeId: `seed_${id}`,
        placeName: name,
        placeNameKey: name.toLowerCase(),
        source: 'initial_content_v2',
        rating,
        comment: positiveComments[index],
        status: 'valid',
        flagReason: null,
        flagReasons: [],
        seededForTesting: true,
        createdAt: Timestamp.fromDate(new Date(now - reviewNumber * 86400000)),
        updatedAt: Timestamp.now(),
      });
    }

    for (let index = 0; index < flaggedExamples.length; index++) {
      reviewNumber += 1;
      flaggedCount += 1;
      const item = flaggedExamples[index];
      const ref = db.collection('reviews').doc(`initial_v2_${id}_flagged_${index + 1}`);
      reviewBatch.set(ref, {
        userId: `initial_v2_flag_user_${reviewNumber}`,
        reviewerName: reviewerNames[reviewNumber % reviewerNames.length],
        placeId: `seed_${id}`,
        placeName: name,
        placeNameKey: name.toLowerCase(),
        source: 'initial_content_v2',
        rating: item.rating,
        comment: item.comment,
        status: 'flagged',
        flagReason: item.reasons.join(' • '),
        flagReasons: item.reasons,
        mlModelVersion: 'tfidf_logreg_v1',
        mlSuspiciousProbability: item.probability,
        mlDecision: 'flagged',
        seededForTesting: true,
        createdAt: Timestamp.fromDate(new Date(now - reviewNumber * 86400000)),
        updatedAt: Timestamp.now(),
      });
    }
  }

  await contentBatch.commit();
  await reviewBatch.commit();

  console.log('');
  console.log('Expanded review data created successfully.');
  console.log(`Removed previous v2 records: ${removed}`);
  console.log(`Locations covered: ${locations.length}`);
  console.log(`Valid reviews created: ${validCount}`);
  console.log(`Flagged reviews created: ${flaggedCount}`);
  console.log(`Total reviews created: ${validCount + flaggedCount}`);
  console.log('');
  console.log('Open Admin > Review Moderation > Flagged to test moderation.');
}

seed().then(() => process.exit(0)).catch((error) => {
  console.error('Seed failed:', error);
  process.exit(1);
});
