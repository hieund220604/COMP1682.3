import admin from 'firebase-admin';
import path from 'path';

// Define the path to the service account key
const serviceAccountPath = path.join(__dirname, 'serviceAccountKey.json');

// Initialize Firebase Admin
if (!admin.apps.length) {
    try {
        admin.initializeApp({
            credential: admin.credential.cert(require(serviceAccountPath))
        });
        console.log('Firebase Admin initialized successfully');
    } catch (error) {
        console.error('Firebase Admin initialization error', error);
    }
}

export { admin };
