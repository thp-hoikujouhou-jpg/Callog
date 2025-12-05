// 🔥 FCM Push Notification API (No Firestore, No Firebase Admin SDK)
// Uses FCM Legacy API with Web API Key only

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
    const { fcmToken, callType, callerName, callerId, channelId, peerId } = data;
    
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

    // Get environment variables
    const projectId = process.env.FIREBASE_PROJECT_ID || 'callog-30758';
    const webApiKey = process.env.FIREBASE_WEB_API_KEY;
    
    if (!webApiKey) {
      return res.status(500).json({
        error: 'FIREBASE_WEB_API_KEY not configured',
        note: 'Set this environment variable in Vercel settings'
      });
    }

    console.log(`📤 Sending FCM notification to: ${fcmToken.substring(0, 20)}...`);
    console.log(`📞 Call type: ${callType}, Caller: ${callerName}`);

    // Send FCM notification using Legacy API (Web API Key)
    const legacyFcmUrl = 'https://fcm.googleapis.com/fcm/send';
    
    const fcmPayload = {
      to: fcmToken,
      notification: {
        title: `🔔 ${callType === 'voice_call' ? '音声' : 'ビデオ'}通話着信`,
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
        peerId: peerId || 'unknown',
        timestamp: Date.now().toString(),
      },
      priority: 'high',
      time_to_live: 60, // Notification expires after 60 seconds
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
      console.log(`   Message ID: ${fcmResult.results?.[0]?.message_id || 'N/A'}`);
      
      return res.status(200).json({
        data: {
          success: true,
          messageId: fcmResult.results?.[0]?.message_id || null,
          message: 'Push notification sent successfully via FCM',
          method: 'FCM Legacy API',
          timestamp: Date.now()
        }
      });
    } else {
      console.error('❌ FCM notification failed:', fcmResult);
      const errorMessage = fcmResult.results?.[0]?.error || 'Unknown FCM error';
      
      return res.status(400).json({
        error: 'FCM notification failed',
        fcmError: errorMessage,
        details: fcmResult,
        note: errorMessage === 'InvalidRegistration' 
          ? 'FCM token is invalid or expired. User needs to re-login.'
          : 'Check FCM token and API key configuration.'
      });
    }

  } catch (error) {
    console.error('❌ Error sending FCM notification:', error);
    return res.status(500).json({
      error: 'Failed to send notification',
      message: error.message,
      stack: process.env.NODE_ENV === 'development' ? error.stack : undefined
    });
  }
};
