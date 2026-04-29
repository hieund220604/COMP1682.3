import fs from 'node:fs';
import path from 'node:path';
import admin from 'firebase-admin';

let firebaseApp: admin.app.App | null = null;

function resolveServiceAccountPath(configuredPath?: string): string | null {
    if (!configuredPath) {
        return null;
    }

    if (path.isAbsolute(configuredPath)) {
        return configuredPath;
    }

    const cwdPath = path.resolve(process.cwd(), configuredPath);
    if (fs.existsSync(cwdPath)) {
        return cwdPath;
    }

    const localPath = path.resolve(__dirname, '../../firebase-service-account.json');
    if (fs.existsSync(localPath)) {
        return localPath;
    }

    return cwdPath;
}

/**
 * Initialize Firebase Admin SDK
 * Supports service-account path, inline JSON, or application default credentials.
 */
export function initializeFirebase(): admin.app.App | null {
    if (firebaseApp) {
        return firebaseApp;
    }

    try {
        const envPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
        const resolvedPath = resolveServiceAccountPath(envPath);

        if (resolvedPath && fs.existsSync(resolvedPath)) {
            const serviceAccount = JSON.parse(fs.readFileSync(resolvedPath, 'utf8'));
            firebaseApp = admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            console.log(`Firebase Admin SDK initialized with service account file: ${resolvedPath}`);
            return firebaseApp;
        }

        if (process.env.FIREBASE_SERVICE_ACCOUNT_JSON) {
            const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT_JSON);
            firebaseApp = admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            console.log('Firebase Admin SDK initialized with service account JSON');
            return firebaseApp;
        }

        const fallbackPath = path.resolve(__dirname, '../../firebase-service-account.json');
        if (fs.existsSync(fallbackPath)) {
            const serviceAccount = JSON.parse(fs.readFileSync(fallbackPath, 'utf8'));
            firebaseApp = admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            console.log(`Firebase Admin SDK initialized with local service account: ${fallbackPath}`);
            return firebaseApp;
        }

        // Legacy: check serviceAccountKey.json in the config directory
        const legacyPath = path.resolve(__dirname, './serviceAccountKey.json');
        if (fs.existsSync(legacyPath)) {
            const serviceAccount = JSON.parse(fs.readFileSync(legacyPath, 'utf8'));
            firebaseApp = admin.initializeApp({
                credential: admin.credential.cert(serviceAccount)
            });
            console.log(`Firebase Admin SDK initialized with legacy service account: ${legacyPath}`);
            return firebaseApp;
        }

        firebaseApp = admin.initializeApp({
            credential: admin.credential.applicationDefault()
        });
        console.log('Firebase Admin SDK initialized with application default credentials');
    } catch (error) {
        console.warn('Firebase Admin SDK not initialized:', error);
        console.warn('Push notifications will not be available. Set FIREBASE_SERVICE_ACCOUNT_PATH or FIREBASE_SERVICE_ACCOUNT_JSON in .env to enable FCM.');
        firebaseApp = null;
    }

    return firebaseApp;
}

/**
 * Get Firebase Admin instance
 */
export function getFirebaseAdmin(): admin.app.App | null {
    return firebaseApp;
}

/**
 * Check if Firebase is initialized
 */
export function isFirebaseInitialized(): boolean {
    return firebaseApp !== null;
}

/**
 * Get Firebase Messaging instance
 */
export function getMessaging(): admin.messaging.Messaging | null {
    if (!firebaseApp) {
        return null;
    }
    return admin.messaging(firebaseApp);
}
