// CRITICAL: Load dotenv FIRST before any other imports
import dotenv from 'dotenv';
dotenv.config();

import express from 'express';
import { createServer } from 'http';
import cors from 'cors';
import fs from 'fs';
import path from 'path';
import { connectDB, disconnectDB } from './db';
import mongoose from 'mongoose';
import { setupSocketIO } from './socketSetup';
import { initializeFirebase } from './config/firebase';
import authRoutes from './route/authRoutes';
import groupRoutes from './route/groupRoutes';
import accountRoutes from './route/accountRoutes';
import vnpayRoutes from './route/vnpayRoutes';
import withdrawalRoutes from './route/withdrawalRoutes';
import transactionRoutes from './route/transactionRoutes';
import subscriptionRoutes from './route/subscriptionRoutes';
import chatRoutes from './route/chatRoutes';
import uploadRoutes from './route/uploadRoutes';
import notificationRoutes from './route/notificationRoutes';
import aiRoutes from './route/aiRoutes';
// UpBill Routes
import invoiceRoutes from './route/invoiceRoutes';
import paymentRequestRoutes from './route/paymentRequestRoutes';
import transferRoutes from './route/transferRoutes';
import exchangeRateRoutes from './route/exchangeRateRoutes';
import dashboardRoutes from './route/dashboardRoutes';
import forecastRoutes from './route/forecastRoutes';
import receiptRoutes from './route/receiptRoutes';
import budgetRoutes from './route/budgetRoutes';
import { connectRedis, disconnectRedis } from './redis';

const app = express();
const httpServer = createServer(app);
const PORT = process.env.PORT || 3000;

// Ensure uploads directory exists
const uploadsDir = path.join(__dirname, 'uploads');
if (!fs.existsSync(uploadsDir)) {
    fs.mkdirSync(uploadsDir, { recursive: true });
}

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/groups', groupRoutes);
app.use('/api/accounts', accountRoutes);
app.use('/api/payments', vnpayRoutes);
app.use('/api/withdrawals', withdrawalRoutes);
app.use('/api/transactions', transactionRoutes);
app.use('/api/subscriptions', subscriptionRoutes);
app.use('/api/chat', chatRoutes);
app.use('/api/upload', uploadRoutes); // New upload route
app.use('/api/notifications', notificationRoutes); // Notification route
app.use('/api/ai', aiRoutes);
app.use('/api/receipts', receiptRoutes);
app.use('/api/budget', budgetRoutes);
app.use('/uploads', express.static(path.join(process.cwd(), 'uploads'))); // Serve uploaded files

// UpBill Routes - mounted separately due to groupId param
app.use('/api/invoices', invoiceRoutes);
app.use('/api/payment-requests', paymentRequestRoutes);
app.use('/api/transfers', transferRoutes);
app.use('/api/exchange', exchangeRateRoutes);
app.use('/api/dashboard', dashboardRoutes);
app.use('/api/forecast', forecastRoutes);

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({ status: 'OK', timestamp: new Date().toISOString() });
});

// DEBUG: Reset all test data (only for development)
app.post('/api/debug/reset-test-data', async (req, res) => {
    if (process.env.NODE_ENV === 'production') {
        res.status(403).json({ error: 'Not allowed in production' });
        return;
    }
    try {
        const { User } = await import('./models/User');
        const { Group } = await import('./models/Group');
        const { GroupMember } = await import('./models/GroupMember');
        const { Invite } = await import('./models/Invite');
        const { Invoice } = await import('./models/Invoice');
        const { InvoiceItem } = await import('./models/InvoiceItem');
        const { OriginalDebt } = await import('./models/OriginalDebt');
        const { PaymentRequest } = await import('./models/PaymentRequest');
        const { Transfer } = await import('./models/Transfer');
        const { TransferDebtAllocation } = await import('./models/TransferDebtAllocation');

        // Delete test users
        const userResult = await User.deleteMany({ email: { $regex: /test\.com$/ } });
        // Delete all groups, members, invites, etc.
        const groupResult = await Group.deleteMany({});
        await GroupMember.deleteMany({});
        await Invite.deleteMany({});
        await Invoice.deleteMany({});
        await InvoiceItem.deleteMany({});
        await OriginalDebt.deleteMany({});
        await PaymentRequest.deleteMany({});
        await Transfer.deleteMany({});
        await TransferDebtAllocation.deleteMany({});

        console.log('Test data reset completed');
        res.json({
            success: true,
            message: 'All test data cleared',
            deleted: {
                users: userResult.deletedCount,
                groups: groupResult.deletedCount
            }
        });
    } catch (error) {
        console.error('Reset test data error:', error);
        res.status(500).json({ error: 'Failed to reset test data' });
    }
});

// Database connection test
app.get('/db-test', async (req, res) => {
    try {
        // Ping MongoDB
        if (!mongoose.connection.db) {
            throw new Error('Database not connected');
        }
        await mongoose.connection.db.admin().ping();
        res.json({
            status: 'Connected to MongoDB',
            database: mongoose.connection.name,
            timestamp: new Date()
        });
    } catch (error) {
        res.status(500).json({
            status: 'Database connection failed',
            error: error instanceof Error ? error.message : 'Unknown error'
        });
    }
});

// Error handler
app.use((err: any, req: express.Request, res: express.Response, next: express.NextFunction) => {
    console.error('Error:', err);
    res.status(err.status || 500).json({
        success: false,
        message: err.message || 'Internal server error'
    });
});

// 404 handler
app.use((req, res) => {
    res.status(404).json({
        success: false,
        message: 'Route not found'
    });
});

import { startScheduler } from './scheduler';

// ... (imports)

// Start server
const startServer = async () => {
    try {
        await connectDB();
        await connectRedis();

        // Initialize Firebase (optional - won't crash if not configured)
        initializeFirebase();

        // Start Scheduler
        startScheduler();

        // Setup Socket.IO
        const io = setupSocketIO(httpServer);
        console.log('✓ Socket.IO initialized');

        httpServer.listen(Number(PORT), '0.0.0.0', () => {
            console.log(`✓ Server running on port ${PORT}`);
            console.log(`✓ Environment: ${process.env.NODE_ENV || 'development'}`);
            console.log(`✓ API available at http://localhost:${PORT}/api`);
            console.log(`✓ WebSocket available at ws://localhost:${PORT}`);
        });
    } catch (error) {
        console.error('Failed to start server:', error);
        process.exit(1);
    }
};

// Graceful shutdown
process.on('SIGINT', async () => {
    console.log('\n✓ Shutting down gracefully...');
    await disconnectRedis();
    await disconnectDB();
    process.exit(0);
});

process.on('SIGTERM', async () => {
    console.log('\n✓ Shutting down gracefully...');
    await disconnectRedis();
    await disconnectDB();
    process.exit(0);
});

// Handle uncaught exceptions
process.on('uncaughtException', (error) => {
    console.error('Uncaught Exception:', error);
    // Don't exit, just log it
});

process.on('unhandledRejection', (reason, promise) => {
    console.error('Unhandled Rejection at:', promise, 'reason:', reason);
    // Don't exit, just log it
});

startServer();
