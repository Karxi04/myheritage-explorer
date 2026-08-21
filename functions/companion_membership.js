'use strict';

const { onRequest } = require('firebase-functions/v2/https');
const { getAuth } = require('firebase-admin/auth');
const {
  getFirestore,
  Timestamp,
  FieldValue,
} = require('firebase-admin/firestore');

const db = getFirestore();

function cleanText(value, maxLength = 160) {
  return String(value ?? '').trim().slice(0, maxLength);
}

function setCors(res) {
  res.set('Access-Control-Allow-Origin', '*');
  res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type');
  res.set('Access-Control-Allow-Methods', 'POST, OPTIONS');
}

async function authenticateRequest(req) {
  const authorization = req.get('Authorization') || '';
  const match = authorization.match(/^Bearer\\s+(.+)$/i);

  if (!match) {
    const error = new Error('Please sign in first.');
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

function sendError(res, error) {
  res.status(error.statusCode || 500).json({
    error: error.message || 'Unable to complete the request.',
  });
}

async function findTravelerByUid(uid) {
  const direct = await db.collection('travelers').doc(uid).get();
  if (direct.exists) {
    return { id: direct.id, data: direct.data() || {} };
  }

  const byUid = await db
    .collection('travelers')
    .where('uid', '==', uid)
    .limit(1)
    .get();

  if (byUid.empty) return null;
  return { id: byUid.docs[0].id, data: byUid.docs[0].data() || {} };
}

async function findTravelerByEmail(email) {
  const snapshot = await db
    .collection('travelers')
    .where('email', '==', email)
    .limit(5)
    .get();

  if (snapshot.empty) return null;

  const preferred = snapshot.docs.find((doc) => {
    const data = doc.data() || {};
    return data.role === 'traveler' && data.status === 'active';
  });

  const document = preferred || snapshot.docs[0];
  return { id: document.id, data: document.data() || {} };
}

function travelerUid(profile) {
  return cleanText(profile?.data?.uid || profile?.id, 200);
}

function travelerDisplayName(profile) {
  const data = profile?.data || {};
  return cleanText(
    data.displayName || data.fullName || data.name || data.email || 'Traveler',
    120,
  );
}

function validateTraveler(profile) {
  if (!profile) {
    const error = new Error('Traveler account was not found.');
    error.statusCode = 404;
    throw error;
  }

  if (profile.data.role !== 'traveler') {
    const error = new Error('Only traveler accounts can join a travel group.');
    error.statusCode = 403;
    throw error;
  }

  if (profile.data.status !== 'active') {
    const error = new Error('This traveler account is not active.');
    error.statusCode = 403;
    throw error;
  }
}

async function buildMemberNameUpdates(memberIds, extraProfiles = []) {
  const uniqueIds = [...new Set((memberIds || []).map((id) => cleanText(id, 200)).filter(Boolean))];
  const profiles = new Map();

  for (const profile of extraProfiles) {
    const uid = travelerUid(profile);
    if (uid) profiles.set(uid, profile);
  }

  await Promise.all(
    uniqueIds.map(async (uid) => {
      if (profiles.has(uid)) return;
      const profile = await findTravelerByUid(uid);
      if (profile) profiles.set(uid, profile);
    }),
  );

  const updates = {};
  for (const [uid, profile] of profiles.entries()) {
    const name = travelerDisplayName(profile);
    if (name) updates[`memberNames.${uid}`] = name;
  }
  return updates;
}

async function addNotification({ userId, title, message, type, referenceId }) {
  if (!userId) return;

  await db.collection('notifications').add({
    userId,
    title,
    message,
    type,
    referenceId,
    read: false,
    createdAt: Timestamp.now(),
  });
}

exports.addTravelGroupMemberByEmail = onRequest(
  {
    region: 'asia-southeast1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    setCors(res);

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Only POST requests are supported.' });
      return;
    }

    try {
      const decoded = await authenticateRequest(req);
      const groupId = cleanText(req.body?.groupId, 200);
      const email = cleanText(req.body?.email, 320).toLowerCase();

      if (!groupId || !email || !email.includes('@')) {
        const error = new Error('Provide a valid travel group and Gmail/email address.');
        error.statusCode = 400;
        throw error;
      }

      const groupRef = db.collection('travel_groups').doc(groupId);
      const groupSnapshot = await groupRef.get();

      if (!groupSnapshot.exists) {
        const error = new Error('Travel group was not found.');
        error.statusCode = 404;
        throw error;
      }

      const group = groupSnapshot.data() || {};
      if (group.status !== 'active') {
        const error = new Error('This travel group is not active.');
        error.statusCode = 409;
        throw error;
      }
      if (group.leaderId !== decoded.uid) {
        const error = new Error('Only the group leader can add members by email.');
        error.statusCode = 403;
        throw error;
      }

      const memberProfile = await findTravelerByEmail(email);
      validateTraveler(memberProfile);

      const memberUid = travelerUid(memberProfile);
      const displayName = travelerDisplayName(memberProfile);
      if (!memberUid) {
        const error = new Error('The traveler account has no valid user ID.');
        error.statusCode = 409;
        throw error;
      }

      const currentMemberIds = Array.isArray(group.memberIds) ? group.memberIds : [];
      if (currentMemberIds.includes(memberUid)) {
        const error = new Error(`${displayName} is already a member of this group.`);
        error.statusCode = 409;
        throw error;
      }

      const allIds = [...currentMemberIds, memberUid];
      const nameUpdates = await buildMemberNameUpdates(allIds, [memberProfile]);

      await groupRef.update({
        memberIds: FieldValue.arrayUnion(memberUid),
        ...nameUpdates,
        updatedAt: Timestamp.now(),
      });

      await addNotification({
        userId: memberUid,
        title: 'Added to a travel group',
        message: `You were added to ${cleanText(group.name, 120) || 'a travel group'} by the group leader.`,
        type: 'companion_group',
        referenceId: groupId,
      });

      res.status(200).json({
        success: true,
        memberUid,
        displayName,
        groupId,
      });
    } catch (error) {
      sendError(res, error);
    }
  },
);

exports.joinTravelGroup = onRequest(
  {
    region: 'asia-southeast1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (req, res) => {
    setCors(res);

    if (req.method === 'OPTIONS') {
      res.status(204).send('');
      return;
    }
    if (req.method !== 'POST') {
      res.status(405).json({ error: 'Only POST requests are supported.' });
      return;
    }

    try {
      const decoded = await authenticateRequest(req);
      const code = cleanText(req.body?.code, 20).toUpperCase();

      if (!code) {
        const error = new Error('Please enter a group code.');
        error.statusCode = 400;
        throw error;
      }

      const travelerProfile = await findTravelerByUid(decoded.uid);
      validateTraveler(travelerProfile);
      const displayName = travelerDisplayName(travelerProfile);

      const groupQuery = await db
        .collection('travel_groups')
        .where('code', '==', code)
        .limit(5)
        .get();

      const groupDocument = groupQuery.docs.find(
        (document) => document.data()?.status === 'active',
      );

      if (!groupDocument) {
        const error = new Error('Invalid or inactive group code.');
        error.statusCode = 404;
        throw error;
      }

      const groupRef = groupDocument.ref;
      const group = groupDocument.data() || {};
      const currentMemberIds = Array.isArray(group.memberIds) ? group.memberIds : [];
      const alreadyMember = currentMemberIds.includes(decoded.uid);

      const allIds = alreadyMember
        ? currentMemberIds
        : [...currentMemberIds, decoded.uid];
      const nameUpdates = await buildMemberNameUpdates(allIds, [travelerProfile]);

      await groupRef.update({
        memberIds: FieldValue.arrayUnion(decoded.uid),
        ...nameUpdates,
        updatedAt: Timestamp.now(),
      });

      if (!alreadyMember && group.leaderId && group.leaderId !== decoded.uid) {
        await addNotification({
          userId: group.leaderId,
          title: 'New travel group member',
          message: `${displayName} joined ${cleanText(group.name, 120) || 'your travel group'} using the group code.`,
          type: 'companion_group',
          referenceId: groupDocument.id,
        });
      }

      res.status(200).json({
        success: true,
        alreadyMember,
        groupId: groupDocument.id,
        groupName: cleanText(group.name, 120) || 'Travel Group',
        code,
        displayName,
      });
    } catch (error) {
      sendError(res, error);
    }
  },
);
