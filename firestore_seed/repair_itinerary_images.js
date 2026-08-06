'use strict';

const fs = require('fs');
const path = require('path');
const { initializeApp, cert } = require('firebase-admin/app');
const {
  getFirestore,
  FieldValue,
} = require('firebase-admin/firestore');

const serviceAccount = require('./serviceAccountKey.json');

initializeApp({
  credential: cert(serviceAccount),
});

const db = getFirestore();

function normalise(value) {
  return String(value || '')
      .toLowerCase()
      .replace(/[^a-z0-9]+/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
}

function loadGeoapifyKey() {
  const direct = String(process.env.GEOAPIFY_API_KEY || '').trim();
  if (direct && !direct.includes('PASTE_YOUR')) return direct;

  const configPath = path.join(
    __dirname,
    '..',
    'lib',
    'core',
    'geoapify_config.dart',
  );

  try {
    const text = fs.readFileSync(configPath, 'utf8');
    const match = text.match(
      /defaultValue\s*:\s*['"]([^'"]+)['"]/,
    );
    const value = String(match?.[1] || '').trim();
    if (value && !value.includes('PASTE_YOUR')) return value;
  } catch (_) {
    // A curated photograph can still be repaired without a map key.
  }

  return '';
}

function coordinatesFor(stop) {
  const raw = stop.location;

  if (
    raw &&
    typeof raw.latitude === 'number' &&
    typeof raw.longitude === 'number'
  ) {
    return {
      latitude: raw.latitude,
      longitude: raw.longitude,
    };
  }

  if (
    typeof stop.latitude === 'number' &&
    typeof stop.longitude === 'number'
  ) {
    return {
      latitude: stop.latitude,
      longitude: stop.longitude,
    };
  }

  return null;
}

function staticMapUrl(coordinates, apiKey) {
  if (!coordinates || !apiKey) return '';

  const params = new URLSearchParams({
    style: 'osm-bright',
    width: '640',
    height: '400',
    format: 'jpeg',
    center:
      `lonlat:${coordinates.longitude.toFixed(6)},` +
      `${coordinates.latitude.toFixed(6)}`,
    zoom: '16',
    scaleFactor: '1',
    apiKey,
  });

  return `https://maps.geoapify.com/v1/staticmap?${params.toString()}`;
}

function matchContent(content, placeName) {
  const key = normalise(placeName);
  if (!key) return null;

  if (content.has(key)) return content.get(key);

  const targetWords = new Set(
    key.split(' ').filter((word) => word.length > 2),
  );

  let best = null;
  let bestScore = 0;

  for (const [candidateKey, value] of content.entries()) {
    const candidateWords = new Set(
      candidateKey.split(' ').filter((word) => word.length > 2),
    );

    let score = 0;
    for (const word of targetWords) {
      if (candidateWords.has(word)) score += 1;
    }

    if (score >= 2 && score > bestScore) {
      bestScore = score;
      best = value;
    }
  }

  return best;
}

async function loadContent() {
  const snapshot = await db
      .collection('place_content')
      .where('status', '==', 'active')
      .get();

  const result = new Map();

  for (const document of snapshot.docs) {
    const data = { id: document.id, ...document.data() };
    const keys = [
      data.placeNameKey,
      data.name,
      document.id,
      ...(data.aliases || []),
    ].map(normalise).filter(Boolean);

    for (const key of keys) {
      result.set(key, data);
    }
  }

  return result;
}

function repairedStops(stops, content, apiKey) {
  let changed = false;

  const updated = (stops || []).map((rawStop) => {
    const stop = { ...rawStop };
    const placeContent = matchContent(content, stop.name);
    const contentImage = String(placeContent?.imageUrl || '').trim();
    const coordinates = coordinatesFor(stop);
    const mapPreview = staticMapUrl(coordinates, apiKey);

    const existingImage = String(stop.imageUrl || '').trim();
    const existingFallback = String(
      stop.fallbackImageUrl || stop.mapPreviewUrl || '',
    ).trim();

    const imageUrl =
      contentImage || existingImage || mapPreview;
    const fallbackImageUrl =
      mapPreview || existingFallback;

    const candidates = [
      contentImage,
      existingImage,
      fallbackImageUrl,
      ...(Array.isArray(stop.imageCandidates)
        ? stop.imageCandidates
        : []),
    ].filter(Boolean);

    const uniqueCandidates = [...new Set(candidates)];

    if (
      stop.imageUrl !== imageUrl ||
      stop.fallbackImageUrl !== fallbackImageUrl ||
      JSON.stringify(stop.imageCandidates || []) !==
          JSON.stringify(uniqueCandidates)
    ) {
      changed = true;
    }

    return {
      ...stop,
      imageUrl,
      fallbackImageUrl,
      mapPreviewUrl: fallbackImageUrl,
      imageCandidates: uniqueCandidates,
      imageType:
        contentImage
          ? String(
              placeContent?.imageType || 'wikipedia_place_photo',
            )
          : mapPreview
              ? 'map_preview'
              : String(stop.imageType || ''),
      imageAttribution:
        contentImage
          ? String(
              placeContent?.imageAttribution ||
              'Wikipedia / Wikimedia Commons',
            )
          : String(stop.imageAttribution || ''),
      imageSourceUrl:
        contentImage
          ? String(placeContent?.imageSourceUrl || '')
          : String(stop.imageSourceUrl || ''),
    };
  });

  return { changed, stops: updated };
}

async function repairCollection(collectionName, content, apiKey) {
  const snapshot = await db.collection(collectionName).get();
  let updatedCount = 0;

  for (let start = 0; start < snapshot.docs.length; start += 300) {
    const batch = db.batch();
    let writeCount = 0;

    for (const document of snapshot.docs.slice(start, start + 300)) {
      const data = document.data();
      const result = repairedStops(data.stops, content, apiKey);

      if (!result.changed) continue;

      const coverImageUrl =
        result.stops.find(
          (stop) => String(stop.imageUrl || '').trim(),
        )?.imageUrl || '';

      batch.update(document.ref, {
        stops: result.stops,
        coverImageUrl,
        updatedAt: FieldValue.serverTimestamp(),
      });

      writeCount += 1;
      updatedCount += 1;
    }

    if (writeCount > 0) {
      await batch.commit();
    }
  }

  return updatedCount;
}

async function repair() {
  const apiKey = loadGeoapifyKey();
  const content = await loadContent();

  const itineraries = await repairCollection(
    'itineraries',
    content,
    apiKey,
  );
  const shared = await repairCollection(
    'shared_itineraries',
    content,
    apiKey,
  );

  console.log('');
  console.log('Itinerary image repair completed.');
  console.log(`Curated place-content aliases loaded: ${content.size}`);
  console.log(`Saved itineraries updated: ${itineraries}`);
  console.log(`Shared itineraries updated: ${shared}`);
  console.log(
    apiKey
      ? 'Geoapify map fallback URLs were generated.'
      : 'No Geoapify key was found; curated photographs were still applied.',
  );
}

repair()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error('Itinerary repair failed:', error);
    process.exit(1);
  });
