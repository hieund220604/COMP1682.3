import mongoose from 'mongoose';

const connectDB = async (): Promise<void> => {
    const mongoURI = process.env.MONGODB_URI || 'mongodb://localhost:27017/splitpal';
    const serverSelectionTimeoutMS = Number(process.env.MONGO_TIMEOUT_MS ?? 5000);
    const allowInsecureTls = process.env.MONGO_TLS_INSECURE === 'true';

    try {
        await mongoose.connect(mongoURI, {
            serverSelectionTimeoutMS,
            tls: true,
            tlsAllowInvalidCertificates: allowInsecureTls,
            tlsAllowInvalidHostnames: allowInsecureTls,
        });
        console.log('Connected to MongoDB');
        console.log(`Database: ${mongoose.connection.name}`);
    } catch (error) {
        console.error('MongoDB connection error:', error);
        throw error;
    }
};

// Graceful disconnect
const disconnectDB = async (): Promise<void> => {
    try {
        await mongoose.disconnect();
        console.log('Disconnected from MongoDB');
    } catch (error) {
        console.error('MongoDB disconnect error:', error);
        throw error;
    }
};

export { connectDB, disconnectDB };
export default mongoose;
