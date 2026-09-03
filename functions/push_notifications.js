'use strict';

const {
  onDocumentCreated,
} = require('firebase-functions/v2/firestore');

const logger =
  require('firebase-functions/logger');

const {
  getApps,
  initializeApp,
} = require('firebase-admin/app');

const {
  getFirestore,
  FieldValue,
} = require('firebase-admin/firestore');

const {
  getMessaging,
} = require('firebase-admin/messaging');

if (getApps().length === 0) {
  initializeApp();
}

const db = getFirestore();

const REGION = 'asia-southeast1';

const PUSH_TYPES = new Set([
  'group_message',
  'private_message',
  'private_chat',
  'private_location_request',
  'private_location_shared',
  'sos',
]);

function cleanText(
  value,
  maxLength = 180,
) {
  return String(value ?? '')
    .trim()
    .slice(0, maxLength);
}

// ============================================================
// SOS -> IN-APP NOTIFICATION
// ============================================================

exports.onSosAlertCreated =
    onDocumentCreated(
  {
    document:
        'sos_alerts/{alertId}',
    region: REGION,
    retry: false,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) return;

    const alert =
        snapshot.data() || {};

    const alertId =
        event.params.alertId;

    const leaderId =
        cleanText(
          alert.leaderId,
          160,
        );

    const senderId =
        cleanText(
          alert.senderId,
          160,
        );

    const senderName =
        cleanText(
          alert.senderName ||
              'A companion',
          100,
        );

    const groupId =
        cleanText(
          alert.groupId,
          160,
        );

    const groupName =
        cleanText(
          alert.groupName ||
              'Travel Group',
          120,
        );

    if (!leaderId ||
        leaderId === senderId) {
      logger.warn(
        'SOS has no valid group leader.',
        {
          alertId,
          groupId,
        },
      );

      return;
    }

    await db
        .collection('notifications')
        .add({
      userId: leaderId,

      title:
          `🚨 SOS Alert from ${senderName}`,

      message:
          `${senderName} triggered an emergency SOS in ${groupName}. Open the app immediately to view their location.`,

      type: 'sos',

      referenceId: alertId,

      alertId,
      groupId,
      senderId,
      senderName,

      read: false,

      createdAt:
          FieldValue.serverTimestamp(),
    });

    logger.info(
      'SOS notification created.',
      {
        alertId,
        leaderId,
      },
    );
  },
);

// ============================================================
// IN-APP NOTIFICATION -> FCM PHONE PUSH
// ============================================================

exports.onNotificationCreated =
    onDocumentCreated(
  {
    document:
        'notifications/{notificationId}',
    region: REGION,
    retry: false,
  },
  async (event) => {
    const snapshot = event.data;

    if (!snapshot) return;

    const notification =
        snapshot.data() || {};

    const notificationId =
        event.params.notificationId;

    const userId =
        cleanText(
          notification.userId,
          160,
        );

    const type =
        cleanText(
          notification.type ||
              'general',
          60,
        );

    if (!userId ||
        !PUSH_TYPES.has(type)) {
      return;
    }

    const tokenSnapshot =
        await db
            .collection('push_tokens')
            .where(
              'userId',
              '==',
              userId,
            )
            .get();

    if (tokenSnapshot.empty) {
      logger.info(
        'No phone token registered.',
        {
          userId,
          notificationId,
        },
      );

      return;
    }

    const tokenDocuments = [];

    for (const document of
        tokenSnapshot.docs) {
      const token =
          cleanText(
            document.data().token,
            4096,
          );

      if (!token) continue;

      tokenDocuments.push({
        document,
        token,
      });
    }

    if (tokenDocuments.length === 0) {
      return;
    }

    const title =
        cleanText(
          notification.title ||
              'MyHeritage Explorer',
          150,
        );

    const body =
        cleanText(
          notification.message ||
              'You have a new update.',
          300,
        );

    const isSos =
        type === 'sos';

    const referenceId =
        cleanText(
          notification.referenceId ||
              '',
          160,
        );

    const groupId =
        cleanText(
          notification.groupId ||
              '',
          160,
        );

    const chatId =
        cleanText(
          notification.chatId ||
              '',
          160,
        );

    const response =
        await getMessaging()
            .sendEachForMulticast({
      tokens:
          tokenDocuments.map(
        (item) => item.token,
      ),

      notification: {
        title,
        body,
      },

      data: {
        type,
        referenceId,
        groupId,
        chatId,
        notificationId,
        title,
        message: body,
      },

      android: {
        priority: 'high',

        notification: {
          channelId:
              isSos
                  ? 'sos_alerts'
                  : 'chat_notifications',

          sound: 'default',

          priority:
              isSos
                  ? 'max'
                  : 'high',

          defaultVibrateTimings:
              true,

          visibility: 'public',
        },
      },

      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1,
          },
        },
      },
    });

    // Remove invalid/expired device tokens.
    const invalidDocuments = [];

    response.responses
        .forEach(
      (
        result,
        index,
      ) {
        if (result.success) {
          return;
        }

        const code =
            result.error?.code ||
            '';

        if (
          code ===
              'messaging/registration-token-not-registered' ||
          code ===
              'messaging/invalid-registration-token'
        ) {
          invalidDocuments.push(
            tokenDocuments[index]
                .document
                .ref,
          );
        }
      },
    );

    if (invalidDocuments.length > 0) {
      const batch =
          db.batch();

      for (const ref of
          invalidDocuments) {
        batch.delete(ref);
      }

      await batch.commit();
    }

    logger.info(
      'Phone notification processed.',
      {
        notificationId,
        userId,
        type,
        successCount:
            response.successCount,
        failureCount:
            response.failureCount,
      },
    );
  },
);