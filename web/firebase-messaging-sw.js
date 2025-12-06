// Firebase Cloud Messaging Service Worker
// This file handles background push notifications for Web platform

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

// Initialize Firebase with your config
firebase.initializeApp({
  apiKey: "AIzaSyCuBb67jyaJQPFgOKgwMkBShARGFfv3aW0",
  authDomain: "callog-30758.firebaseapp.com",
  projectId: "callog-30758",
  storageBucket: "callog-30758.firebasestorage.app",
  messagingSenderId: "1054733931534",
  appId: "1:1054733931534:web:fdb1e3ad5f1f9a81b4e7e9",
  measurementId: "G-DPFMV8J0WG"
});

// Retrieve an instance of Firebase Messaging
const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);
  console.log('[firebase-messaging-sw.js] Payload data:', payload.data);
  
  // Extract call data
  const data = payload.data || {};
  const callType = data.type || '';
  const callerName = data.callerName || 'Unknown';
  
  // Prepare notification for incoming call
  let notificationTitle = 'Callog';
  let notificationBody = 'New notification';
  
  if (callType === 'voice_call') {
    notificationTitle = '音声通話着信';
    notificationBody = `${callerName} さんから音声通話がかかってきています`;
  } else if (callType === 'video_call') {
    notificationTitle = 'ビデオ通話着信';
    notificationBody = `${callerName} さんからビデオ通話がかかってきています`;
  } else if (payload.notification) {
    notificationTitle = payload.notification.title || 'Callog';
    notificationBody = payload.notification.body || 'New notification';
  }
  
  const notificationOptions = {
    body: notificationBody,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: data,
    requireInteraction: true, // Keep notification visible until user interacts
    tag: `call-${data.channelId || Date.now()}`, // Unique tag for call notifications
    vibrate: [200, 100, 200], // Vibration pattern
  };

  console.log('[firebase-messaging-sw.js] Showing notification:', notificationTitle, notificationOptions);
  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click received.');
  console.log('[firebase-messaging-sw.js] Notification data:', event.notification.data);
  
  event.notification.close();
  
  // Get call data from notification
  const data = event.notification.data || {};
  const channelId = data.channelId || '';
  const callType = data.type || '';
  
  // Build URL with call parameters
  let targetUrl = '/';
  if (channelId && callType) {
    targetUrl = `/?call=incoming&channelId=${channelId}&type=${callType}&callerName=${encodeURIComponent(data.callerName || 'Unknown')}&callerId=${data.callerId || 'unknown'}`;
  }
  
  console.log('[firebase-messaging-sw.js] Opening URL:', targetUrl);
  
  // Open the app with call parameters when notification is clicked
  event.waitUntil(
    clients.matchAll({type: 'window', includeUncontrolled: true}).then((clientList) => {
      // Check if there's already a window open
      for (const client of clientList) {
        if (client.url.includes(self.registration.scope) && 'focus' in client) {
          // Focus existing window and navigate to call screen
          client.focus();
          client.postMessage({
            type: 'incoming_call',
            data: data
          });
          return;
        }
      }
      // No window found, open a new one
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
