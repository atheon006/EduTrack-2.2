importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.10.0/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyCU_A46qSy-gDHx6lHrkm8QWaixxFVDjjU",
  authDomain: "school-e04b8.firebaseapp.com",
  projectId: "school-e04b8",
  storageBucket: "school-e04b8.firebasestorage.app",
  messagingSenderId: "371745891018",
  appId: "1:371745891018:web:23a9a2c316c5ec0e88ca33",
  measurementId: "G-WR6VHEED9Q"
});

const messaging = firebase.messaging();

// Background push notification handler for EduTrack PWA
messaging.onBackgroundMessage((payload) => {
  console.log("🔔 [EduTrack SW] Background message received:", payload);
  
  const notificationTitle = payload.notification?.title || "EduTrack Notification";
  const notificationOptions = {
    body: payload.notification?.body || "Vous avez une nouvelle notification EduTrack.",
    icon: "/icons/Icon-192.png",
    badge: "/icons/Icon-192.png",
    data: payload.data || {}
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
