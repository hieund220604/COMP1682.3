import admin from 'firebase-admin';

// Re-export admin - initialization is handled centrally in firebase.ts via initializeFirebase()
// Use admin.app() to get the existing default app when needed.
export { admin };
