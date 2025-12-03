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
  
  const notificationTitle = payload.notification?.title || 'Callog';
  const notificationOptions = {
    body: payload.notification?.body || 'New notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: payload.data,
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification clicks
self.addEventListener('notificationclick', (event) => {
  console.log('[firebase-messaging-sw.js] Notification click received.');
  
  event.notification.close();
  
  // Open the app when notification is clicked
  event.waitUntil(
    clients.openWindow('/')
  );
});
