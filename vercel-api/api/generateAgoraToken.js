const { RtcTokenBuilder, RtcRole } = require('agora-token');

module.exports = async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Credentials', true);
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET,OPTIONS,PATCH,DELETE,POST,PUT');
  res.setHeader('Access-Control-Allow-Headers', 'X-CSRF-Token, X-Requested-With, Accept, Accept-Version, Content-Length, Content-MD5, Content-Type, Date, X-Api-Version, Authorization');
  
  // Handle OPTIONS preflight
  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  try {
    // Get request data
    const data = req.body.data || req.body;
    const channelName = data.channelName;
    const uid = data.uid || 0;
    const role = data.role || 'publisher';
    
    // Validate
    if (!channelName) {
      return res.status(400).json({
        error: 'Channel name is required'
      });
    }
    
    // Get environment variables
    const appId = process.env.AGORA_APP_ID;
    const appCertificate = process.env.AGORA_APP_CERTIFICATE;
    
    // Check certificate
    if (!appCertificate) {
      return res.status(200).json({
        data: {
          token: null,
          appId: appId,
          channelName: channelName,
          uid: uid,
          message: 'App Certificate not configured',
        }
      });
    }
    
    // Generate token
    const expirationTimeInSeconds = Math.floor(Date.now() / 1000) + 86400;
    const rtcRole = role === 'audience' ? RtcRole.AUDIENCE : RtcRole.PUBLISHER;
    
    const token = RtcTokenBuilder.buildTokenWithUid(
      appId,
      appCertificate,
      channelName,
      uid,
      rtcRole,
      expirationTimeInSeconds
    );
    
    return res.status(200).json({
      data: {
        token: token,
        appId: appId,
        channelName: channelName,
        uid: uid,
        expiresAt: expirationTimeInSeconds,
      }
    });
    
  } catch (error) {
    console.error('Error:', error);
    return res.status(500).json({
      error: 'Failed to generate token: ' + error.message
    });
  }
};
