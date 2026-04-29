import { subscriptionService } from './service/subscriptionService';
import { paymentRequestService } from './service/paymentRequestService';
import { recurringBillService } from './service/recurringBillService';

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
        console.log(`[Scheduler] Running at ${new Date().toISOString()}`);
        const result = await subscriptionService.processRenewals();
        if (result.totalMembersChecked > 0) {
            console.log(`[Scheduler] Subscriptions: ${result.charged} charged, ${result.failed} failed, ${result.kicked} kicked`);
        }
        await paymentRequestService.processExpirationsAndReminders();

        // Recurring bills: auto-generate DRAFT invoices from templates
        const rbResult = await recurringBillService.processAutoGenerate();
        if (rbResult.generated > 0 || rbResult.failed > 0) {
            console.log(`[Scheduler] RecurringBills: +${rbResult.generated} generated, ${rbResult.skipped} skipped, ${rbResult.failed} failed`);
        }
    } catch (error) {
        console.error('[Scheduler] Error:', error);
    }
}
