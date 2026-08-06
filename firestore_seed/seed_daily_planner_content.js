'use strict';

const { initializeApp, cert } = require('firebase-admin/app');
const {
  getFirestore,
  Timestamp,
} = require('firebase-admin/firestore');

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

const reviews = {
  kyrin_sushi: [
    {
      rating: 5,
      reviewerName: 'Sample Traveler A',
      comment:
        'The sushi selection was enjoyable and the service was attentive. '
        + 'The restaurant worked well as a relaxed lunch stop.',
      daysAgo: 18,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler B',
      comment:
        'A comfortable place for a casual Japanese meal. The waiting time '
        + 'was reasonable during the visit.',
      daysAgo: 36,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler C',
      comment:
        'The food presentation was good and the staff were friendly. '
        + 'The price level felt moderate for the area.',
      daysAgo: 54,
    },
  ],
  armenian_street: [
    {
      rating: 5,
      reviewerName: 'Sample Traveler D',
      comment:
        'The heritage buildings and street art made this a memorable '
        + 'walking stop in George Town.',
      daysAgo: 12,
    },
    {
      rating: 5,
      reviewerName: 'Sample Traveler E',
      comment:
        'There were many interesting details to photograph, and nearby '
        + 'attractions were easy to reach on foot.',
      daysAgo: 29,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler F',
      comment:
        'A worthwhile heritage area, although it became crowded during '
        + 'the busier part of the day.',
      daysAgo: 47,
    },
  ],
  cheong_fatt_tze_mansion: [
    {
      rating: 5,
      reviewerName: 'Sample Traveler G',
      comment:
        'The architecture and interior details were impressive. The visit '
        + 'added useful historical context to the itinerary.',
      daysAgo: 16,
    },
    {
      rating: 5,
      reviewerName: 'Sample Traveler H',
      comment:
        'A strong choice for travelers interested in heritage buildings '
        + 'and conservation.',
      daysAgo: 33,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler I',
      comment:
        'The mansion was visually distinctive and easy to combine with '
        + 'other central George Town attractions.',
      daysAgo: 61,
    },
  ],
  pinang_peranakan_mansion: [
    {
      rating: 5,
      reviewerName: 'Sample Traveler J',
      comment:
        'The collections and decorated rooms provided a detailed look at '
        + 'Peranakan culture and lifestyle.',
      daysAgo: 11,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler K',
      comment:
        'A useful cultural stop with many objects and interior details to '
        + 'explore.',
      daysAgo: 31,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler L',
      comment:
        'The museum was interesting and informative, especially for a '
        + 'first-time visitor learning about local heritage.',
      daysAgo: 58,
    },
  ],
  clan_jetties: [
    {
      rating: 4,
      reviewerName: 'Sample Traveler M',
      comment:
        'The waterfront setting and wooden walkways offered a different '
        + 'view of George Town living heritage.',
      daysAgo: 14,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler N',
      comment:
        'A meaningful cultural stop that can be visited together with '
        + 'nearby heritage streets.',
      daysAgo: 42,
    },
    {
      rating: 4,
      reviewerName: 'Sample Traveler O',
      comment:
        'The visit was enjoyable, but travelers should be respectful '
        + 'because this remains a residential community.',
      daysAgo: 67,
    },
  ],
};

async function seed() {
  const batch = db.batch();
  const now = new Date();

  for (const place of placeContent) {
    const { id, ...data } = place;
    batch.set(
      db.collection('place_content').doc(id),
      {
        ...data,
        status: 'active',
        updatedAt: Timestamp.fromDate(now),
      },
      { merge: true },
    );

    const placeReviews = reviews[id] || [];
    placeReviews.forEach((review, index) => {
      const createdAt = new Date(
        now.getTime() - review.daysAgo * 24 * 60 * 60 * 1000,
      );
      const reviewRef = db
        .collection('reviews')
        .doc(`demo_${id}_${index + 1}`);

      batch.set(
        reviewRef,
        {
          userId: `demo_user_${index + 1}`,
          reviewerName: review.reviewerName,
          placeId: `seed_${id}`,
          placeName: place.name,
          placeNameKey: place.placeNameKey,
          source: 'seed_demo',
          rating: review.rating,
          comment: review.comment,
          status: 'valid',
          flagReason: null,
          isDemo: true,
          createdAt: Timestamp.fromDate(createdAt),
          updatedAt: Timestamp.fromDate(now),
        },
        { merge: true },
      );
    });
  }

  await batch.commit();

  console.log('');
  console.log('Daily Planner sample data created successfully.');
  console.log(`Seeded ${placeContent.length} place-content records.`);
  console.log(
    `Seeded ${Object.values(reviews).reduce(
      (total, items) => total + items.length,
      0,
    )} labelled sample reviews.`,
  );
  console.log('');
  console.log(
    'These reviews are demonstration records and are labelled SAMPLE in the app.',
  );
}

seed()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Seed failed:', error);
    process.exit(1);
  });
