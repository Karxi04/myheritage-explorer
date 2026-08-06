const { initializeApp, cert } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
} = require("firebase-admin/firestore");

const serviceAccount = require("./serviceAccountKey.json");

// Connect the script to your Firebase project.
initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

const places = [
  {
    name: "Clan Jetties of Penang",
    category: "Heritage",
    description:
      "Historic traditional waterfront settlement in George Town.",
    area: "George Town",
    score: 4.8,
    trustLabel: "High Trust",
    estimatedTime: "09:00 AM",
    distance: "15 min walk",
    imageUrl: "https://example.com/clan-jetties.jpg",
  },
  {
    name: "Kek Lok Si Temple",
    category: "Cultural",
    description:
      "A well-known Buddhist temple complex located in Air Itam.",
    area: "Air Itam",
    score: 4.7,
    trustLabel: "High Trust",
    estimatedTime: "11:00 AM",
    distance: "20 min drive",
    imageUrl: "https://example.com/kek-lok-si.jpg",
  },
  {
    name: "Fort Cornwallis",
    category: "Historical",
    description:
      "A historic fort located near the Esplanade in George Town.",
    area: "George Town",
    score: 4.5,
    trustLabel: "Verified",
    estimatedTime: "02:00 PM",
    distance: "10 min walk",
    imageUrl: "https://example.com/fort-cornwallis.jpg",
  },
];

async function collectionIsEmpty(collectionName) {
  const snapshot = await db
    .collection(collectionName)
    .limit(1)
    .get();

  return snapshot.empty;
}

async function seedPlaces(batch) {
  const isEmpty = await collectionIsEmpty("places");

  if (!isEmpty) {
    console.log("places already contains data. Skipping.");
    return;
  }

  for (const place of places) {
    // Calling doc() without an ID generates an automatic document ID.
    const documentReference = db.collection("places").doc();

    batch.set(documentReference, {
      ...place,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  }

  console.log(`${places.length} place documents prepared.`);
}

async function createPlaceholder(batch, collectionName) {
  const isEmpty = await collectionIsEmpty(collectionName);

  if (!isEmpty) {
    console.log(`${collectionName} already contains data. Skipping.`);
    return;
  }

  const placeholderReference = db
    .collection(collectionName)
    .doc("_placeholder");

  batch.set(placeholderReference, {
    isPlaceholder: true,
    note: "Delete this document after actual data is added.",
    createdAt: FieldValue.serverTimestamp(),
  });

  console.log(`${collectionName} placeholder prepared.`);
}

async function seedFirestore() {
  try {
    const batch = db.batch();

    await seedPlaces(batch);
    await createPlaceholder(batch, "itineraries");
    await createPlaceholder(batch, "reviews");
    await createPlaceholder(batch, "cultural_tasks");
    await createPlaceholder(batch, "users");

    await batch.commit();

    console.log("\nFirestore setup completed successfully.");
    console.log("Collections created:");
    console.log("- places");
    console.log("- itineraries");
    console.log("- reviews");
    console.log("- cultural_tasks");
    console.log("- users");
  } catch (error) {
    console.error("\nFailed to seed Firestore:");
    console.error(error);
    process.exitCode = 1;
  }
}

seedFirestore();