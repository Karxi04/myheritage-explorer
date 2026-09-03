'use strict';

const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const logger = require('firebase-functions/logger');
const { getApps, initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();
const REGION = 'asia-southeast1';

function cleanText(value, maxLength = 160) {
  return String(value ?? '').trim().slice(0, maxLength);
}

function messagePreview(value) {
  const text = cleanText(value, 180);
  return text.length <= 120 ? text : `${text.slice(0, 117)}...`;
}

async function commitNotificationDocuments(documents) {
  // Firestore write batches support up to 500 writes.
  // Keep some room in every batch.
  const chunkSize = 450;

  for (let start = 0; start < documents.length; start += chunkSize) {
    const batch = db.batch();

    for (const document of documents.slice(start, start + chunkSize)) {
      const ref = db.collection('notifications').doc();
      batch.set(ref, document);
    }

    await batch.commit();
  }
}

exports.onGroupMessageCreated = onDocumentCreated(
  {
    document: 'travel_groups/{groupId}/messages/{messageId}',
    region: REGION,
    retry: false,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const message = snapshot.data() || {};
    const groupId = event.params.groupId;
    const messageId = event.params.messageId;

    const senderId = cleanText(message.senderId, 160);
    const senderName = cleanText(message.senderName || 'Group member', 100);
    const text = cleanText(message.text, 2000);

    if (!senderId || !text) {
      logger.warn('Skipping invalid group message notification', {
        groupId,
        messageId,
      });
      return;
    }

    const groupSnapshot = await db
      .collection('travel_groups')
      .doc(groupId)
      .get();

    if (!groupSnapshot.exists) {
      logger.warn('Travel group not found for message notification', {
        groupId,
        messageId,
      });
      return;
    }

    const group = groupSnapshot.data() || {};
    const groupName = cleanText(group.name || 'Travel Group', 120);
    const memberIds = Array.isArray(group.memberIds)
      ? [...new Set(group.memberIds.map((id) => cleanText(id, 160)).filter(Boolean))]
      : [];

    // Never notify the sender about their own message.
    const recipientIds = memberIds.filter((uid) => uid !== senderId);

    if (recipientIds.length === 0) return;

    const createdAt = FieldValue.serverTimestamp();
    const preview = messagePreview(text);

    const notifications = recipientIds.map((userId) => ({
      userId,
      title: `New message in ${groupName}`,
      message: `${senderName}: ${preview}`,
      type: 'group_message',
      referenceId: groupId,
      groupId,
      groupName,
      messageId,
      senderId,
      senderName,
      read: false,
      createdAt,
    }));

    await commitNotificationDocuments(notifications);

    logger.info('Group message notifications created', {
      groupId,
      messageId,
      recipientCount: recipientIds.length,
    });
  },
);

exports.onPrivateMessageCreated = onDocumentCreated(
  {
    document: 'private_chats/{chatId}/messages/{messageId}',
    region: REGION,
    retry: false,
  },
  async (event) => {
    const snapshot = event.data;
    if (!snapshot) return;

    const message = snapshot.data() || {};
    const chatId = event.params.chatId;
    const messageId = event.params.messageId;

    // Location request / response / shared-location messages already have
    // their own purpose-specific notification flow in the Flutter code.
    // This trigger handles normal private text messages only.
    const type = cleanText(message.type || 'text', 50);
    if (type !== 'text') return;

    const senderId = cleanText(message.senderId, 160);
    const senderName = cleanText(message.senderName || 'Traveler', 100);
    const text = cleanText(message.text, 2000);

    if (!senderId || !text) {
      logger.warn('Skipping invalid private message notification', {
        chatId,
        messageId,
      });
      return;
    }

    let receiverId = cleanText(message.receiverId, 160);

    // Backward-compatible fallback if a legacy message has no receiverId.
    if (!receiverId) {
      const chatSnapshot = await db
        .collection('private_chats')
        .doc(chatId)
        .get();

      const participants = Array.isArray(chatSnapshot.data()?.participantIds)
        ? chatSnapshot.data().participantIds
        : [];

      receiverId = cleanText(
        participants.find((id) => String(id) !== senderId),
        160,
      );
    }

    if (!receiverId || receiverId === senderId) return;

    await db.collection('notifications').add({
      userId: receiverId,
      title: `New message from ${senderName}`,
      message: messagePreview(text),
      type: 'private_message',
      referenceId: chatId,
      chatId,
      messageId,
      senderId,
      senderName,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });

    logger.info('Private message notification created', {
      chatId,
      messageId,
      receiverId,
    });
  },
);
