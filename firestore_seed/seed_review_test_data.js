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

const locations = [
  {
    id: 'kyrin_sushi',
    placeId: 'seed_kyrin_sushi',
    placeName: 'Kyrin Sushi',
    placeNameKey: 'kyrin sushi',
    reviews: [
      {
        reviewerName: 'Aina Rahman',
        rating: 5,
        comment:
          'The sushi was fresh, the presentation was neat and the staff were attentive throughout the meal.',
        status: 'valid',
      },
      {
        reviewerName: 'Daniel Lim',
        rating: 4,
        comment:
          'A comfortable place for lunch with a good variety of Japanese dishes and reasonable waiting time.',
        status: 'valid',
      },
      {
        reviewerName: 'Nur Izzati',
        rating: 4,
        comment:
          'The food quality was consistent and the dining area was clean. I would return for another meal.',
        status: 'valid',
      },
      {
        reviewerName: 'Marcus Lee',
        rating: 5,
        comment:
          'Terrible service and the food was disappointing.',
        status: 'flagged',
        flagReasons: ['Possible rating-comment mismatch'],
      },
      {
        reviewerName: 'Siti Hajar',
        rating: 3,
        comment: 'Good good good good good',
        status: 'flagged',
        flagReasons: ['Repeated word or phrase pattern'],
      },
    ],
  },
  {
    id: 'armenian_street',
    placeId: 'seed_armenian_street',
    placeName: 'Armenian Street',
    placeNameKey: 'armenian street',
    reviews: [
      {
        reviewerName: 'Wei Jian',
        rating: 5,
        comment:
          'The heritage buildings and street art made this one of the most interesting walking areas in George Town.',
        status: 'valid',
      },
      {
        reviewerName: 'Farah Nadia',
        rating: 4,
        comment:
          'There are many photo spots and small shops nearby. Visiting earlier in the morning was more comfortable.',
        status: 'valid',
      },
      {
        reviewerName: 'Harith Iskandar',
        rating: 4,
        comment:
          'A lively cultural street that connects easily with several nearby heritage attractions.',
        status: 'valid',
      },
      {
        reviewerName: 'Mei Ling',
        rating: 1,
        comment:
          'Amazing place with wonderful art and a great atmosphere.',
        status: 'flagged',
        flagReasons: ['Possible rating-comment mismatch'],
      },
      {
        reviewerName: 'Jason Tan',
        rating: 4,
        comment: 'Nice',
        status: 'flagged',
        flagReasons: ['Review is too short or generic'],
      },
    ],
  },
  {
    id: 'cheong_fatt_tze_mansion',
    placeId: 'seed_cheong_fatt_tze_mansion',
    placeName: 'Cheong Fatt Tze Mansion',
    placeNameKey: 'cheong fatt tze mansion',
    reviews: [
      {
        reviewerName: 'Amirah Yusuf',
        rating: 5,
        comment:
          'The architecture and interior details were impressive, and the visit provided useful historical context.',
        status: 'valid',
      },
      {
        reviewerName: 'Bryan Wong',
        rating: 5,
        comment:
          'The guided experience was informative and the mansion was well maintained during my visit.',
        status: 'valid',
      },
      {
        reviewerName: 'Priya Nair',
        rating: 4,
        comment:
          'A strong heritage stop for travelers interested in conservation, architecture and local history.',
        status: 'valid',
      },
      {
        reviewerName: 'Adam Chong',
        rating: 4,
        comment:
          'The architecture and interior details were impressive, and the visit provided useful historical context.',
        status: 'flagged',
        flagReasons: ['Duplicate review text detected'],
      },
      {
        reviewerName: 'Hui Min',
        rating: 2,
        comment:
          'Perfect experience, fantastic guide and the best heritage attraction in the city.',
        status: 'flagged',
        flagReasons: ['Possible rating-comment mismatch'],
      },
    ],
  },
  {
    id: 'pinang_peranakan_mansion',
    placeId: 'seed_pinang_peranakan_mansion',
    placeName: 'Pinang Peranakan Mansion',
    placeNameKey: 'pinang peranakan mansion',
    reviews: [
      {
        reviewerName: 'Kavitha Raj',
        rating: 5,
        comment:
          'The decorated rooms and collections gave a detailed introduction to Peranakan culture and daily life.',
        status: 'valid',
      },
      {
        reviewerName: 'Muhammad Aqil',
        rating: 4,
        comment:
          'There were many objects to explore and the displays helped explain local cultural traditions.',
        status: 'valid',
      },
      {
        reviewerName: 'Chloe Ng',
        rating: 4,
        comment:
          'An informative museum that fits well into a heritage-focused George Town itinerary.',
        status: 'valid',
      },
      {
        reviewerName: 'Raymond Goh',
        rating: 3,
        comment: 'Museum museum museum museum museum',
        status: 'flagged',
        flagReasons: ['Repeated word or phrase pattern'],
      },
    ],
  },
  {
    id: 'clan_jetties',
    placeId: 'seed_clan_jetties',
    placeName: 'Clan Jetties',
    placeNameKey: 'clan jetties',
    reviews: [
      {
        reviewerName: 'Nadia Azman',
        rating: 4,
        comment:
          'The waterfront setting and wooden walkways offered a different view of George Town living heritage.',
        status: 'valid',
      },
      {
        reviewerName: 'Kelvin Ooi',
        rating: 4,
        comment:
          'A meaningful cultural stop, but visitors should remain respectful because it is still a residential area.',
        status: 'valid',
      },
      {
        reviewerName: 'Shalini Devi',
        rating: 4,
        comment:
          'The location was easy to combine with nearby heritage streets and the waterfront views were enjoyable.',
        status: 'valid',
      },
      {
        reviewerName: 'Ian Low',
        rating: 2,
        comment:
          'Excellent place, amazing scenery and I loved every part of the visit.',
        status: 'flagged',
        flagReasons: ['Possible rating-comment mismatch'],
      },
    ],
  },
];

async function removePreviousInitialReviews() {
  const snapshot = await db
      .collection('reviews')
      .where('source', '==', 'initial_content')
      .get();

  for (let start = 0; start < snapshot.docs.length; start += 400) {
    const batch = db.batch();
    for (const doc of snapshot.docs.slice(start, start + 400)) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }
  return snapshot.docs.length;
}

async function seedReviews() {
  const removed = await removePreviousInitialReviews();
  const now = Date.now();
  let validCount = 0;
  let flaggedCount = 0;
  let reviewNumber = 0;

  const batch = db.batch();

  for (const location of locations) {
    for (const review of location.reviews) {
      reviewNumber += 1;
      const flags = review.flagReasons || [];
      const daysAgo = 4 + reviewNumber * 3;
      const createdAt = new Date(
        now - daysAgo * 24 * 60 * 60 * 1000,
      );

      if (review.status === 'flagged') {
        flaggedCount += 1;
      } else {
        validCount += 1;
      }

      const ref = db
          .collection('reviews')
          .doc(`initial_${location.id}_${reviewNumber}`);

      batch.set(ref, {
        userId: `initial_user_${reviewNumber}`,
        reviewerName: review.reviewerName,
        placeId: location.placeId,
        placeName: location.placeName,
        placeNameKey: location.placeNameKey,
        source: 'initial_content',
        rating: review.rating,
        comment: review.comment,
        status: review.status,
        flagReason: flags.length > 0 ? flags.join(' • ') : null,
        flagReasons: flags,
        seededForTesting: true,
        createdAt: Timestamp.fromDate(createdAt),
        updatedAt: Timestamp.now(),
      });
    }
  }

  await batch.commit();

  console.log('');
  console.log('Review records created successfully.');
  console.log(`Removed previous initial records: ${removed}`);
  console.log(`Valid reviews created: ${validCount}`);
  console.log(`Flagged reviews created: ${flaggedCount}`);
  console.log(`Total reviews created: ${validCount + flaggedCount}`);
  console.log('');
  console.log(
    'Open Admin > Review Moderation to inspect and moderate the flagged reviews.',
  );
}

seedReviews()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Review creation failed:', error);
    process.exit(1);
  });
