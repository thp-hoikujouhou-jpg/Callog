/**
 * Callog - Cloud Functions for Push Notifications
 * 
 * Features:
 * - Send push notifications for incoming voice/video calls
 * - Automatic FCM message delivery
 * - Call notification cleanup after 30 seconds
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

admin.initializeApp();

/**
 * Send Call Notification
 * Triggered when a new document is created in call_notifications collection
 */
exports.sendCallNotification = functions.firestore
  .document('call_notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data();
    const notificationId = context.params.notificationId;
    
    console.log('📲 New call notification:', data);
    
    try {
      // Validate required fields
      if (!data.peerToken || !data.callType || !data.callerName) {
        console.error('❌ Missing required fields:', data);
        return null;
      }
      
      // Determine call type display name
      const callTypeDisplay = data.callType === 'voice_call' ? '音声通話' : 'ビデオ通話';
      
      // Create FCM message
      const message = {
        notification: {
          title: `着信: ${callTypeDisplay}`,
          body: `${data.callerName}から通話があります`,
        },
        data: {
          callType: data.callType,
          channelId: data.channelId || '',
          callerName: data.callerName,
          peerId: data.peerId || '',
          notificationId: notificationId,
        },
        token: data.peerToken,
        android: {
          priority: 'high',
          notification: {
            channelId: 'call_notifications',
            priority: 'high',
            sound: 'default',
            defaultSound: true,
            defaultVibrateTimings: true,
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
        webpush: {
          notification: {
            icon: '/icons/Icon-192.png',
            badge: '/icons/Icon-192.png',
            vibrate: [200, 100, 200],
            requireInteraction: true,
            actions: [
              {
                action: 'answer',
                title: '応答',
              },
              {
                action: 'decline',
                title: '拒否',
              },
            ],
          },
        },
      };
      
      // Send FCM message
      const response = await admin.messaging().send(message);
      console.log('✅ Notification sent successfully:', response);
      
      // Update notification status
      await admin.firestore()
        .collection('call_notifications')
        .doc(notificationId)
        .update({
          status: 'sent',
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          fcmResponse: response,
        });
      
      // Schedule cleanup after 30 seconds (unanswered calls)
      setTimeout(async () => {
        try {
          const doc = await admin.firestore()
            .collection('call_notifications')
            .doc(notificationId)
            .get();
          
          if (doc.exists && doc.data().status === 'sent') {
            await admin.firestore()
              .collection('call_notifications')
              .doc(notificationId)
              .update({
                status: 'expired',
                expiredAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            console.log('⏰ Notification expired:', notificationId);
          }
        } catch (error) {
          console.error('❌ Cleanup error:', error);
        }
      }, 30000); // 30 seconds
      
      return response;
      
    } catch (error) {
      console.error('❌ Error sending notification:', error);
      
      // Update notification status to failed
      await admin.firestore()
        .collection('call_notifications')
        .doc(notificationId)
        .update({
          status: 'failed',
          error: error.message,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      
      throw error;
    }
  });

/**
 * Clean up old notifications
 * Runs every hour to delete notifications older than 1 hour
 */
exports.cleanupOldNotifications = functions.pubsub
  .schedule('every 1 hours')
  .onRun(async (context) => {
    const cutoffTime = new Date(Date.now() - 60 * 60 * 1000); // 1 hour ago
    
    const snapshot = await admin.firestore()
      .collection('call_notifications')
      .where('timestamp', '<', cutoffTime)
      .get();
    
    const batch = admin.firestore().batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`🧹 Cleaned up ${snapshot.size} old notifications`);
    
    return null;
  });
