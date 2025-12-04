/**
 * Callog - Cloud Functions for Push Notifications & Agora Token Generation
 * 
 * Features:
 * - Send push notifications for incoming voice/video calls
 * - Generate Agora RTC tokens for secure calls
 * - Automatic FCM message delivery
 * - Call notification cleanup after 30 seconds
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {RtcTokenBuilder, RtcRole} = require('agora-token');

admin.initializeApp();

// Agora Configuration
const AGORA_APP_ID = 'd1a8161eb70448d89eea1722bc169c92';
// TODO: Add your Agora App Certificate from https://console.agora.io/
// Required for token generation in production
const AGORA_APP_CERTIFICATE = process.env.AGORA_APP_CERTIFICATE || '';

/**
 * Send Call Notification (Firestore Trigger - LEGACY, not used)
 * This function is kept for backwards compatibility but is not actively used.
 * The app uses sendPushNotification (callable function) instead.
 */
// Commented out to avoid deployment issues
/*
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
*/

/**
 * Generate Agora RTC Token (Callable Function)
 * Called from Flutter app to get a secure token for joining voice/video calls
 * 
 * Parameters:
 * - channelName: The name of the channel to join
 * - uid: User ID (0 for auto-assignment)
 * - role: 'publisher' or 'audience' (default: 'publisher')
 * 
 * Returns:
 * - token: The generated RTC token
 * - appId: Agora App ID
 * - channelName: The channel name
 * - uid: The user ID
 */
exports.generateAgoraToken = functions.https.onCall(async (data, context) => {
  try {
    console.log('🎫 Generating Agora token:', data);
    
    // Validate input
    const channelName = data.channelName;
    const uid = data.uid || 0;
    const role = data.role === 'audience' ? RtcRole.AUDIENCE : RtcRole.PUBLISHER;
    
    if (!channelName) {
      throw new Error('Channel name is required');
    }
    
    // Check if App Certificate is configured
    if (!AGORA_APP_CERTIFICATE) {
      console.warn('⚠️ App Certificate not configured - returning empty token');
      console.warn('⚠️ For production, set AGORA_APP_CERTIFICATE environment variable');
      return {
        token: null,
        appId: AGORA_APP_ID,
        channelName: channelName,
        uid: uid,
        message: 'Token generation disabled - App Certificate not configured',
      };
    }
    
    // Token expiration time (24 hours from now)
    const expirationTimeInSeconds = Math.floor(Date.now() / 1000) + 86400;
    
    // Generate token
    const token = RtcTokenBuilder.buildTokenWithUid(
      AGORA_APP_ID,
      AGORA_APP_CERTIFICATE,
      channelName,
      uid,
      role,
      expirationTimeInSeconds
    );
    
    console.log('✅ Token generated successfully');
    
    return {
      token: token,
      appId: AGORA_APP_ID,
      channelName: channelName,
      uid: uid,
      expiresAt: expirationTimeInSeconds,
    };
    
  } catch (error) {
    console.error('❌ Error generating Agora token:', error);
    throw new Error('Failed to generate Agora token: ' + error.message);
  }
});

/**
 * Send Push Notification (Callable Function)
 * Called from Flutter app to send push notifications to peers
 * 
 * Parameters:
 * - peerId: The user ID to send notification to
 * - channelId: The call channel ID
 * - callType: 'voice_call' or 'video_call'
 * - callerName: The caller's display name
 * 
 * Returns:
 * - success: Boolean indicating if notification was sent
 * - messageId: FCM message ID
 */
exports.sendPushNotification = functions.https.onCall(async (data, context) => {
  try {
    console.log('📲 Sending push notification:', data);
    
    // Validate authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    // Validate input
    const {peerId, channelId, callType, callerName} = data;
    
    if (!peerId || !channelId || !callType || !callerName) {
      throw new Error('Missing required parameters');
    }
    
    // Get peer's FCM token
    const peerDoc = await admin.firestore()
      .collection('users')
      .doc(peerId)
      .get();
    
    if (!peerDoc.exists) {
      throw new Error('Peer user not found');
    }
    
    const peerToken = peerDoc.data().fcmToken;
    
    if (!peerToken) {
      throw new Error('Peer has no FCM token');
    }
    
    // Determine call type display name
    const callTypeDisplay = callType === 'voice_call' ? '音声通話' : 'ビデオ通話';
    
    // Create FCM message
    const message = {
      notification: {
        title: `着信: ${callTypeDisplay}`,
        body: `${callerName}から通話があります`,
      },
      data: {
        callType: callType,
        channelId: channelId,
        callerName: callerName,
        callerId: context.auth.uid,
        timestamp: Date.now().toString(),
      },
      token: peerToken,
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
            contentAvailable: true,
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
    console.log('✅ Push notification sent successfully:', response);
    
    // Store notification record
    await admin.firestore()
      .collection('call_notifications')
      .add({
        callerId: context.auth.uid,
        peerId: peerId,
        channelId: channelId,
        callType: callType,
        callerName: callerName,
        status: 'sent',
        fcmResponse: response,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    
    return {
      success: true,
      messageId: response,
    };
    
  } catch (error) {
    console.error('❌ Error sending push notification:', error);
    throw new Error('Failed to send push notification: ' + error.message);
  }
});

/**
 * Clean up old notifications
 * Runs every hour to delete notifications older than 1 hour
 */
exports.cleanupOldNotifications = functions.pubsub.schedule('every 1 hours').onRun(async (context) => {
    const cutoffTime = new Date(Date.now() - 60 * 60 * 1000); // 1 hour ago
    
    const snapshot = await admin.firestore()
      .collection('call_notifications')
      .where('createdAt', '<', cutoffTime)
      .get();
    
    const batch = admin.firestore().batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    console.log(`🧹 Cleaned up ${snapshot.size} old notifications`);
    
    return null;
  });
