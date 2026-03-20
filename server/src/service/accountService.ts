import { User } from '../models/User';
import { TopUp } from '../models/TopUp';
import { TopUpStatus } from '../type/account';
import { transactionService } from './transactionService';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import { TransactionType } from '../type/transaction';
import mongoose from 'mongoose';

export const accountService = {
    async createTopUp(userId: string, amount: number): Promise<string> {
        // Validate user exists
        const user = await User.findById(userId);

        if (!user) {
            throw new Error('User not found');
        }

        // Create pending top-up
        const topUp = await TopUp.create({
            userId,
            amount,
            status: TopUpStatus.PENDING
        });

        return topUp._id.toString();
    },

    async completeTopUp(topUpId: string, txnRef: string): Promise<void> {
        const topUp = await TopUp.findById(topUpId);

        if (!topUp) {
            throw new Error("Top-up transaction not found");
        }

        if (topUp.status === TopUpStatus.COMPLETED) {
            return; // Already completed
        }

        const user = await User.findById(topUp.userId);

        if (!user) {
            throw new Error("User not found");
        }

        const balanceBefore = Number(user.balance);
        const amount = Number(topUp.amount);

        const session = await mongoose.startSession();
        let processed = false;
        try {
            await session.withTransaction(async () => {
                const updatedTopUp = await TopUp.findOneAndUpdate(
                    { _id: topUpId, status: TopUpStatus.PENDING },
                    { status: TopUpStatus.COMPLETED, vnpayTxnRef: txnRef },
                    { new: true, session }
                );

                if (!updatedTopUp) {
                    // Already processed elsewhere
                    return;
                }

                const updateResult = await User.updateOne(
                    { _id: topUp.userId },
                    { $inc: { balance: amount } },
                    { session }
                );

                if (updateResult.matchedCount === 0) {
                    throw new Error("User not found during balance update");
                }

                processed = true;
            });
        } finally {
            await session.endSession();
        }

        if (processed) {
            await transactionService.createTransaction({
                userId: topUp.userId,
                type: TransactionType.TOP_UP,
                amount: amount,
                balanceBefore: balanceBefore,
                balanceAfter: balanceBefore + amount,
                currency: "VND",
                description: "Top up via VNPay",
                referenceId: topUpId,
                referenceType: "TOP_UP"
            });

            // Send balance update notification
            await notificationService.createNotification({
                userId: topUp.userId,
                type: NotificationType.BALANCE_UPDATED,
                title: 'Balance Updated',
                message: `Your balance was increased by ${amount.toLocaleString()} VND. New balance: ${(balanceBefore + amount).toLocaleString()} VND`,
                data: {
                    topUpId,
                    amount,
                    newBalance: balanceBefore + amount,
                    transactionType: 'TOP_UP'
                }
            });
        }
    },

    async failTopUp(topUpId: string, txnRef: string): Promise<void> {
        await TopUp.findByIdAndUpdate(topUpId, {
            status: TopUpStatus.FAILED,
            vnpayTxnRef: txnRef
        });
    }
};

