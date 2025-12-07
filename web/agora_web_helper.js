/**
 * Agora Web SDK Native Helper
 * 
 * This helper provides direct access to Agora Web SDK v4.x APIs
 * Bypasses Flutter SDK wrapper for better Web compatibility
 */

// Global Agora client instances
window.agoraClients = {};
window.agoraAudioTracks = {};
window.agoraVideoTracks = {};

/**
 * Create and join Agora channel with audio
 * 
 * @param {string} appId - Agora App ID
 * @param {string} channelName - Channel name to join
 * @param {string} token - Agora token (optional)
 * @param {number} uid - User ID (0 for auto-assign)
 * @returns {Promise<object>} Client and tracks
 */
window.agoraJoinAudioChannel = async function(appId, channelName, token, uid = 0) {
  try {
    console.log('[AgoraWebHelper] 🚀 Creating audio client...');
    console.log('[AgoraWebHelper] App ID:', appId);
    console.log('[AgoraWebHelper] Channel:', channelName);
    console.log('[AgoraWebHelper] Token:', token ? 'YES' : 'NO');
    console.log('[AgoraWebHelper] UID:', uid);
    
    // Create client
    const client = AgoraRTC.createClient({ 
      mode: 'rtc', 
      codec: 'vp8' // VP8 for better compatibility
    });
    
    // Store client globally
    window.agoraClients[channelName] = client;
    
    // Set up event handlers
    client.on('user-published', async (user, mediaType) => {
      console.log('[AgoraWebHelper] ✅ User published:', user.uid, 'MediaType:', mediaType);
      
      // Subscribe to the remote user
      await client.subscribe(user, mediaType);
      console.log('[AgoraWebHelper] ✅ Subscribed to user:', user.uid);
      
      if (mediaType === 'audio') {
        // Play the remote audio track
        const remoteAudioTrack = user.audioTrack;
        remoteAudioTrack.play();
        console.log('[AgoraWebHelper] 🔊 Playing remote audio from user:', user.uid);
        
        // Set volume to maximum
        remoteAudioTrack.setVolume(100);
        console.log('[AgoraWebHelper] 🔊 Remote audio volume set to 100');
      }
    });
    
    client.on('user-unpublished', (user, mediaType) => {
      console.log('[AgoraWebHelper] 👋 User unpublished:', user.uid, 'MediaType:', mediaType);
    });
    
    client.on('user-joined', (user) => {
      console.log('[AgoraWebHelper] 🎉 User joined channel:', user.uid);
    });
    
    client.on('user-left', (user, reason) => {
      console.log('[AgoraWebHelper] 👋 User left channel:', user.uid, 'Reason:', reason);
    });
    
    // Join channel
    console.log('[AgoraWebHelper] 📡 Joining channel...');
    const assignedUid = await client.join(appId, channelName, token || null, uid);
    console.log('[AgoraWebHelper] ✅ Joined channel successfully!');
    console.log('[AgoraWebHelper] Assigned UID:', assignedUid);
    
    // Create local audio track
    console.log('[AgoraWebHelper] 🎤 Creating microphone audio track...');
    const audioTrack = await AgoraRTC.createMicrophoneAudioTrack({
      encoderConfig: 'high_quality_stereo',
    });
    console.log('[AgoraWebHelper] ✅ Microphone audio track created');
    
    // Store audio track globally
    window.agoraAudioTracks[channelName] = audioTrack;
    
    // Set audio track volume to maximum
    audioTrack.setVolume(100);
    console.log('[AgoraWebHelper] 🔊 Local audio volume set to 100');
    
    // Publish audio track
    console.log('[AgoraWebHelper] 📤 Publishing audio track...');
    await client.publish([audioTrack]);
    console.log('[AgoraWebHelper] ✅ Audio track published successfully!');
    
    // Log current remote users
    const remoteUsers = client.remoteUsers;
    console.log('[AgoraWebHelper] 👥 Current remote users:', remoteUsers.length);
    remoteUsers.forEach(user => {
      console.log('[AgoraWebHelper]   - User:', user.uid, 'Audio:', user.hasAudio, 'Video:', user.hasVideo);
    });
    
    return {
      client: client,
      audioTrack: audioTrack,
      uid: assignedUid
    };
    
  } catch (error) {
    console.error('[AgoraWebHelper] ❌ Error:', error);
    throw error;
  }
};

/**
 * Leave Agora channel
 * 
 * @param {string} channelName - Channel name to leave
 */
window.agoraLeaveChannel = async function(channelName) {
  try {
    console.log('[AgoraWebHelper] 🚪 Leaving channel:', channelName);
    
    const client = window.agoraClients[channelName];
    const audioTrack = window.agoraAudioTracks[channelName];
    
    if (audioTrack) {
      // Close and release audio track
      audioTrack.close();
      console.log('[AgoraWebHelper] ✅ Audio track closed');
    }
    
    if (client) {
      // Unpublish and leave
      await client.unpublish();
      await client.leave();
      console.log('[AgoraWebHelper] ✅ Left channel successfully');
      
      // Clean up
      delete window.agoraClients[channelName];
      delete window.agoraAudioTracks[channelName];
    }
    
  } catch (error) {
    console.error('[AgoraWebHelper] ❌ Leave error:', error);
  }
};

/**
 * Toggle microphone mute
 * 
 * @param {string} channelName - Channel name
 * @param {boolean} muted - True to mute, false to unmute
 */
window.agoraMuteMicrophone = async function(channelName, muted) {
  try {
    const audioTrack = window.agoraAudioTracks[channelName];
    if (audioTrack) {
      await audioTrack.setEnabled(!muted);
      console.log('[AgoraWebHelper]', muted ? '🔇 Muted' : '🔊 Unmuted');
    }
  } catch (error) {
    console.error('[AgoraWebHelper] ❌ Mute error:', error);
  }
};

console.log('[AgoraWebHelper] ✅ Agora Web Helper loaded successfully');
