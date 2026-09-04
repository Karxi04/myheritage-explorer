'use strict';

const {
  initializeApp,
  applicationDefault,
} = require('firebase-admin/app');

const {
  getFirestore,
  FieldValue,
  Timestamp,
} = require('firebase-admin/firestore');

const {
  getMessaging,
} = require('firebase-admin/messaging');

initializeApp({
  credential: applicationDefault(),
  projectId: 'myheritage-4fe2f',
});

const db = getFirestore();

const processing = new Set();

function text(
  value,
  maxLength = 500,
) {
  return String(value ?? '')
    .trim()
    .slice(0, maxLength);
}

function channelForType(type) {
  if (type === 'sos') {
    return 'sos_heads_up_v6';
  }

  if (
    type === 'group_message' ||
    type === 'private_message' ||
    type === 'private_chat' ||
    type === 'private_location_request' ||
    type === 'private_location_shared'
  ) {
    return 'chat_heads_up_v6';
  }

  return 'general_heads_up_v6';
}

async function loadTokens(
  userId,
) {
  const snapshot =
    await db
      .collection('push_tokens')
      .where(
        'userId',
        '==',
        userId,
      )
      .get();

  const tokens = new Map();

  for (const document
    of snapshot.docs) {
    const data =
      document.data();

    if (data.enabled === false) {
      continue;
    }

    const token =
      text(
        data.token,
        4096,
      );

    if (!token) {
      continue;
    }

    tokens.set(
      token,
      document.ref,
    );
  }

  return tokens;
}

async function claimNotification(
  document,
  allowMissingStatus,
) {
  return db.runTransaction(
    async transaction => {
      const current =
        await transaction.get(
          document.ref,
        );

      if (!current.exists) {
        return null;
      }

      const data =
        current.data() || {};

      const status =
        text(
          data.pushStatus,
          30,
        );

      if (
        status === 'sent' ||
        status === 'processing'
      ) {
        return null;
      }

      if (
        status !== 'pending' &&
        !(
          allowMissingStatus &&
          !status
        )
      ) {
        return null;
      }

      transaction.update(
        document.ref,
        {
          pushStatus:
            'processing',

          pushAttempts:
            FieldValue.increment(1),

          pushStartedAt:
            FieldValue.serverTimestamp(),
        },
      );

      return data;
    },
  );
}

async function sendNotification(
  document,
  allowMissingStatus = false,
) {
  if (processing.has(document.id)) {
    return;
  }

  processing.add(document.id);

  try {
    const data =
      await claimNotification(
        document,
        allowMissingStatus,
      );

    if (!data) {
      return;
    }

    const userId =
      text(
        data.userId,
        200,
      );

    if (!userId) {
      throw new Error(
        'Notification does not contain userId.',
      );
    }

    const tokenMap =
      await loadTokens(
        userId,
      );

    const tokens =
      [...tokenMap.keys()];

    if (tokens.length === 0) {
      throw new Error(
        `No FCM token registered for ${userId}.`,
      );
    }

    const type =
      text(
        data.type || 'general',
        100,
      ).toLowerCase();

    const title =
      text(
        data.title ||
          'MyHeritage Explorer',
        150,
      );

    const body =
      text(
        data.message ||
          'You have a new notification.',
        500,
      );

    console.log('');
    console.log(
      `[SEND] ${type}`,
    );
    console.log(
      `User: ${userId}`,
    );
    console.log(
      `Title: ${title}`,
    );
    console.log(
      `Body: ${body}`,
    );

    const response =
      await getMessaging()
        .sendEachForMulticast({
          tokens,

          notification: {
            title,
            body,
          },

          data: {
            type,

            notificationId:
              document.id,

            referenceId:
              text(
                data.referenceId,
                300,
              ),

            groupId:
              text(
                data.groupId,
                300,
              ),

            chatId:
              text(
                data.chatId,
                500,
              ),
          },

          android: {
            priority:
              'high',

            notification: {
              channelId:
                channelForType(type),

              priority:
                type === 'sos'
                  ? 'max'
                  : 'high',

              visibility:
                'public',

              sound:
                'default',

              defaultSound:
                true,

              defaultVibrateTimings:
                true,
            },
          },
        });

    const invalidCodes =
      new Set([
        'messaging/registration-token-not-registered',
        'messaging/invalid-registration-token',
      ]);

    const cleanup = [];

    response.responses.forEach(
      (
        result,
        index,
      ) => {
        if (result.success) {
          return;
        }

        const code =
          result.error?.code ||
          '';

        console.error(
          `FCM failure: ${code}`,
        );

        if (
          invalidCodes.has(code)
        ) {
          const token =
            tokens[index];

          const reference =
            tokenMap.get(token);

          if (reference) {
            cleanup.push(
              reference.delete(),
            );
          }
        }
      },
    );

    await Promise.all(
      cleanup,
    );

    await document.ref.update({
      pushStatus:
        'sent',

      pushSentAt:
        FieldValue.serverTimestamp(),

      pushSuccessCount:
        response.successCount,

      pushFailureCount:
        response.failureCount,

      pushLastError:
        FieldValue.delete(),
    });

    console.log(
      `Success: ${response.successCount}`,
    );

    console.log(
      `Failed: ${response.failureCount}`,
    );
  } catch (error) {
    console.error(
      `[PUSH FAILED] ${document.id}`,
    );

    console.error(
      error.message || error,
    );

    try {
      await document.ref.update({
        pushStatus:
          'failed',

        pushFailedAt:
          FieldValue.serverTimestamp(),

        pushLastError:
          text(
            error.message || error,
            1000,
          ),
      });
    } catch (_) {}
  } finally {
    processing.delete(
      document.id,
    );
  }
}

// ================================================================
// 1. PENDING NOTIFICATIONS
//
// Handles:
// - Group chat
// - Private chat
// - SOS
// - AppServices.notify()
// and also catches notifications created while the server was off.
// ================================================================

db
  .collection('notifications')
  .where(
    'pushStatus',
    '==',
    'pending',
  )
  .onSnapshot(
    snapshot => {
      for (
        const change
        of snapshot.docChanges()
      ) {
        if (
          change.type !==
          'added'
        ) {
          continue;
        }

        sendNotification(
          change.doc,
          false,
        );
      }
    },
    error => {
      console.error(
        'Pending listener error:',
        error,
      );
    },
  );

// ================================================================
// 2. LIVE NOTIFICATIONS WITHOUT pushStatus
//
// Some existing backend code, such as the already-deployed
// companion membership functions, creates notification documents
// without pushStatus.
//
// We can support them without redeploying Cloud Functions.
// ================================================================

let initialLiveSnapshot = true;

db
  .collection('notifications')
  .onSnapshot(
    snapshot => {
      if (initialLiveSnapshot) {
        initialLiveSnapshot =
          false;

        return;
      }

      for (
        const change
        of snapshot.docChanges()
      ) {
        if (
          change.type !==
          'added'
        ) {
          continue;
        }

        const data =
          change.doc.data();

        if (data.pushStatus) {
          continue;
        }

        sendNotification(
          change.doc,
          true,
        );
      }
    },
    error => {
      console.error(
        'Live listener error:',
        error,
      );
    },
  );

// ================================================================
// 3. CATCH RECENT UNTRACKED NOTIFICATIONS
//
// Useful if the local server was restarted.
// ================================================================

async function catchUpRecentNotifications() {
  const cutoff =
    Timestamp.fromMillis(
      Date.now() -
        30 * 60 * 1000,
    );

  const snapshot =
    await db
      .collection('notifications')
      .where(
        'createdAt',
        '>=',
        cutoff,
      )
      .get();

  for (const document
    of snapshot.docs) {
    if (
      !document.data()
        .pushStatus
    ) {
      await sendNotification(
        document,
        true,
      );
    }
  }
}

catchUpRecentNotifications()
  .catch(
    error => {
      console.error(
        'Catch-up error:',
        error,
      );
    },
  );

console.log('');
console.log(
  '==========================================',
);
console.log(
  'MyHeritage Notification Server',
);
console.log(
  'Firebase project: myheritage-4fe2f',
);
console.log(
  'Listening for notifications...',
);
console.log(
  '==========================================',
);