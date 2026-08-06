'use strict';

const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

const placeContent = [
  {
    id: 'kyrin_sushi',
    name: 'Kyrin Sushi',
    placeNameKey: 'kyrin sushi',
    aliases: [
      'Kyrin Sushi',
      'Kyrin Sushi George Town',
    ],
    imageUrl:
      'https://commons.wikimedia.org/wiki/Special:FilePath/Japanese%20Sushi%20platter.jpg?width=1200',
    imageType: 'representative_photo',
    imageAttribution:
      'Representative sushi image from Wikimedia Commons',
    imageSourceUrl:
      'https://commons.wikimedia.org/wiki/File:Japanese_Sushi_platter.jpg',
    imageNotice:
      'This is a representative food image, not a photograph of Kyrin Sushi.',
    description:
      'Kyrin Sushi is a Japanese dining option in George Town. '
      + 'The venue can be considered when a traveler selects Food as an '
      + 'interest. Check the latest opening hours and menu directly with '
      + 'the restaurant before visiting.',
  },
  {
    id: 'armenian_street',
    name: 'Armenian Street',
    placeNameKey: 'armenian street',
    aliases: [
      'Armenian Street',
      'Lebuh Armenian',
      'Armenian Street George Town',
    ],
    imageUrl:
      'https://commons.wikimedia.org/wiki/Special:FilePath/Armenian%20Street%2C%20George%20Town%20%28220921%29.jpg?width=1200',
    imageType: 'curated_place_photo',
    imageAttribution:
      'Armenian Street, George Town — Wikimedia Commons',
    imageSourceUrl:
      'https://commons.wikimedia.org/wiki/File:Armenian_Street,_George_Town_(220921).jpg',
    imageNotice: '',
    description:
      'Armenian Street is a heritage street in central George Town known '
      + 'for its historic streetscape, cultural attractions and public art. '
      + 'It is suitable for a walking-based heritage itinerary.',
  },
  {
    id: 'cheong_fatt_tze_mansion',
    name: 'Cheong Fatt Tze Mansion',
    placeNameKey: 'cheong fatt tze mansion',
    aliases: [
      'Cheong Fatt Tze Mansion',
      'The Blue Mansion',
      'Blue Mansion',
    ],
    imageUrl:
      'https://commons.wikimedia.org/wiki/Special:FilePath/Cheong%20Fatt%20Tze%20Mansion.jpg?width=1200',
    imageType: 'curated_place_photo',
    imageAttribution:
      'Cheong Fatt Tze Mansion — Wikimedia Commons',
    imageSourceUrl:
      'https://commons.wikimedia.org/wiki/File:Cheong_Fatt_Tze_Mansion.jpg',
    imageNotice: '',
    description:
      'Cheong Fatt Tze Mansion, also known as the Blue Mansion, is a '
      + 'prominent heritage building in George Town. It is suitable for '
      + 'travelers interested in architecture, history and culture.',
  },
  {
    id: 'pinang_peranakan_mansion',
    name: 'Pinang Peranakan Mansion',
    placeNameKey: 'pinang peranakan mansion',
    aliases: [
      'Pinang Peranakan Mansion',
      'Penang Peranakan Mansion',
      'Peranakan Mansion',
    ],
    imageUrl:
      'https://commons.wikimedia.org/wiki/Special:FilePath/Pinang%20Peranakan%20Mansion%20%28I%29.jpg?width=1200',
    imageType: 'curated_place_photo',
    imageAttribution:
      'Pinang Peranakan Mansion — Wikimedia Commons',
    imageSourceUrl:
      'https://commons.wikimedia.org/wiki/File:Pinang_Peranakan_Mansion_(I).jpg',
    imageNotice: '',
    description:
      'Pinang Peranakan Mansion is a museum in George Town focused on '
      + 'Peranakan heritage, decorative arts and domestic culture. It is '
      + 'a strong match for Heritage and Culture interests.',
  },
  {
    id: 'clan_jetties',
    name: 'Clan Jetties',
    placeNameKey: 'clan jetties',
    aliases: [
      'Clan Jetties',
      'Clan Jetties of Penang',
      'Chew Jetty',
      'Chew Jetty Penang',
    ],
    imageUrl:
      'https://commons.wikimedia.org/wiki/Special:FilePath/Clan%20Jetties%20of%20Penang.jpg?width=1200',
    imageType: 'curated_place_photo',
    imageAttribution:
      'Clan Jetties of Penang — Wikimedia Commons',
    imageSourceUrl:
      'https://commons.wikimedia.org/wiki/File:Clan_Jetties_of_Penang.jpg',
    imageNotice: '',
    description:
      'The Clan Jetties are historic waterfront settlements in George '
      + 'Town. They are relevant to travelers interested in local history, '
      + 'living heritage and waterfront culture.',
  },
];

function isGeneratedReview(data) {
  const source = String(data.source || '').toLowerCase();
  return data.isDemo === true ||
    data.isPrototype === true ||
    source.includes('demo') ||
    source.includes('prototype') ||
    source.includes('seed_demo');
}

async function prepareProductionData() {
  const now = Timestamp.now();

  // Keep curated place images and descriptions.
  const contentBatch = db.batch();
  for (const place of placeContent) {
    const { id, ...data } = place;
    contentBatch.set(
      db.collection('place_content').doc(id),
      {
        ...data,
        status: 'active',
        updatedAt: now,
      },
      { merge: true },
    );
  }
  await contentBatch.commit();

  // Remove all previously generated review records.
  const reviewsSnapshot = await db.collection('reviews').get();
  const generatedDocs = reviewsSnapshot.docs.filter((doc) =>
    isGeneratedReview(doc.data()),
  );

  for (let start = 0; start < generatedDocs.length; start += 400) {
    const batch = db.batch();
    const chunk = generatedDocs.slice(start, start + 400);
    for (const doc of chunk) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }

  console.log('');
  console.log('Production review data prepared successfully.');
  console.log(`Curated content retained for ${placeContent.length} locations.`);
  console.log(`Removed ${generatedDocs.length} generated review records.`);
  console.log('');
  console.log(
    'The app will now calculate ratings only from reviews submitted through the real review form.',
  );
}

prepareProductionData()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Production preparation failed:', error);
    process.exit(1);
  });
