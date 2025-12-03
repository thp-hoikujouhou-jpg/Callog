/**
 * Firebase Cloud Functions for Callog
 * 
 * Features:
 * - Send push notifications for incoming voice/video calls
 * - Handle call signaling and routing
 * - Log call history
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send call notification when a new call_notification document is created
 * 
 * Triggered by: /call_notifications/{notificationId}
 */
exports.sendCallNotification = functions.firestore
  .document('call_notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    try {
      const data = snapshot.data();
      const { peerId, peerToken, channelId, callType, callerName, timestamp } = data;

      console.log(`Sending ${callType} notification to ${peerId} from ${callerName}`);

      // Check if peer token exists
      if (!peerToken) {
        console.error('No FCM token for peer:', peerId);
        await snapshot.ref.update({ status: 'failed', error: 'No FCM token' });
        return null;
      }

      // Prepare notification message
      const callTypeText = callType === 'video_call' ? 'ビデオ通話' : '音声通話';
      const message = {
        token: peerToken,
        notification: {
          title: `${callTypeText}着信`,
          body: `${callerName} さんから${callTypeText}がかかってきています`,
        },
        data: {
          type: callType,
          channelId: channelId,
          callerName: callerName,
          timestamp: timestamp || Date.now().toString(),
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
        },
        android: {
          priority: 'high',
          notification: {
            channelId: 'incoming_calls',
            sound: 'call_ringtone',
            priority: 'max',
            visibility: 'public',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'call_ringtone.aiff',
              category: 'CALL_INVITATION',
              'thread-id': channelId,
            },
          },
        },
      };

      // Send the notification
      const response = await admin.messaging().send(message);
      console.log('Successfully sent notification:', response);

      // Update notification status
      await snapshot.ref.update({
        status: 'sent',
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        messageId: response,
      });

      return response;
    } catch (error) {
      console.error('Error sending notification:', error);
      
      // Update notification status
      await snapshot.ref.update({
        status: 'failed',
        error: error.message,
        failedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      return null;
    }
  });

/**
 * Log call history when a call ends
 * 
 * Triggered by: /call_sessions/{sessionId}
 * When: status changes to 'ended'
 */
exports.logCallHistory = functions.firestore
  .document('call_sessions/{sessionId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();

      // Only log when call status changes to 'ended'
      if (before.status !== 'ended' && after.status === 'ended') {
        const { callerId, receiverId, callType, startTime, endTime, channelId } = after;
        
        const duration = endTime && startTime 
          ? (endTime.toMillis() - startTime.toMillis()) / 1000
          : 0;

        console.log(`Logging call history: ${callType} from ${callerId} to ${receiverId}, duration: ${duration}s`);

        // Create call history entry
        const historyData = {
          callerId,
          receiverId,
          callType,
          startTime,
          endTime,
          duration,
          channelId,
          sessionId: context.params.sessionId,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
        };

        // Add to both users' call history
        const batch = admin.firestore().batch();
        
        batch.set(
          admin.firestore().collection('users').doc(callerId).collection('call_history').doc(),
          { ...historyData, direction: 'outgoing' }
        );
        
        batch.set(
          admin.firestore().collection('users').doc(receiverId).collection('call_history').doc(),
          { ...historyData, direction: 'incoming' }
        );

        await batch.commit();
        console.log('Call history logged successfully');
      }

      return null;
    } catch (error) {
      console.error('Error logging call history:', error);
      return null;
    }
  });

/**
 * Clean up old notifications (runs daily)
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 24 hours')
  .onRun(async (context) => {
    try {
      const oneDayAgo = new Date();
      oneDayAgo.setDate(oneDayAgo.getDate() - 1);

      const snapshot = await admin.firestore()
        .collection('call_notifications')
        .where('timestamp', '<', oneDayAgo)
        .limit(500)
        .get();

      console.log(`Cleaning up ${snapshot.size} old notifications`);

      const batch = admin.firestore().batch();
      snapshot.docs.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log('Old notifications cleaned up successfully');
      
      return null;
    } catch (error) {
      console.error('Error cleaning up notifications:', error);
      return null;
    }
  });

/**
 * Update user's online status
 * 
 * Triggered by: /users/{userId}/sessions/{sessionId}
 */
exports.updateOnlineStatus = functions.firestore
  .document('users/{userId}/sessions/{sessionId}')
  .onWrite(async (change, context) => {
    try {
      const userId = context.params.userId;
      
      // Check if user has any active sessions
      const sessionsSnapshot = await admin.firestore()
        .collection('users').doc(userId).collection('sessions')
        .where('active', '==', true)
        .limit(1)
        .get();

      const isOnline = !sessionsSnapshot.empty;

      // Update user's online status
      await admin.firestore().collection('users').doc(userId).update({
        isOnline,
        lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      });

      console.log(`Updated online status for ${userId}: ${isOnline}`);
      return null;
    } catch (error) {
      console.error('Error updating online status:', error);
      return null;
    }
  });
