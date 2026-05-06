import { Transfer, TransferStatus } from '../models/Transfer';
import { TransferDebtAllocation } from '../models/TransferDebtAllocation';
import { User } from '../models/User';
import { Invoice } from '../models/Invoice';
import { GroupMember } from '../models/GroupMember';
import { originalDebtService } from './originalDebtService';
import { paymentRequestService } from './paymentRequestService';
import { emailService } from './emailService';
import { transactionService } from './transactionService';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import { TransactionType } from '../type/transaction';
import {
    TransferResponse,
    DebtAllocationDetail,
    InitiatePaymentResponse,
    PaymentCompleteResponse,
    MyTransfersResponse
} from '../type/transfer';
import { UserSummary } from '../type/invoice';
import mongoose from 'mongoose';

const transformUser = (user: any): UserSummary => ({
    id: user._id.toString(),
    displayName: user.displayName,
    avatarUrl: user.avatarUrl
});

function generateOTP(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

export const transferService = {
    /**
     * Get transfer by ID with full details
     */
    async getTransferById(transferId: string): Promise<TransferResponse | null> {
        const transfer = await Transfer.findById(transferId);
        if (!transfer) return null;

        const [fromUser, toUser] = await Promise.all([
            User.findById(transfer.fromUserId),
            User.findById(transfer.toUserId)
        ]);

        // Get debt allocations
        const allocations = await TransferDebtAllocation.find({ transferId });
        const allocationDetails: DebtAllocationDetail[] = await Promise.all(
            allocations.map(async (alloc) => {
                const invoice = await Invoice.findOne({
                    _id: { $in: await this.getInvoiceIdFromDebt(alloc.originalDebtId) }
                });
                return {
                    originalDebtId: alloc.originalDebtId,
                    invoiceId: invoice?._id.toString() || '',
                    invoiceTitle: invoice?.title || 'Unknown',
                    allocatedAmount: alloc.allocatedAmount
                };
            })
        );

        return {
            id: transfer._id.toString(),
            paymentRequestId: transfer.paymentRequestId,
            groupId: transfer.groupId,
            fromUser: fromUser ? transformUser(fromUser) : { id: transfer.fromUserId, displayName: null, avatarUrl: null },
            toUser: toUser ? transformUser(toUser) : { id: transfer.toUserId, displayName: null, avatarUrl: null },
            amount: transfer.amount,
            status: transfer.status,
            paidAt: transfer.paidAt ?? undefined,
            otpExpiresAt: transfer.otpExpiresAt ?? undefined,
            createdAt: transfer.createdAt,
            categoryTagId: transfer.categoryTagId ?? undefined,
            debtAllocations: allocationDetails
        };
    },

    /**
     * Helper to get invoice ID from original debt
     */
    async getInvoiceIdFromDebt(originalDebtId: string): Promise<string[]> {
        const { OriginalDebt } = await import('../models/OriginalDebt');
        const debt = await OriginalDebt.findById(originalDebtId);
        return debt ? [debt.invoiceId] : [];
    },

    /**
     * Get my transfers (pending and completed)
     */
    async getMyTransfers(userId: string, groupId: string): Promise<MyTransfersResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });
        if (!membership) {
            throw new Error('NOT_GROUP_MEMBER');
        }

        // Transfers where I am the payer (outgoing)
        const outgoingTransfers = await Transfer.find({
            groupId,
            fromUserId: userId
        }).sort({ createdAt: -1 });

        // Transfers where I am the receiver (incoming - others owe me)
        const incomingTransfers = await Transfer.find({
            groupId,
            toUserId: userId,
            status: 'PENDING'
        }).sort({ createdAt: -1 });

        const pending: TransferResponse[] = [];
        const completed: TransferResponse[] = [];
        const pendingIncoming: TransferResponse[] = [];

        for (const transfer of outgoingTransfers) {
            const response = await this.getTransferById(transfer._id.toString());
            if (response) {
                if (transfer.status === 'PENDING') {
                    pending.push(response);
                } else if (transfer.status === 'COMPLETED') {
                    completed.push(response);
                }
            }
        }

        for (const transfer of incomingTransfers) {
            const response = await this.getTransferById(transfer._id.toString());
            if (response) {
                pendingIncoming.push(response);
            }
        }

        return { pending, completed, pendingIncoming };
    },

    /**
     * Initiate payment - send OTP to user's email
     */
    async initiatePayment(userId: string, transferId: string): Promise<InitiatePaymentResponse> {
        const transfer = await Transfer.findById(transferId);

        if (!transfer) {
            throw new Error('Transfer not found');
        }

        // Only the debtor can pay
        if (transfer.fromUserId !== userId) {
            throw new Error('You can only pay your own transfers');
        }

        if (transfer.status === 'COMPLETED') {
            throw new Error('Transfer is already completed');
        }

        // Check user balance
        const user = await User.findById(userId);
        if (!user) {
            throw new Error('User not found');
        }

        if (Number(user.balance) < transfer.amount) {
            throw new Error(`Insufficient balance. Required: ${transfer.amount.toLocaleString()} VND, Available: ${Number(user.balance).toLocaleString()} VND`);
        }

        // Generate and save OTP
        const otp = generateOTP();
        const otpExpiresAt = new Date(Date.now() + 5 * 60 * 1000); // 5 minutes

        await Transfer.findByIdAndUpdate(transferId, {
            otp,
            otpExpiresAt,
            otpVerified: false
        });

        // Send OTP email
        try {
            await emailService.sendOTPEmail(user.email, otp);
        } catch (error) {
            console.error('Failed to send OTP email:', error);
            // Continue anyway - user can request resend
        }

        return {
            transferId,
            message: `OTP sent to ${user.email}. Valid for 5 minutes.`,
            otpExpiresAt
        };
    },

    /**
     * Verify OTP and complete payment
     */
    async verifyOTPAndPay(userId: string, transferId: string, otp: string, categoryTagId?: string): Promise<PaymentCompleteResponse> {
        const transfer = await Transfer.findById(transferId);
        if (!transfer) {
            throw new Error('Transfer not found');
        }

        if (transfer.fromUserId !== userId) {
            throw new Error('You can only pay your own transfers');
        }

        if (transfer.status === 'COMPLETED') {
            throw new Error('Transfer is already completed');
        }

        if (!transfer.otp || !transfer.otpExpiresAt) {
            throw new Error('No OTP requested. Please initiate payment first.');
        }

        if (transfer.otpExpiresAt < new Date()) {
            throw new Error('OTP has expired. Please request a new OTP.');
        }

        if (transfer.otp !== otp) {
            throw new Error('Invalid OTP');
        }

        const fromUser = await User.findById(transfer.fromUserId);
        const toUser = await User.findById(transfer.toUserId);

        if (!fromUser || !toUser) {
            throw new Error('User not found');
        }

        const amount = Number(transfer.amount);
        let newFromBalance = 0;
        let newToBalance = 0;

        const allocations = await TransferDebtAllocation.find({ transferId });

        const session = await mongoose.startSession();

        try {
            await session.withTransaction(async () => {
                const lockedTransfer = await Transfer.findOneAndUpdate(
                    {
                        _id: transferId,
                        status: 'PENDING',
                        otp,
                        otpExpiresAt: { $gt: new Date() }
                    },
                    {
                        status: 'COMPLETED',
                        paidAt: new Date(),
                        otp: null,
                        otpVerified: true,
                        categoryTagId: categoryTagId ?? null
                    },
                    { session, new: false }
                );

                if (!lockedTransfer) {
                    throw new Error('Transfer already processed or OTP invalid');
                }

                const fromUserDoc = await User.findOneAndUpdate(
                    { _id: transfer.fromUserId, balance: { $gte: amount } },
                    { $inc: { balance: -amount } },
                    { session, new: false }
                );

                if (!fromUserDoc) {
                    throw new Error('Insufficient balance');
                }

                const toUserDoc = await User.findOneAndUpdate(
                    { _id: transfer.toUserId },
                    { $inc: { balance: amount } },
                    { session, new: false }
                );

                if (!toUserDoc) {
                    throw new Error('Recipient not found');
                }

                // CRITICAL: Validate allocations and reduce debts
                // For multi-hop (graph-based) allocations, the total sum may exceed
                // the transfer amount because intermediate chain debts are also reduced.
                // Validate by checking only the payer's outgoing debt allocations.
                if (allocations.length > 0) {
                    const { OriginalDebt } = await import('../models/OriginalDebt');
                    const allocDebtIds = [...new Set(allocations.map(a => a.originalDebtId))];
                    const allocDebts = await OriginalDebt.find({ _id: { $in: allocDebtIds } }).session(session);
                    const debtMap = new Map(allocDebts.map(d => [d._id.toString(), d]));

                    const payerAllocated = allocations
                        .filter(a => {
                            const debt = debtMap.get(a.originalDebtId);
                            return debt && debt.debtorId === transfer.fromUserId;
                        })
                        .reduce((sum, a) => sum + a.allocatedAmount, 0);

                    if (Math.abs(payerAllocated - amount) > 0.01) {
                        console.error('[ERROR] Transfer allocation mismatch:', {
                            transferId,
                            transferAmount: amount,
                            payerAllocated,
                            totalAllocations: allocations.length,
                        });
                        throw new Error(`Payer allocation sum (${payerAllocated}) != transfer amount (${amount})`);
                    }

                    // Reduce ALL allocated debts (direct + intermediate hops)
                    for (const alloc of allocations) {
                        await originalDebtService.reduceDebt(alloc.originalDebtId, alloc.allocatedAmount, session);
                    }
                } else {
                    // Fallback for migrated transfers (from settlements) that don't have allocation records
                    await originalDebtService.reduceDebtsBetweenUsers(transfer.groupId, transfer.fromUserId, transfer.toUserId, amount, session);
                }

                newFromBalance = Number(fromUserDoc.balance) - amount;
                newToBalance = Number(toUserDoc.balance) + amount;
            });

            await transactionService.createTransaction({
                userId: fromUser._id.toString(),
                groupId: transfer.groupId,
                type: TransactionType.TRANSFER_SENT,
                amount: amount,
                balanceBefore: newFromBalance + amount,
                balanceAfter: newFromBalance,
                currency: 'VND',
                description: `Payment to ${toUser.displayName}`,
                referenceId: transferId,
                referenceType: 'TRANSFER'
            });

            await transactionService.createTransaction({
                userId: toUser._id.toString(),
                groupId: transfer.groupId,
                type: TransactionType.TRANSFER_RECEIVED,
                amount: amount,
                balanceBefore: newToBalance - amount,
                balanceAfter: newToBalance,
                currency: 'VND',
                description: `Received from ${fromUser.displayName}`,
                referenceId: transferId,
                referenceType: 'TRANSFER'
            });
        } finally {
            session.endSession();
        }

        await paymentRequestService.updateRequestStatus(transfer.paymentRequestId);

        // Send notification to receiver about payment received
        await notificationService.createNotification({
            userId: transfer.toUserId,
            type: NotificationType.PAYMENT_RECEIVED,
            title: 'Payment Received',
            message: `${fromUser.displayName || 'Someone'} sent you ${amount.toLocaleString()} VND`,
            data: {
                transferId,
                groupId: transfer.groupId,
                amount,
                fromUserId: fromUser._id.toString()
            }
        });

        const updatedTransfer = await this.getTransferById(transferId);

        return {
            success: true,
            message: 'Payment completed successfully',
            transfer: updatedTransfer!,
            newBalance: newFromBalance
        };
    },

    /**
     * Resend OTP for a transfer
     */
    async resendOTP(userId: string, transferId: string): Promise<InitiatePaymentResponse> {
        return this.initiatePayment(userId, transferId);
    },

    /**
     * Get transfers by payment request
     */
    async getTransfersByRequest(requestId: string): Promise<TransferResponse[]> {
        const transfers = await Transfer.find({ paymentRequestId: requestId });

        return Promise.all(
            transfers.map(t => this.getTransferById(t._id.toString()))
        ).then(results => results.filter((r): r is TransferResponse => r !== null));
    },

    /**
     * Update transfer status (used by VNPay webhooks)
     */
    async updateTransferStatus(transferId: string, status: TransferStatus, vnpayTxnRef?: string): Promise<TransferResponse> {
        const transfer = await Transfer.findById(transferId);

        if (!transfer) {
            throw new Error('Transfer not found');
        }

        if (status === 'COMPLETED' && transfer.status !== 'COMPLETED') {
            const [fromUser, toUser] = await Promise.all([
                User.findById(transfer.fromUserId),
                User.findById(transfer.toUserId)
            ]);

            if (!fromUser || !toUser) {
                throw new Error('User not found');
            }

            const fromUserBalanceBefore = Number(fromUser.balance);
            const toUserBalanceBefore = Number(toUser.balance);
            const amount = Number(transfer.amount);

            const allocations = await TransferDebtAllocation.find({ transferId });

            const session = await mongoose.startSession();
            session.startTransaction();

            try {
                // 1. Update User Balances
                await User.findByIdAndUpdate(
                    transfer.fromUserId,
                    { $inc: { balance: -amount } },
                    { session }
                );

                await User.findByIdAndUpdate(
                    transfer.toUserId,
                    { $inc: { balance: amount } },
                    { session }
                );

                // 2. Update Transfer
                await Transfer.findByIdAndUpdate(
                    transferId,
                    {
                        status,
                        vnpayTxnRef,
                        vnpayTransDate: new Date(),
                        paidAt: new Date()
                    },
                    { session }
                );

                // 3. Reduce original debts
                if (allocations.length > 0) {
                    for (const alloc of allocations) {
                        await originalDebtService.reduceDebt(alloc.originalDebtId, alloc.allocatedAmount, session);
                    }
                } else {
                    // Fallback mechanism for backward compatibility
                    await originalDebtService.reduceDebtsBetweenUsers(transfer.groupId, transfer.fromUserId, transfer.toUserId, amount, session);
                }

                await session.commitTransaction();
            } catch (error) {
                await session.abortTransaction();
                throw error;
            } finally {
                session.endSession();
            }

            // Update PaymentRequest status
            await paymentRequestService.updateRequestStatus(transfer.paymentRequestId);

            const toUserName = toUser.displayName || toUser.email || 'Unknown';
            const fromUserName = fromUser.displayName || fromUser.email || 'Unknown';

            await transactionService.createTransaction({
                userId: transfer.fromUserId,
                groupId: transfer.groupId,
                type: TransactionType.TRANSFER_SENT,
                amount: amount,
                balanceBefore: fromUserBalanceBefore,
                balanceAfter: fromUserBalanceBefore - amount,
                currency: 'VND',
                description: `Paid debt to ${toUserName} (VNPay)`,
                referenceId: transferId,
                referenceType: 'TRANSFER',
                metadata: vnpayTxnRef ? { vnpayTxnRef } : undefined
            });

            await transactionService.createTransaction({
                userId: transfer.toUserId,
                groupId: transfer.groupId,
                type: TransactionType.TRANSFER_RECEIVED,
                amount: amount,
                balanceBefore: toUserBalanceBefore,
                balanceAfter: toUserBalanceBefore + amount,
                currency: 'VND',
                description: `Received from ${fromUserName} (VNPay)`,
                referenceId: transferId,
                referenceType: 'TRANSFER',
                metadata: vnpayTxnRef ? { vnpayTxnRef } : undefined
            });

            // Need to notify the user
            await notificationService.createNotification({
                userId: transfer.toUserId,
                type: NotificationType.PAYMENT_RECEIVED,
                title: 'Payment Received via VNPay',
                message: `${fromUserName} sent you ${amount.toLocaleString()} VND via VNPay`,
                data: {
                    transferId,
                    groupId: transfer.groupId,
                    amount,
                    fromUserId: fromUser._id.toString()
                }
            });

        } else {
            await Transfer.findByIdAndUpdate(transferId, { status, vnpayTxnRef });
        }

        const result = await this.getTransferById(transferId);
        if (!result) {
            throw new Error('Transfer not found after update');
        }
        return result;
    }
};
