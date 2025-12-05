const { Firestore } = require('@google-cloud/firestore');

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');
  
  // Handle OPTIONS
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    // Get request data
    const data = req.body?.data || req.body;
    const { peerId, channelId, callType, callerName, callerId } = data;
    
    // Validate required fields
    if (!peerId || !channelId || !callType || !callerName) {
      return res.status(400).json({
        error: 'Missing required fields: peerId, channelId, callType, callerName'
      });
    }

    // Get environment variables
    const projectId = process.env.FIREBASE_PROJECT_ID;
    const webApiKey = process.env.FIREBASE_WEB_API_KEY;
    
    if (!projectId) {
      return res.status(500).json({
        error: 'FIREBASE_PROJECT_ID not configured'
      });
    }

    // Initialize Firestore (no credentials needed for Vercel environment)
    // Firestore will use Application Default Credentials from Vercel
    const firestore = new Firestore({
      projectId: projectId,
      // Allow anonymous access for read operations via Firestore Security Rules
      // For write operations, the client SDK will use Firebase Auth tokens
      keyFilename: undefined, // Explicitly set to undefined to use default credentials
    });

    // Get peer's FCM token from Firestore
    const userDoc = await firestore.collection('users').doc(peerId).get();
    
    if (!userDoc.exists) {
      console.log(`⚠️ User ${peerId} not found in Firestore`);
      return res.status(404).json({
        error: 'Peer user not found in Firestore'
      });
    }

    const userData = userDoc.data();
    const fcmToken = userData?.fcmToken;

    if (!fcmToken) {
      console.log(`⚠️ User ${peerId} has no FCM token`);
      return res.status(200).json({
        data: {
          success: false,
          message: 'Peer has no FCM token registered',
          note: 'User may need to re-login or enable notifications'
        }
      });
    }

    console.log(`📤 Sending FCM notification to: ${fcmToken.substring(0, 20)}...`);

    // Create call notification in Firestore (for fallback)
    const callNotification = {
      peerId: peerId,
      callerId: callerId || 'unknown',
      callerName: callerName,
      channelId: channelId,
      callType: callType,
      status: 'ringing',
      timestamp: new Date().toISOString(),
      createdAt: Date.now(),
    };

    const notificationRef = await firestore
      .collection('call_notifications')
      .add(callNotification);

    console.log(`✅ Firestore notification created: ${notificationRef.id}`);

    // If no Web API Key, only use Firestore
    if (!webApiKey) {
      console.log('⚠️ FIREBASE_WEB_API_KEY not configured - using Firestore only');
      return res.status(200).json({
        data: {
          success: true,
          notificationId: notificationRef.id,
          message: 'Firestore notification created (FCM disabled)',
          note: 'Set FIREBASE_WEB_API_KEY to enable FCM browser notifications'
        }
      });
    }

    // Send FCM notification using Web API Key
    try {
      const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;
      
      // Get OAuth 2.0 access token using Web API Key
      // For Web API Key, we use the legacy FCM endpoint instead
      const legacyFcmUrl = 'https://fcm.googleapis.com/fcm/send';
      
      const fcmPayload = {
        to: fcmToken,
        notification: {
          title: `${callType === 'voice_call' ? '音声' : 'ビデオ'}通話着信`,
          body: `${callerName}さんから${callType === 'voice_call' ? '音声' : 'ビデオ'}通話がかかってきています`,
          icon: '/icon.png',
          badge: '/badge.png',
          tag: `call_${channelId}`,
          requireInteraction: true,
          click_action: `https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai`,
        },
        data: {
          type: callType,
          channelId: channelId,
          callerName: callerName,
          callerId: callerId || 'unknown',
          timestamp: Date.now().toString(),
          notificationId: notificationRef.id,
        },
        priority: 'high',
        time_to_live: 60,
      };

      const fcmResponse = await fetch(legacyFcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `key=${webApiKey}`,
        },
        body: JSON.stringify(fcmPayload),
      });

      const fcmResult = await fcmResponse.json();

      if (fcmResult.success === 1) {
        console.log(`✅ FCM notification sent successfully`);
        return res.status(200).json({
          data: {
            success: true,
            messageId: fcmResult.results?.[0]?.message_id || null,
            notificationId: notificationRef.id,
            message: 'Push notification sent via FCM',
            method: 'FCM + Firestore'
          }
        });
      } else {
        console.error('❌ FCM notification failed:', fcmResult);
        // FCM failed, but Firestore notification is created
        return res.status(200).json({
          data: {
            success: true,
            notificationId: notificationRef.id,
            message: 'Firestore notification created (FCM failed)',
            error: fcmResult.results?.[0]?.error || 'Unknown FCM error',
            method: 'Firestore only'
          }
        });
      }

    } catch (fcmError) {
      console.error('❌ FCM error:', fcmError);
      // FCM error, but Firestore notification is created
      return res.status(200).json({
        data: {
          success: true,
          notificationId: notificationRef.id,
          message: 'Firestore notification created (FCM error)',
          error: fcmError.message,
          method: 'Firestore only'
        }
      });
    }

  } catch (error) {
    console.error('❌ Error:', error);
    return res.status(500).json({
      error: 'Failed to send notification',
      message: error.message
    });
  }
};
