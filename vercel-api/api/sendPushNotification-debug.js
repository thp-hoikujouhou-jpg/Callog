// 🔍 Debug version of sendPushNotification API
// Provides detailed error messages for troubleshooting

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK with detailed logging
if (admin.apps.length === 0) {
  try {
    const serviceAccountRaw = process.env.FIREBASE_SERVICE_ACCOUNT || '{}';
    console.log('🔍 FIREBASE_SERVICE_ACCOUNT length:', serviceAccountRaw.length);
    console.log('🔍 First 50 chars:', serviceAccountRaw.substring(0, 50));
    
    const serviceAccount = JSON.parse(serviceAccountRaw);
    console.log('🔍 Parsed service account project_id:', serviceAccount.project_id);
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: process.env.FIREBASE_PROJECT_ID || 'callog-30758'
    });
    
    console.log('✅ Firebase Admin SDK initialized successfully');
  } catch (error) {
    console.error('❌ Failed to initialize Firebase Admin SDK:', error.message);
    console.error('Stack:', error.stack);
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

  // Debug info
  console.log('🔍 Request method:', req.method);
  console.log('🔍 Request body:', JSON.stringify(req.body));
  console.log('🔍 Firebase Admin apps count:', admin.apps.length);
  console.log('🔍 Environment variables present:', {
    FIREBASE_SERVICE_ACCOUNT: !!process.env.FIREBASE_SERVICE_ACCOUNT,
    FIREBASE_PROJECT_ID: !!process.env.FIREBASE_PROJECT_ID,
    AGORA_APP_ID: !!process.env.AGORA_APP_ID
  });

  try {
    // Verify Firebase Admin SDK is initialized
    if (admin.apps.length === 0) {
      return res.status(500).json({
        error: 'Firebase Admin SDK not initialized',
        message: 'FIREBASE_SERVICE_ACCOUNT environment variable may be missing or invalid',
        debug: {
          hasServiceAccount: !!process.env.FIREBASE_SERVICE_ACCOUNT,
          serviceAccountLength: process.env.FIREBASE_SERVICE_ACCOUNT?.length || 0
        }
      });
    }

    // Get request data
    const data = req.body?.data || req.body;
    console.log('🔍 Extracted data:', data);
    
    const { fcmToken, callType, callerName, channelId, callerId, peerId } = data;
    
    // Validate required fields
    if (!fcmToken) {
      return res.status(400).json({
        error: 'Missing required field: fcmToken',
        receivedData: data
      });
    }

    if (!callType || !callerName || !channelId) {
      return res.status(400).json({
        error: 'Missing required fields: callType, callerName, channelId',
        receivedData: data
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
      android: {
        priority: 'high',
      },
      apns: {
        headers: {
          'apns-priority': '10',
        },
      },
    };

    // Send FCM notification
    const response = await admin.messaging().send(message);
    
    console.log(`✅ FCM notification sent successfully`);
    console.log(`   Message ID: ${response}`);

    return res.status(200).json({
      success: true,
      messageId: response,
      message: 'Push notification sent successfully',
      debug: {
        method: 'FCM HTTP v1 API',
        timestamp: Date.now()
      }
    });

  } catch (error) {
    console.error('❌ Error:', error);
    
    return res.status(500).json({
      error: 'Failed to send notification',
      message: error.message,
      code: error.code,
      debug: {
        errorName: error.name,
        stack: error.stack?.split('\n')[0]
      }
    });
  }
};
