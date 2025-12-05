// 🔥 FCM Push Notification API with Firebase Admin SDK
// Uses Service Account Key from environment variable

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
if (admin.apps.length === 0) {
  try {
    const serviceAccount = JSON.parse(
      process.env.FIREBASE_SERVICE_ACCOUNT || '{}'
    );
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: process.env.FIREBASE_PROJECT_ID || 'callog-30758'
    });
    
    console.log('✅ Firebase Admin SDK initialized successfully');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error);
  }
}

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
    // Verify Firebase Admin SDK is initialized
    if (admin.apps.length === 0) {
      return res.status(500).json({
        error: 'Firebase Admin SDK not initialized',
        message: 'FIREBASE_SERVICE_ACCOUNT environment variable may be missing or invalid'
      });
    }

    // Get request data
    const data = req.body?.data || req.body;
    const { fcmToken, callType, callerName, channelId, callerId, peerId } = data;
    
    // Validate required fields
    if (!fcmToken) {
      return res.status(400).json({
        error: 'Missing required field: fcmToken'
      });
    }

    if (!callType || !callerName || !channelId) {
      return res.status(400).json({
        error: 'Missing required fields: callType, callerName, channelId'
      });
    }

    console.log(`📤 Sending FCM notification via Firebase Admin SDK`);
    console.log(`   FCM Token: ${fcmToken.substring(0, 20)}...`);
    console.log(`   Call type: ${callType}, Caller: ${callerName}`);

    // Prepare FCM message
    const message = {
      token: fcmToken,
      notification: {
        title: `🔔 ${callType === 'voice_call' ? '音声' : 'ビデオ'}通話着信`,
        body: `${callerName}さんから${callType === 'voice_call' ? '音声' : 'ビデオ'}通話がかかってきています`,
      },
      data: {
        type: callType,
        channelId: channelId,
        callerName: callerName,
        callerId: callerId || 'unknown',
        peerId: peerId || 'unknown',
        timestamp: Date.now().toString(),
      },
      webpush: {
        fcmOptions: {
          link: 'https://5060-i9jon7di5fl8a64rlbe9u-18e660f9.sandbox.novita.ai',
        },
        notification: {
          icon: '/icon.png',
          badge: '/badge.png',
          tag: `call_${channelId}`,
          requireInteraction: true,
        },
      },
      // High priority for immediate delivery
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
      },
    };

    // Send FCM notification using Firebase Admin SDK
    const response = await admin.messaging().send(message);
    
    console.log(`✅ FCM notification sent successfully`);
    console.log(`   Message ID: ${response}`);

    return res.status(200).json({
      data: {
        success: true,
        messageId: response,
        message: 'Push notification sent successfully via Firebase Admin SDK',
        method: 'FCM HTTP v1 API',
        timestamp: Date.now()
      }
    });

  } catch (error) {
    console.error('❌ Error sending FCM notification:', error);
    
    // Detailed error handling
    let errorMessage = error.message;
    let errorCode = error.code;
    
    if (errorCode === 'messaging/invalid-registration-token' || 
        errorCode === 'messaging/registration-token-not-registered') {
      errorMessage = 'FCM token is invalid or expired. User needs to re-login.';
    } else if (errorCode === 'messaging/mismatched-credential') {
      errorMessage = 'Firebase Service Account credentials are invalid.';
    }
    
    return res.status(500).json({
      error: 'Failed to send notification',
      message: errorMessage,
      code: errorCode,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};
