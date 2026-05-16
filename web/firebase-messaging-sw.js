// firebase-messaging-sw.js
// This service worker file is required for Firebase Cloud Messaging to work properly
// It handles background push notifications when the app is not in focus

importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.0/firebase-messaging-compat.js');

// Initialize Firebase in the service worker
// Using the Firebase configuration from lib/config/firebase_options.dart
firebase.initializeApp({
  apiKey: "AIzaSyD7SCL47I6u62yOILbSTDZf9m6WBy64Dw4",
  authDomain: "flags-1a8df.firebaseapp.com",
  projectId: "flags-1a8df",
  storageBucket: "flags-1a8df.firebasestorage.app",
  messagingSenderId: "967452533065",
  appId: "1:967452533065:web:f0e4cc2b2f49be5a077a98"
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Received background message ', payload);

  // Customize notification here
  const notificationTitle = payload.notification?.title || 'Flags Notification';
  const notificationOptions = {
    body: payload.notification?.body || 'You have a new notification',
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    tag: 'flags-notification',
    renotify: true,
    data: payload.data
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});

// Handle notification click
self.addEventListener('notificationclick', function(event) {
  console.log('[firebase-messaging-sw.js] Notification click: ', event);
  event.notification.close();

  // This is to handle when the user clicks on the notification
  // You can customize this to open specific pages based on the notification data
  const urlToOpen = event.notification.data?.url || '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // If a tab is already open, focus it
      for (const client of clientList) {
        if (client.url.includes(self.location.origin) && 'focus' in client) {
          return client.focus();
        }
      }
      // Otherwise, open a new tab
      if (clients.openWindow) {
        return clients.openWindow(urlToOpen);
      }
    })
  );
});

console.log('[firebase-messaging-sw.js] Service Worker initialized successfully');
