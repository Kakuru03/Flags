// set-admin.js
const admin = require('firebase-admin');

// 1. Initialize the SDK with your service account
// You can download this file from Firebase Console > Project Settings > Service Accounts
const serviceAccount = require('./path/to/your-service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

// 2. Define the user's UID and the custom claims object
const uid = 'Puneq4vFjPTKfBGvlRJ7HlEBKUy2';
const claims = { admin: true }; // You can use any key, like 'role': 'admin'

// 3. Set the custom claims
admin.auth().setCustomUserClaims(uid, claims)
  .then(() => {
    console.log(`Success! Custom claims set for user ${uid}:`, claims);
  })
  .catch((error) => {
    console.log('Error setting custom claims:', error);
  });