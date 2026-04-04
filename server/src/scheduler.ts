import { subscriptionService } from './service/subscriptionService';
import { paymentRequestService } from './service/paymentRequestService';

const INTERVAL_MS = 60 * 60 * 1000; // 1 hour

export const startScheduler = () => {
    console.log('✓ Scheduler started directly (checking every hour)');

    // Initial check on startup (delay slightly to ensure DB connection)
    setTimeout(() => {
        runJob();
    }, 5000);

    setInterval(async () => {
        await runJob();
    }, INTERVAL_MS);
};

async function runJob() {
    try {
        console.log(`[Scheduler] Running subscription renewals check at ${new Date().toISOString()}`);
        const result = await subscriptionService.processRenewals();
        if (result.totalSubscriptions > 0) {
            console.log(`[Scheduler] Subscription renewals processed: ${result.successfulCharges} success, ${result.failedCharges} failed out of ${result.totalSubscriptions}`);
        }
        await paymentRequestService.processExpirationsAndReminders();
    } catch (error) {
        console.error('[Scheduler] Error processing subscription renewals:', error);
    }
}
