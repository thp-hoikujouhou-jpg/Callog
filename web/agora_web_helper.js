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

// REMOVED: ensureFlutterUIOnTop() - No longer manipulating Flutter UI z-index

/**
 * Resume AudioContext (required for browser autoplay policy)
 */
function resumeAudioContext() {
  if (window.AgoraRTC && window.AgoraRTC.audioContext) {
    if (window.AgoraRTC.audioContext.state === 'suspended') {
      console.log('[AgoraWebHelper] 🔊 Resuming AudioContext...');
      window.AgoraRTC.audioContext.resume().then(() => {
        console.log('[AgoraWebHelper] ✅ AudioContext resumed successfully');
      }).catch(err => {
        console.error('[AgoraWebHelper] ❌ Failed to resume AudioContext:', err);
      });
    } else {
      console.log('[AgoraWebHelper] 🔊 AudioContext state:', window.AgoraRTC.audioContext.state);
    }
  }
}

/**
 * Create and join Agora channel with audio only
 * 
 * @param {string} appId - Agora App ID
 * @param {string} channelName - Channel name to join
 * @param {string} token - Agora token (optional)
 * @param {number} uid - User ID (0 for auto-assign)
 * @returns {Promise<object>} Client and tracks
 */
window.agoraJoinAudioChannel = async function(appId, channelName, token, uid = 0) {
  try {
    console.log('[AgoraWebHelper] 🚀 Creating AUDIO-ONLY client...');
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
        // Resume AudioContext first (browser autoplay policy)
        resumeAudioContext();
        
        // Play the remote audio track
        const remoteAudioTrack = user.audioTrack;
        
        // CRITICAL FIX: Set volume BEFORE playing
        console.log(`[AgoraWebHelper] 🔊 Setting remote audio volume to 100 for user: ${user.uid}`);
        remoteAudioTrack.setVolume(100);
        
        // Play after volume is set
        remoteAudioTrack.play();
        console.log(`[AgoraWebHelper] ✅ Remote audio playing at volume 100 from user: ${user.uid}`);
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
    console.error('[AgoraWebHelper] ❌ Error in agoraJoinAudioChannel:', error);
    throw error;
  }
};

/**
 * Create and join Agora channel with audio + video
 * 
 * @param {string} appId - Agora App ID
 * @param {string} channelName - Channel name to join
 * @param {string} token - Agora token (optional)
 * @param {number} uid - User ID (0 for auto-assign)
 * @returns {Promise<object>} Client and tracks
 */
window.agoraJoinVideoChannel = async function(appId, channelName, token, uid = 0) {
  try {
    console.log('[AgoraWebHelper] 🚀 Creating AUDIO+VIDEO client...');
    console.log('[AgoraWebHelper] App ID:', appId);
    console.log('[AgoraWebHelper] Channel:', channelName);
    console.log('[AgoraWebHelper] Token:', token ? 'YES' : 'NO');
    console.log('[AgoraWebHelper] UID:', uid);
    
    // Create client
    const client = AgoraRTC.createClient({ 
      mode: 'rtc', 
      codec: 'vp8'
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
        // Resume AudioContext first (browser autoplay policy)
        resumeAudioContext();
        
        const remoteAudioTrack = user.audioTrack;
        
        // CRITICAL FIX: Set volume BEFORE playing
        console.log(`[AgoraWebHelper] 🔊 Setting remote audio volume to 100 for user: ${user.uid}`);
        remoteAudioTrack.setVolume(100);
        
        // Play after volume is set
        remoteAudioTrack.play();
        console.log(`[AgoraWebHelper] ✅ Remote audio playing at volume 100 from user: ${user.uid}`);
      }
      
      if (mediaType === 'video') {
        const remoteVideoTrack = user.videoTrack;
        // Play video in a div with id 'remote-video-container'
        const remoteContainer = document.getElementById('remote-video-container');
        if (remoteContainer) {
          remoteContainer.style.display = 'block';
          remoteContainer.style.visibility = 'visible';
          remoteContainer.style.pointerEvents = 'none'; // CRITICAL: Video never captures clicks
          remoteContainer.style.zIndex = '-1'; // ALWAYS behind Flutter UI
          remoteVideoTrack.play(remoteContainer);
          console.log('[AgoraWebHelper] 📹 Playing remote video, z-index: -1 (behind Flutter)');
        } else {
          console.warn('[AgoraWebHelper] ⚠️ remote-video-container not found');
        }
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
    
    // Create local video track
    console.log('[AgoraWebHelper] 📹 Creating camera video track...');
    const videoTrack = await AgoraRTC.createCameraVideoTrack({
      encoderConfig: '720p_2',
    });
    console.log('[AgoraWebHelper] ✅ Camera video track created');
    
    // Play local video in a div with id 'local-video-container'
    const localContainer = document.getElementById('local-video-container');
    if (localContainer) {
      localContainer.style.display = 'block';
      localContainer.style.visibility = 'visible';
      localContainer.style.pointerEvents = 'none'; // CRITICAL: Video never captures clicks
      localContainer.style.zIndex = '-1'; // ALWAYS behind Flutter UI
      videoTrack.play(localContainer);
      console.log('[AgoraWebHelper] 📹 Playing local video, z-index: -1 (behind Flutter)');
    } else {
      console.warn('[AgoraWebHelper] ⚠️ local-video-container not found');
    }
    
    // Store tracks globally
    window.agoraAudioTracks[channelName] = audioTrack;
    window.agoraVideoTracks[channelName] = videoTrack;
    
    // Set audio volume to maximum
    audioTrack.setVolume(100);
    console.log('[AgoraWebHelper] 🔊 Local audio volume set to 100');
    
    // Publish audio and video tracks
    console.log('[AgoraWebHelper] 📤 Publishing audio and video tracks...');
    await client.publish([audioTrack, videoTrack]);
    console.log('[AgoraWebHelper] ✅ Audio and video tracks published successfully!');
    
    // Log current remote users
    const remoteUsers = client.remoteUsers;
    console.log('[AgoraWebHelper] 👥 Current remote users:', remoteUsers.length);
    remoteUsers.forEach(user => {
      console.log('[AgoraWebHelper]   - User:', user.uid, 'Audio:', user.hasAudio, 'Video:', user.hasVideo);
    });
    
    return {
      client: client,
      audioTrack: audioTrack,
      videoTrack: videoTrack,
      uid: assignedUid
    };
    
  } catch (error) {
    console.error('[AgoraWebHelper] ❌ Error in agoraJoinVideoChannel:', error);
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
    const videoTrack = window.agoraVideoTracks[channelName];
    
    if (videoTrack) {
      // Close and release video track
      videoTrack.close();
      console.log('[AgoraWebHelper] ✅ Video track closed');
    }
    
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
      delete window.agoraVideoTracks[channelName];
    }
    
    // Hide video containers and reset z-index
    const localContainer = document.getElementById('local-video-container');
    const remoteContainer = document.getElementById('remote-video-container');
    if (localContainer) {
      localContainer.style.display = 'none';
      localContainer.style.visibility = 'hidden';
      localContainer.style.zIndex = '-1'; // Move behind everything when hidden
      console.log('[AgoraWebHelper] 🙈 Local video container hidden');
    }
    if (remoteContainer) {
      remoteContainer.style.display = 'none';
      remoteContainer.style.visibility = 'hidden';
      remoteContainer.style.zIndex = '-1'; // Move behind everything when hidden
      console.log('[AgoraWebHelper] 🙈 Remote video container hidden');
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

/**
 * Toggle video camera
 * 
 * @param {string} channelName - Channel name
 * @param {boolean} enabled - True to enable, false to disable
 */
window.agoraToggleVideo = async function(channelName, enabled) {
  try {
    const videoTrack = window.agoraVideoTracks[channelName];
    if (videoTrack) {
      await videoTrack.setEnabled(enabled);
      console.log('[AgoraWebHelper]', enabled ? '📹 Video enabled' : '🔲 Video disabled');
    }
  } catch (error) {
    console.error('[AgoraWebHelper] ❌ Toggle video error:', error);
  }
};

/**
 * Switch camera (front/back)
 * 
 * @param {string} channelName - Channel name
 */
window.agoraSwitchCamera = async function(channelName) {
  try {
    const videoTrack = window.agoraVideoTracks[channelName];
    if (videoTrack) {
      const devices = await AgoraRTC.getCameras();
      if (devices.length > 1) {
        const currentDevice = videoTrack.getMediaStreamTrack().getSettings().deviceId;
        const nextDevice = devices.find(d => d.deviceId !== currentDevice);
        if (nextDevice) {
          await videoTrack.setDevice(nextDevice.deviceId);
          console.log('[AgoraWebHelper] 🔄 Switched to camera:', nextDevice.label);
        }
      } else {
        console.warn('[AgoraWebHelper] ⚠️ Only one camera available');
      }
    }
  } catch (error) {
    console.error('[AgoraWebHelper] ❌ Switch camera error:', error);
  }
};

console.log('[AgoraWebHelper] ✅ Agora Web Helper loaded successfully');
