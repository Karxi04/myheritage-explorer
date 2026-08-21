'use strict';

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');

initializeApp();

const db = getFirestore();
const googlePlacesApiKey = defineSecret('GOOGLE_PLACES_API_KEY');

const INTEREST_QUERIES = Object.freeze({
  Heritage: (area) =>
    `heritage attractions historical landmarks museums in ${area}, Malaysia`,
  Food: (area) =>
    `local Malaysian food restaurants traditional food in ${area}, Malaysia`,
  Art: (area) =>
    `art galleries street art museums creative attractions in ${area}, Malaysia`,
  Culture: (area) =>
    `cultural attractions temples traditional culture in ${area}, Malaysia`,
  Nature: (area) =>
    `parks gardens nature attractions in ${area}, Malaysia`,
});

const DEFAULT_DURATION = Object.freeze({
  Heritage: 75,
  Food: 60,
  Art: 60,
  Culture: 75,
  Nature: 90,
  'Local Business': 45,
});

function cleanText(value, maxLength = 120) {
  return String(value ?? '').trim().slice(0, maxLength);
}

function normalize(value) {
  return cleanText(value, 200)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, ' ')
    .trim();
}

function safeInternalId(prefix, value) {
  return `${prefix}_${String(value ?? '')
    .replace(/[^a-zA-Z0-9_-]/g, '_')
    .slice(0, 180)}`;
}

function numeric(value, fallback = 0) {
  const result = Number(value);
  return Number.isFinite(result) ? result : fallback;
}

function budgetFromPriceLevel(priceLevel) {
  switch (priceLevel) {
    case 'PRICE_LEVEL_FREE':
    case 'PRICE_LEVEL_INEXPENSIVE':
      return 'Low';
    case 'PRICE_LEVEL_EXPENSIVE':
    case 'PRICE_LEVEL_VERY_EXPENSIVE':
      return 'High';
    case 'PRICE_LEVEL_MODERATE':
      return 'Medium';
    default:
      return 'Unknown';
  }
}

function budgetAllowed(userBudget, placeBudget) {
  if (!placeBudget || placeBudget === 'Unknown') return true;
  const rank = { Low: 1, Medium: 2, High: 3 };
  return (rank[placeBudget] ?? 2) <= (rank[userBudget] ?? 2);
}

function paceMultiplier(pace) {
  switch (pace) {
    case 'Relaxed':
      return 1.25;
    case 'Fast':
      return 0.8;
    default:
      return 1;
  }
}

function travelBuffer(pace) {
  switch (pace) {
    case 'Relaxed':
      return 15;
    case 'Fast':
      return 8;
    default:
      return 10;
  }
}

function inferredCategory(types, requestedInterest) {
  const set = new Set(Array.isArray(types) ? types : []);
  if (
    set.has('restaurant') ||
    set.has('cafe') ||
    set.has('bakery') ||
    set.has('food_court') ||
    set.has('meal_takeaway')
  ) {
    return 'Food';
  }
  if (
    set.has('art_gallery') ||
    set.has('art_museum') ||
    set.has('art_studio')
  ) {
    return 'Art';
  }
  if (
    set.has('park') ||
    set.has('botanical_garden') ||
    set.has('national_park') ||
    set.has('hiking_area')
  ) {
    return 'Nature';
  }
  if (
    set.has('museum') ||
    set.has('historical_landmark') ||
    set.has('historical_place') ||
    set.has('cultural_landmark')
  ) {
    return requestedInterest === 'Culture' ? 'Culture' : 'Heritage';
  }
  return requestedInterest;
}

function rankingScore(candidate) {
  const rating = numeric(candidate.googleRating ?? candidate.score, 0);
  const count = numeric(candidate.googleUserRatingCount, 0);
  const ratingScore = rating / 5;
  const reviewConfidence = Math.min(Math.log10(count + 1) / 4, 1);
  const sourceBonus =
    candidate.source === 'verified_vendor'
      ? 0.35
      : candidate.source === 'firestore'
        ? 0.2
        : 0;
  const taskBonus = candidate.culturalTask ? 0.25 : 0;
  return ratingScore * 0.65 + reviewConfidence * 0.2 + sourceBonus + taskBonus;
}

async function authenticateRequest(req) {
  const authorization = req.get('Authorization') || '';
  const match = authorization.match(/^Bearer\s+(.+)$/i);
  if (!match) {
    const error = new Error('Please sign in before generating an itinerary.');
    error.statusCode = 401;
    throw error;
  }
  try {
    return await getAuth().verifyIdToken(match[1]);
  } catch (_) {
    const error = new Error('Your login session is invalid. Please sign in again.');
    error.statusCode = 401;
    throw error;
  }
}

async function enforceThrottle(uid) {
  const ref = db.collection('api_usage').doc(`dailyPlanner_${uid}`);
  const now = Timestamp.now();

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const previous = snapshot.data()?.lastRequestAt;
    if (previous && typeof previous.toMillis === 'function') {
      const elapsed = now.toMillis() - previous.toMillis();
      if (elapsed < 3000) {
        const error = new Error(
          'Please wait a few seconds before generating another itinerary.',
        );
        error.statusCode = 429;
        throw error;
      }
    }
    transaction.set(
      ref,
      {
        userId: uid,
        feature: 'daily_planner',
        lastRequestAt: now,
      },
      { merge: true },
    );
  });
}

async function callPlacesApi(url, options, fieldMask) {
  const response = await fetch(url, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': googlePlacesApiKey.value(),
      'X-Goog-FieldMask': fieldMask,
      ...(options.headers || {}),
    },
  });

  const bodyText = await response.text();
  let body = {};
  if (bodyText) {
    try {
      body = JSON.parse(bodyText);
    } catch (_) {
      body = {};
    }
  }

  if (!response.ok) {
    const message =
      body?.error?.message ||
      `Google Places request failed with status ${response.status}.`;
    const error = new Error(message);
    error.statusCode = response.status;
    throw error;
  }
  return body;
}

async function searchGoogleInterest(area, interest) {
  const queryBuilder = INTEREST_QUERIES[interest];
  if (!queryBuilder) return [];

  const response = await callPlacesApi(
    'https://places.googleapis.com/v1/places:searchText',
    {
      method: 'POST',
      body: JSON.stringify({
        textQuery: queryBuilder(area),
        pageSize: 8,
        languageCode: 'en',
        regionCode: 'MY',
        minRating: 3.5,
      }),
    },
    [
      'places.id',
      'places.displayName',
      'places.formattedAddress',
      'places.location',
      'places.rating',
      'places.userRatingCount',
      'places.types',
      'places.primaryType',
      'places.priceLevel',
      'places.googleMapsUri',
      'places.businessStatus',
    ].join(','),
  );

  return (response.places || [])
    .filter(
      (place) =>
        place.businessStatus !== 'CLOSED_PERMANENTLY' &&
        place.businessStatus !== 'CLOSED_TEMPORARILY',
    )
    .map((place) => {
      const category = inferredCategory(place.types, interest);
      const placeId = safeInternalId('google', place.id);
      const budgetLevel = budgetFromPriceLevel(place.priceLevel);
      return {
        placeId,
        googlePlaceId: place.id,
        source: 'google',
        name: place.displayName?.text || 'Unnamed place',
        description: place.formattedAddress || '',
        formattedAddress: place.formattedAddress || '',
        area,
        category,
        tags: [category, interest],
        durationMinutes: DEFAULT_DURATION[category] || 60,
        budgetLevel,
        googleRating: numeric(place.rating, 0),
        googleUserRatingCount: numeric(place.userRatingCount, 0),
        score: numeric(place.rating, 0),
        googleMapsUri: place.googleMapsUri || '',
        location: place.location
          ? {
              latitude: numeric(place.location.latitude),
              longitude: numeric(place.location.longitude),
            }
          : null,
        trustLabel: 'Insufficient Data',
      };
    });
}

async function loadFirestorePlaces(area, interests) {
  const snapshot = await db
    .collection('places')
    .where('status', '==', 'active')
    .get();

  const areaKey = normalize(area);
  const interestSet = new Set(interests.map(normalize));
  return snapshot.docs
    .map((doc) => {
      const data = doc.data();
      const category = cleanText(data.category || 'Heritage');
      const tags = Array.isArray(data.tags) ? data.tags.map(cleanText) : [];
      const location = data.location;
      return {
        placeId: doc.id,
        googlePlaceId: data.googlePlaceId || null,
        source: 'firestore',
        name: cleanText(data.name || 'Unnamed place', 160),
        description: cleanText(data.description || '', 600),
        formattedAddress: cleanText(
          data.formattedAddress || data.area || '',
          300,
        ),
        area: cleanText(data.area || area, 160),
        category,
        tags,
        durationMinutes: Math.max(
          30,
          Math.round(numeric(data.durationMinutes, DEFAULT_DURATION[category] || 60)),
        ),
        budgetLevel: cleanText(data.budgetLevel || 'Medium'),
        score: numeric(data.score, 0),
        googleRating: data.googleRating == null
          ? null
          : numeric(data.googleRating, 0),
        googleUserRatingCount: numeric(data.googleUserRatingCount, 0),
        googleMapsUri: cleanText(data.googleMapsUri || '', 1000),
        imageUrl: cleanText(data.imageUrl || '', 1000),
        location:
          location &&
          typeof location.latitude === 'number' &&
          typeof location.longitude === 'number'
            ? {
                latitude: location.latitude,
                longitude: location.longitude,
              }
            : null,
        trustLabel: cleanText(data.trustLabel || 'Insufficient Data'),
        activeCulturalTaskId: data.activeCulturalTaskId || null,
      };
    })
    .filter((place) => {
      const matchesArea =
        normalize(place.area).includes(areaKey) ||
        areaKey.includes(normalize(place.area));
      const matchValues = [place.category, ...place.tags].map(normalize);
      const matchesInterest = matchValues.some((value) =>
        interestSet.has(value),
      );
      return matchesArea && matchesInterest;
    });
}

async function loadVerifiedVendors(area, interests) {
  if (!interests.includes('Local Business')) return [];

  const snapshot = await db.collection('users').where('role', '==', 'vendor').get();
  const areaKey = normalize(area);

  return snapshot.docs
    .filter((doc) => {
      const data = doc.data();
      return (
        data.status === 'active' &&
        data.vendorStatus === 'verified' &&
        normalize(data.shopLocation).includes(areaKey)
      );
    })
    .map((doc) => {
      const data = doc.data();
      return {
        placeId: safeInternalId('vendor', doc.id),
        googlePlaceId: data.googlePlaceId || null,
        vendorId: doc.id,
        source: 'verified_vendor',
        name: cleanText(
          data.businessName || data.displayName || 'Verified local business',
          160,
        ),
        description: cleanText(data.businessDescription || '', 600),
        formattedAddress: cleanText(data.shopLocation || area, 300),
        area: cleanText(data.shopLocation || area, 160),
        category: 'Local Business',
        tags: ['Local Business', cleanText(data.businessCategory || '')],
        durationMinutes: 45,
        budgetLevel: cleanText(data.budgetLevel || 'Medium'),
        score: numeric(data.score, 0),
        googleRating: data.googleRating == null
          ? null
          : numeric(data.googleRating, 0),
        googleUserRatingCount: numeric(data.googleUserRatingCount, 0),
        googleMapsUri: cleanText(data.googleMapsUri || '', 1000),
        imageUrl: cleanText(data.imageUrl || '', 1000),
        location: null,
        trustLabel: cleanText(data.trustLabel || 'Insufficient Data'),
      };
    });
}

async function loadActiveTasks() {
  const snapshot = await db
    .collection('cultural_tasks')
    .where('status', '==', 'active')
    .get();
  const now = Date.now();

  return snapshot.docs
    .map((doc) => ({ id: doc.id, ...doc.data() }))
    .filter((task) => {
      const deadline = task.deadline;
      return (
        !deadline ||
        typeof deadline.toMillis !== 'function' ||
        deadline.toMillis() >= now
      );
    });
}

function matchCulturalTask(candidate, tasks) {
  const nameKey = normalize(candidate.name);
  return (
    tasks.find((task) => {
      if (
        task.placeId &&
        String(task.placeId) === String(candidate.placeId)
      ) {
        return true;
      }
      if (
        task.googlePlaceId &&
        candidate.googlePlaceId &&
        String(task.googlePlaceId) === String(candidate.googlePlaceId)
      ) {
        return true;
      }
      const locationKey = normalize(task.locationName);
      return (
        locationKey.length >= 4 &&
        (nameKey.includes(locationKey) || locationKey.includes(nameKey))
      );
    }) || null
  );
}

async function loadReviewStats(placeId) {
  const snapshot = await db
    .collection('reviews')
    .where('placeId', '==', placeId)
    .get();

  const reviews = snapshot.docs.map((doc) => doc.data());
  const valid = reviews.filter((review) => review.status === 'valid');
  const flagged = reviews.filter((review) => review.status === 'flagged');
  const average =
    valid.length === 0
      ? 0
      : valid.reduce((sum, review) => sum + numeric(review.rating), 0) /
        valid.length;

  let trustLabel = 'Insufficient Data';
  if (reviews.length >= 3) {
    const flaggedRatio = flagged.length / reviews.length;
    trustLabel =
      flaggedRatio <= 0.1
        ? 'High Trust'
        : flaggedRatio <= 0.3
          ? 'Medium Trust'
          : 'Low Trust';
  }

  return {
    inAppAverageRating: Number(average.toFixed(1)),
    inAppReviewCount: valid.length,
    flaggedReviewCount: flagged.length,
    trustLabel,
  };
}

async function loadGoogleDetails(candidate) {
  if (!candidate.googlePlaceId) return candidate;

  try {
    const response = await callPlacesApi(
      `https://places.googleapis.com/v1/places/${encodeURIComponent(
        candidate.googlePlaceId,
      )}?languageCode=en&regionCode=MY`,
      { method: 'GET' },
      [
        'id',
        'rating',
        'userRatingCount',
        'googleMapsUri',
        'reviews',
      ].join(','),
    );

    const googleReviews = (response.reviews || []).slice(0, 5).map((review) => ({
      rating: numeric(review.rating, 0),
      text: cleanText(review.text?.text || '', 1200),
      relativePublishTimeDescription: cleanText(
        review.relativePublishTimeDescription || '',
        120,
      ),
      googleMapsUri: cleanText(review.googleMapsUri || '', 1200),
      flagContentUri: cleanText(review.flagContentUri || '', 1200),
      author: {
        displayName: cleanText(
          review.authorAttribution?.displayName || 'Google user',
          160,
        ),
        uri: cleanText(review.authorAttribution?.uri || '', 1200),
        photoUri: cleanText(
          review.authorAttribution?.photoUri || '',
          1200,
        ),
      },
    }));

    return {
      ...candidate,
      googleRating: numeric(response.rating, candidate.googleRating),
      googleUserRatingCount: numeric(
        response.userRatingCount,
        candidate.googleUserRatingCount,
      ),
      googleMapsUri: response.googleMapsUri || candidate.googleMapsUri,
      googleReviews,
    };
  } catch (error) {
    logger.warn('Unable to load Google place details', {
      googlePlaceId: candidate.googlePlaceId,
      message: error.message,
    });
    return candidate;
  }
}

function deduplicateCandidates(candidates) {
  const byKey = new Map();

  for (const candidate of candidates) {
    const key = candidate.googlePlaceId
      ? `google:${candidate.googlePlaceId}`
      : `name:${normalize(candidate.name)}:${normalize(candidate.area)}`;
    const current = byKey.get(key);
    if (!current || rankingScore(candidate) > rankingScore(current)) {
      byKey.set(key, candidate);
    }
  }
  return [...byKey.values()];
}

function selectItinerary(candidates, availableMinutes, pace) {
  const multiplier = paceMultiplier(pace);
  const buffer = travelBuffer(pace);
  const remainingCandidates = candidates
    .map((candidate) => ({
      ...candidate,
      durationMinutes: Math.max(
        30,
        Math.round(numeric(candidate.durationMinutes, 60) * multiplier),
      ),
    }))
    .sort((a, b) => rankingScore(b) - rankingScore(a));

  const selected = [];
  const categoryCounts = new Map();
  let remaining = availableMinutes;

  while (remainingCandidates.length > 0 && selected.length < 6) {
    let bestIndex = -1;
    let bestAdjustedScore = -Infinity;

    for (let index = 0; index < remainingCandidates.length; index += 1) {
      const candidate = remainingCandidates[index];
      const travelMinutesBefore = selected.length === 0 ? 0 : buffer;
      const required = candidate.durationMinutes + travelMinutesBefore;
      if (required > remaining) continue;

      const categoryPenalty =
        (categoryCounts.get(candidate.category) || 0) * 0.22;
      const adjustedScore = rankingScore(candidate) - categoryPenalty;
      if (adjustedScore > bestAdjustedScore) {
        bestAdjustedScore = adjustedScore;
        bestIndex = index;
      }
    }

    if (bestIndex < 0) break;
    const candidate = remainingCandidates.splice(bestIndex, 1)[0];
    const travelMinutesBefore = selected.length === 0 ? 0 : buffer;
    selected.push({ ...candidate, travelMinutesBefore });
    remaining -= candidate.durationMinutes + travelMinutesBefore;
    categoryCounts.set(
      candidate.category,
      (categoryCounts.get(candidate.category) || 0) + 1,
    );
  }

  if (selected.length === 0 && remainingCandidates.length > 0) {
    const shortest = [...remainingCandidates].sort(
      (a, b) => a.durationMinutes - b.durationMinutes,
    )[0];
    if (shortest.durationMinutes <= availableMinutes) {
      selected.push({ ...shortest, travelMinutesBefore: 0 });
      remaining = availableMinutes - shortest.durationMinutes;
    }
  }

  return {
    selected,
    totalEstimatedMinutes: availableMinutes - remaining,
    remainingMinutes: remaining,
  };
}

exports.generateDailyItinerary = onRequest(
  {
    region: 'asia-southeast1',
    timeoutSeconds: 60,
    memory: '512MiB',
    secrets: [googlePlacesApiKey],
  },
  async (req, res) => {
    res.set('Access-Control-Allow-Origin', '*');
    res.set(
      'Access-Control-Allow-Headers',
      'Authorization, Content-Type',
    );
    res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Only POST requests are supported.' });
      return;
    }

    try {
      const decodedToken = await authenticateRequest(req);
      await enforceThrottle(decodedToken.uid);

      const area = cleanText(req.body?.area, 120);
      const availableHours = numeric(req.body?.availableHours, 0);
      const interests = Array.isArray(req.body?.interests)
        ? [...new Set(req.body.interests.map((item) => cleanText(item, 50)))]
        : [];
      const budgetLevel = cleanText(req.body?.budgetLevel, 20);
      const travelPace = cleanText(req.body?.travelPace, 20);

      if (
        !area ||
        availableHours < 1 ||
        availableHours > 12 ||
        interests.length === 0
      ) {
        res.status(400).json({
          error:
            'Provide an area, available time and at least one interest.',
        });
        return;
      }

      const acceptedBudget = ['Low', 'Medium', 'High'].includes(budgetLevel)
        ? budgetLevel
        : 'Medium';
      const acceptedPace = ['Relaxed', 'Balanced', 'Fast'].includes(travelPace)
        ? travelPace
        : 'Balanced';
      const acceptedInterests = interests.filter((interest) =>
        [
          'Heritage',
          'Food',
          'Art',
          'Culture',
          'Nature',
          'Local Business',
        ].includes(interest),
      );

      const googleInterests = acceptedInterests.filter(
        (interest) => interest !== 'Local Business',
      );

      const [
        googleSettled,
        firestorePlaces,
        verifiedVendors,
        tasks,
      ] = await Promise.all([
        Promise.allSettled(
          googleInterests.map((interest) =>
            searchGoogleInterest(area, interest),
          ),
        ),
        loadFirestorePlaces(area, acceptedInterests),
        loadVerifiedVendors(area, acceptedInterests),
        loadActiveTasks(),
      ]);

      const googlePlaces = googleSettled.flatMap((result) => {
        if (result.status === 'fulfilled') return result.value;
        logger.warn('Google interest search failed', {
          message: result.reason?.message || String(result.reason),
        });
        return [];
      });

      let candidates = deduplicateCandidates([
        ...verifiedVendors,
        ...firestorePlaces,
        ...googlePlaces,
      ])
        .filter((candidate) =>
          budgetAllowed(acceptedBudget, candidate.budgetLevel),
        )
        .map((candidate) => {
          const task = matchCulturalTask(candidate, tasks);
          return {
            ...candidate,
            culturalTask: task
              ? {
                  id: task.id,
                  title: cleanText(task.title || '', 160),
                  description: cleanText(task.description || '', 600),
                  rewardPoints: numeric(task.rewardPoints, 0),
                  locationName: cleanText(task.locationName || '', 160),
                }
              : null,
          };
        });

      if (candidates.length === 0) {
        res.status(200).json({
          places: [],
          summary: {
            totalEstimatedMinutes: 0,
            remainingMinutes: Math.round(availableHours * 60),
          },
        });
        return;
      }

      const itinerary = selectItinerary(
        candidates,
        Math.round(availableHours * 60),
        acceptedPace,
      );

      const enriched = await Promise.all(
        itinerary.selected.map(async (candidate) => {
          const [googleDetails, reviewStats] = await Promise.all([
            loadGoogleDetails(candidate),
            loadReviewStats(candidate.placeId),
          ]);

          const score =
            reviewStats.inAppReviewCount > 0
              ? reviewStats.inAppAverageRating
              : numeric(googleDetails.googleRating ?? candidate.score, 0);

          return {
            ...googleDetails,
            score,
            trustLabel: reviewStats.trustLabel,
            inAppAverageRating: reviewStats.inAppAverageRating,
            inAppReviewCount: reviewStats.inAppReviewCount,
            flaggedReviewCount: reviewStats.flaggedReviewCount,
          };
        }),
      );

      res.status(200).json({
        places: enriched,
        summary: {
          area,
          availableHours,
          interests: acceptedInterests,
          budgetLevel: acceptedBudget,
          travelPace: acceptedPace,
          stopCount: enriched.length,
          totalEstimatedMinutes: itinerary.totalEstimatedMinutes,
          remainingMinutes: itinerary.remainingMinutes,
        },
      });
    } catch (error) {
      logger.error('Daily Planner generation failed', error);
      res.status(error.statusCode || 500).json({
        error:
          error.message ||
          'Unable to generate the itinerary. Please try again.',
      });
    }
  },
);

// Companion group membership operations run on the trusted backend so
// clients do not need permission to read another traveler's private profile.
const companionMembership = require('./companion_membership');
exports.addTravelGroupMemberByEmail =
  companionMembership.addTravelGroupMemberByEmail;
exports.joinTravelGroup = companionMembership.joinTravelGroup;
