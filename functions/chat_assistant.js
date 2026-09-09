'use strict';

const { onRequest } = require('firebase-functions/v2/https');
const { defineSecret } = require('firebase-functions/params');
const logger = require('firebase-functions/logger');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const {
  getFirestore,
  Timestamp,
} = require('firebase-admin/firestore');

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const GEMINI_API_KEY = defineSecret('GEMINI_API_KEY');

const REGION = 'asia-southeast1';
const MODEL = 'gemini-3.7-flash';

function cleanText(value, maxLength = 500) {
  return String(value ?? '').trim().slice(0, maxLength);
}

function toIso(value) {
  if (!value) return null;

  try {
    if (typeof value.toDate === 'function') {
      return value.toDate().toISOString();
    }

    if (value instanceof Date) {
      return value.toISOString();
    }
  } catch (_) {
    // Ignore malformed date values.
  }

  return null;
}

function compactGeo(value) {
  if (
    value &&
    typeof value.latitude === 'number' &&
    typeof value.longitude === 'number'
  ) {
    return {
      latitude: Number(value.latitude.toFixed(5)),
      longitude: Number(value.longitude.toFixed(5)),
    };
  }

  return null;
}

function pickStopName(stop) {
  if (!stop || typeof stop !== 'object') return '';

  return cleanText(
    stop.name ||
      stop.title ||
      stop.placeName ||
      stop.locationName ||
      stop.address ||
      '',
    120,
  );
}

async function authenticateRequest(req) {
  const authorization = req.get('Authorization') || '';
  const match = authorization.match(/^Bearer\s+(.+)$/i);

  if (!match) {
    const error = new Error('Please sign in before using the travel assistant.');
    error.statusCode = 401;
    throw error;
  }

  try {
    return await getAuth().verifyIdToken(match[1]);
  } catch (_) {
    const error = new Error(
      'Your login session is invalid. Please sign in again.',
    );
    error.statusCode = 401;
    throw error;
  }
}

async function enforceThrottle(uid) {
  const ref = db.collection('api_usage').doc(`chatAssistant_${uid}`);
  const now = Timestamp.now();

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(ref);
    const previous = snapshot.data()?.lastRequestAt;

    if (previous && typeof previous.toMillis === 'function') {
      const elapsed = now.toMillis() - previous.toMillis();

      if (elapsed < 1200) {
        const error = new Error(
          'Please wait a moment before sending another chatbot message.',
        );
        error.statusCode = 429;
        throw error;
      }
    }

    transaction.set(
      ref,
      {
        userId: uid,
        feature: 'chat_assistant',
        lastRequestAt: now,
      },
      { merge: true },
    );
  });
}

async function safeDocs(label, queryFactory) {
  try {
    const snapshot = await queryFactory();
    return snapshot.docs;
  } catch (error) {
    logger.warn(`Chatbot context query failed: ${label}`, {
      message: error?.message || String(error),
    });
    return [];
  }
}

function uniqueDocuments(documents) {
  const seen = new Set();
  const result = [];

  for (const document of documents) {
    if (seen.has(document.id)) continue;
    seen.add(document.id);
    result.push(document);
  }

  return result;
}

async function buildDatabaseContext(uid) {
  const profilePromise = db.collection('travelers').doc(uid).get();

  const [
    profileSnapshot,
    itineraryDocs,
    groupDocs,
    notificationDocs,
    submissionDocs,
    voucherDocs,
    invitationDocs,
    locationRequestDocs,
    privateChatDocs,
    receivedSosDocs,
    sentSosDocs,
    hazardDocs,
    culturalTaskDocs,
  ] = await Promise.all([
    profilePromise,

    safeDocs('itineraries', () =>
      db.collection('itineraries')
        .where('userId', '==', uid)
        .limit(6)
        .get(),
    ),

    safeDocs('travel_groups', () =>
      db.collection('travel_groups')
        .where('memberIds', 'array-contains', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('notifications', () =>
      db.collection('notifications')
        .where('userId', '==', uid)
        .limit(15)
        .get(),
    ),

    safeDocs('task_submissions', () =>
      db.collection('task_submissions')
        .where('userId', '==', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('claimed_vouchers', () =>
      db.collection('claimed_vouchers')
        .where('userId', '==', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('group_invitations', () =>
      db.collection('group_invitations')
        .where('memberId', '==', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('location_requests', () =>
      db.collection('location_requests')
        .where('targetId', '==', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('private_chats', () =>
      db.collection('private_chats')
        .where('participantIds', 'array-contains', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('received_sos', () =>
      db.collection('sos_alerts')
        .where('recipientIds', 'array-contains', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('sent_sos', () =>
      db.collection('sos_alerts')
        .where('senderId', '==', uid)
        .limit(10)
        .get(),
    ),

    safeDocs('verified_hazards', () =>
      db.collection('hazards')
        .where('status', '==', 'verified')
        .limit(15)
        .get(),
    ),

    safeDocs('active_cultural_tasks', () =>
      db.collection('cultural_tasks')
        .where('status', '==', 'active')
        .limit(15)
        .get(),
    ),
  ]);

  const profile = profileSnapshot.data() || {};

  const itineraries = itineraryDocs.map((doc) => {
    const data = doc.data() || {};
    const stops = Array.isArray(data.stops)
      ? data.stops
          .slice(0, 8)
          .map(pickStopName)
          .filter(Boolean)
      : [];

    return {
      title: cleanText(data.title || 'Saved Itinerary', 140),
      area: cleanText(data.area || '', 100),
      travelPace: cleanText(data.travelPace || '', 40),
      stopCount: Array.isArray(data.stops) ? data.stops.length : 0,
      stops,
      createdAt: toIso(data.createdAt),
      updatedAt: toIso(data.updatedAt),
    };
  });

  const groups = groupDocs.map((doc) => {
    const data = doc.data() || {};
    const memberNames =
      data.memberNames && typeof data.memberNames === 'object'
        ? Object.values(data.memberNames)
            .map((name) => cleanText(name, 100))
            .filter(Boolean)
        : [];

    return {
      name: cleanText(data.name || 'Travel Group', 120),
      description: cleanText(data.description || '', 240),
      status: cleanText(data.status || '', 40),
      userRole: data.leaderId === uid ? 'leader' : 'member',
      memberCount: Array.isArray(data.memberIds) ? data.memberIds.length : 0,
      memberNames,
      updatedAt: toIso(data.updatedAt),
    };
  });

  const notifications = notificationDocs
    .map((doc) => {
      const data = doc.data() || {};
      return {
        title: cleanText(data.title || 'Update', 140),
        message: cleanText(data.message || '', 300),
        type: cleanText(data.type || 'general', 60),
        read: data.read === true,
        createdAt: toIso(data.createdAt),
      };
    })
    .sort((a, b) => String(b.createdAt || '').localeCompare(String(a.createdAt || '')))
    .slice(0, 12);

  const taskSubmissions = submissionDocs.map((doc) => {
    const data = doc.data() || {};
    return {
      taskTitle: cleanText(data.taskTitle || '', 140),
      category: cleanText(data.taskCategory || '', 100),
      status: cleanText(data.status || '', 50),
      rewardPoints: Number(data.rewardPoints || 0),
      submittedAt: toIso(data.submittedAt),
    };
  });

  const claimedVouchers = voucherDocs.map((doc) => {
    const data = doc.data() || {};
    return {
      title: cleanText(data.title || 'Voucher', 140),
      vendorName: cleanText(data.vendorName || '', 120),
      status: cleanText(data.status || '', 50),
      pointCost: Number(data.pointCost || 0),
      claimedAt: toIso(data.claimedAt),
    };
  });

  const invitations = invitationDocs.map((doc) => {
    const data = doc.data() || {};
    return {
      groupName: cleanText(data.groupName || 'Travel Group', 120),
      leaderName: cleanText(data.leaderName || 'Group Leader', 100),
      status: cleanText(data.status || '', 50),
      createdAt: toIso(data.createdAt),
    };
  });

  const locationRequests = locationRequestDocs.map((doc) => {
    const data = doc.data() || {};
    return {
      requestType: cleanText(data.requestType || 'group', 40),
      requesterName: cleanText(data.requesterName || '', 100),
      targetName: cleanText(data.targetName || '', 100),
      status: cleanText(data.status || '', 50),
      createdAt: toIso(data.createdAt),
      respondedAt: toIso(data.respondedAt),
    };
  });

  const privateChats = privateChatDocs.map((doc) => {
    const data = doc.data() || {};
    const names =
      data.participantNames && typeof data.participantNames === 'object'
        ? Object.values(data.participantNames)
            .map((name) => cleanText(name, 100))
            .filter(Boolean)
        : [];

    return {
      participants: names,
      lastMessage: cleanText(data.lastMessage || '', 240),
      lastMessageAt: toIso(data.lastMessageAt),
    };
  });

  const sosAlerts = uniqueDocuments([...receivedSosDocs, ...sentSosDocs]).map(
    (doc) => {
      const data = doc.data() || {};

      return {
        groupName: cleanText(data.groupName || 'Travel Group', 120),
        senderName: cleanText(data.senderName || 'Group Member', 100),
        status: cleanText(data.status || '', 50),
        triggerCount: Number(data.triggerCount || 1),
        relationship: data.senderId === uid ? 'sent_by_user' : 'received_by_user',
        createdAt: toIso(data.createdAt),
        lastTriggeredAt: toIso(data.lastTriggeredAt),
      };
    },
  );

  const verifiedHazards = hazardDocs.map((doc) => {
    const data = doc.data() || {};

    return {
      category: cleanText(data.category || 'Hazard', 100),
      severity: cleanText(data.severity || 'Low', 40),
      description: cleanText(data.description || '', 320),
      location: compactGeo(data.location),
      createdAt: toIso(data.createdAt),
      upvoteCount: Number(data.upvoteCount || 0),
      resolveCount: Number(data.resolveCount || 0),
    };
  });

  const activeCulturalTasks = culturalTaskDocs.map((doc) => {
    const data = doc.data() || {};

    return {
      title: cleanText(data.title || 'Cultural Task', 140),
      category: cleanText(data.category || '', 100),
      difficulty: cleanText(data.difficulty || '', 40),
      locationName: cleanText(data.locationName || '', 140),
      rewardPoints: Number(data.rewardPoints || 0),
      deadline: toIso(data.deadline),
    };
  });

  return {
    contextGeneratedAt: new Date().toISOString(),

    travelerProfile: {
      displayName: cleanText(profile.displayName || 'Traveler', 100),
      travelInterests: Array.isArray(profile.travelInterests)
        ? profile.travelInterests.map((item) => cleanText(item, 60)).slice(0, 12)
        : [],
      budgetPreference: cleanText(profile.budgetPreference || '', 40),
      travelPace: cleanText(profile.travelPace || '', 40),
      points: Number(profile.points || 0),
      localImpactScore: Number(profile.localImpactScore || 0),
      rank: cleanText(profile.rank || '', 40),
    },

    savedItineraries: itineraries,
    travelGroups: groups,
    recentNotifications: notifications,
    culturalTaskSubmissions: taskSubmissions,
    claimedVouchers,
    groupInvitations: invitations,
    incomingLocationRequests: locationRequests,
    privateChats,
    sosAlerts,
    verifiedHazards,
    activeCulturalTasks,
  };
}

function normalizeHistory(rawHistory) {
  if (!Array.isArray(rawHistory)) return [];

  return rawHistory
    .slice(-10)
    .map((item) => {
      const role =
        cleanText(item?.role, 20).toLowerCase() === 'assistant'
          ? 'assistant'
          : 'user';

      const text = cleanText(item?.text, 1200);

      return text ? { role, text } : null;
    })
    .filter(Boolean);
}

function buildModelInput(message, history, databaseContext) {
  const transcript = history
    .map((item) => `${item.role.toUpperCase()}: ${item.text}`)
    .join('\n');

  return [
    'LIVE DATABASE CONTEXT FOR THE SIGNED-IN TRAVELER:',
    JSON.stringify(databaseContext, null, 2),
    '',
    'RECENT CHAT HISTORY:',
    transcript || '(No previous turns.)',
    '',
    'CURRENT USER QUESTION:',
    message,
  ].join('\n');
}

function extractInteractionText(payload) {
  const steps = Array.isArray(payload?.steps) ? payload.steps : [];

  const modelSteps = steps.filter((step) => step?.type === 'model_output');
  if (modelSteps.length === 0) return '';

  const last = modelSteps[modelSteps.length - 1];
  const content = Array.isArray(last.content) ? last.content : [];

  return content
    .filter((part) => part?.type === 'text')
    .map((part) => cleanText(part.text, 12000))
    .filter(Boolean)
    .join('\n')
    .trim();
}

const SYSTEM_INSTRUCTION = `
You are the MyHeritage Explorer intelligent travel assistant for a Malaysian
sustainable-tourism application.

Your job is to reason over the LIVE DATABASE CONTEXT supplied with each request,
the user's current question, and the recent conversation. Do not use hard-coded
keyword-response rules.

Important behavior:
1. Treat the supplied database context as the authoritative source for the
   signed-in user's account state, saved itineraries, travel groups, alerts,
   tasks, vouchers and notifications.
2. Never invent a database fact. If the requested account fact is absent from
   the context, clearly say that it is not available in the current app data.
3. You may use general travel knowledge for general questions, but distinguish
   general advice from facts that came from the user's database.
4. Do not expose internal document IDs, authentication identifiers, API keys,
   tokens, or implementation details.
5. For safety or SOS questions, prioritize clear, actionable safety guidance.
   If there is immediate danger, advise using the app's SOS feature and local
   emergency services.
6. Do not claim real-time weather, opening hours, traffic or live external facts
   unless they are actually present in the supplied context.
7. Keep answers concise and useful. Use short bullets when they improve clarity.
8. If the user asks about their latest itinerary, group, notification, cultural
   task, voucher, hazard or SOS state, answer from the database context.
9. Reason internally and return only the final helpful answer.
`.trim();

exports.chatAssistant = onRequest(
  {
    region: REGION,
    timeoutSeconds: 60,
    memory: '512MiB',
    secrets: [GEMINI_API_KEY],
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
      res.status(405).json({
        error: 'Only POST requests are supported.',
      });
      return;
    }

    try {
      const decodedToken = await authenticateRequest(req);
      await enforceThrottle(decodedToken.uid);

      const message = cleanText(req.body?.message, 1800);
      const history = normalizeHistory(req.body?.history);

      if (!message) {
        res.status(400).json({
          error: 'Please enter a chatbot message.',
        });
        return;
      }

      const databaseContext = await buildDatabaseContext(decodedToken.uid);
      const modelInput = buildModelInput(
        message,
        history,
        databaseContext,
      );

      const response = await fetch(
        'https://generativelanguage.googleapis.com/v1beta/interactions',
        {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': GEMINI_API_KEY.value(),
          },
          body: JSON.stringify({
            model: MODEL,
            input: modelInput,
            system_instruction: SYSTEM_INSTRUCTION,
            store: false,
          }),
        },
      );

      const responseText = await response.text();

      let payload = {};
      if (responseText) {
        try {
          payload = JSON.parse(responseText);
        } catch (_) {
          payload = {};
        }
      }

      if (!response.ok) {
        logger.error('Gemini Interactions API failed', {
          status: response.status,
          body: cleanText(responseText, 1500),
        });

        const error = new Error(
          'The AI assistant is temporarily unavailable. Please try again.',
        );
        error.statusCode = 502;
        throw error;
      }

      const answer = extractInteractionText(payload);

      if (!answer) {
        logger.error('Gemini returned no text output', {
          payload: JSON.stringify(payload).slice(0, 2000),
        });

        const error = new Error(
          'The AI assistant returned an empty response. Please try again.',
        );
        error.statusCode = 502;
        throw error;
      }

      res.status(200).json({
        answer,
        model: MODEL,
        databaseGrounded: true,
        contextGeneratedAt: databaseContext.contextGeneratedAt,
      });
    } catch (error) {
      logger.error('Chat assistant request failed', {
        message: error?.message || String(error),
      });

      res.status(error.statusCode || 500).json({
        error:
          error.message ||
          'Unable to answer right now. Please try again.',
      });
    }
  },
);
