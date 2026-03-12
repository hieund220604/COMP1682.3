import { User } from '../models/User';
import { Withdrawal } from '../models/Withdrawal';
import { CreateWithdrawalRequest, WithdrawalResponse, WithdrawalSuccessResponse } from '../type/withdrawal';
import { emailService } from './emailService';
import { transactionService } from './transactionService';
import { TransactionType } from '../type/transaction';
import mongoose from 'mongoose';

function generateOTP(): string {
    return Math.floor(100000 + Math.random() * 900000).toString();
}

function transformWithdrawal(withdrawal: any): WithdrawalResponse {
    return {
        id: withdrawal._id.toString(),
        userId: withdrawal.userId,
        amount: Number(withdrawal.amount),
        currency: withdrawal.currency,
        accountNumber: withdrawal.accountNumber,
        bankName: withdrawal.bankName,
        accountName: withdrawal.accountName,
        status: withdrawal.status,
        otpExpiresAt: withdrawal.otpExpiresAt ?? undefined,
        verifiedAt: withdrawal.verifiedAt ?? undefined,
        createdAt: withdrawal.createdAt
    };
}

export const withdrawalService = {
    async initiateWithdrawal(userId: string, data: CreateWithdrawalRequest): Promise<WithdrawalResponse> {
        const user = await User.findById(userId);

        if (!user) {
            throw new Error('User not found');
        }

        const userBalance = Number(user.balance);
        const requestAmount = Number(data.amount);

        if (userBalance < requestAmount) {
            throw new Error(`Insufficient balance. Available: ${userBalance}, Requested: ${requestAmount}`);
        }

        if (requestAmount <= 0) {
            throw new Error('Amount must be greater than 0');
        }

        const otp = generateOTP();
        const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

        const withdrawal = await Withdrawal.create({
            userId,
            amount: data.amount,
            currency: 'VND',
            accountNumber: data.accountNumber,
            bankName: data.bankName,
            accountName: data.accountName,
            status: 'OTP_SENT',
            otp,
            otpExpiresAt
        });

        try {
            await emailService.sendOTPEmail(user.email, otp);
        } catch (error) {
            console.error('Failed to send OTP email:', error);
        }

        return transformWithdrawal(withdrawal);
    },

    async resendOTP(withdrawalId: string, userEmail: string): Promise<WithdrawalSuccessResponse> {
        const withdrawal = await Withdrawal.findById(withdrawalId);

        if (!withdrawal) {
            throw new Error('Withdrawal not found');
        }

        if (withdrawal.status !== 'OTP_SENT' && withdrawal.status !== 'PENDING') {
            throw new Error(`Cannot resend OTP for withdrawal in ${withdrawal.status} status`);
        }

        const otp = generateOTP();
        const otpExpiresAt = new Date(Date.now() + 10 * 60 * 1000);

        await Withdrawal.findByIdAndUpdate(withdrawalId, {
            otp,
            otpExpiresAt,
            status: 'OTP_SENT'
        });

        try {
            await emailService.sendOTPEmail(userEmail, otp);
        } catch (error) {
            console.error('Failed to send OTP email:', error);
        }

        return {
            id: withdrawalId,
            status: 'OTP_SENT',
            message: `OTP sent to ${userEmail}. Valid for 10 minutes.`
        };
    },

    async verifyOTP(withdrawalId: string, otp: string): Promise<any> {
        const withdrawal = await Withdrawal.findById(withdrawalId);

        if (!withdrawal) {
            throw new Error('Withdrawal not found');
        }

        if (withdrawal.status !== 'OTP_SENT') {
            throw new Error(`Cannot verify OTP for withdrawal in ${withdrawal.status} status`);
        }

        if (!withdrawal.otpExpiresAt || withdrawal.otpExpiresAt < new Date()) {
            throw new Error('OTP has expired. Please request a new OTP.');
        }

        if (withdrawal.otp !== otp) {
            throw new Error('Invalid OTP');
        }

        const amount = Number(withdrawal.amount);
        let balanceBefore = 0;
        let balanceAfter = 0;

        const session = await mongoose.startSession();
        try {
            await session.withTransaction(async () => {
                const lockedWithdrawal = await Withdrawal.findOneAndUpdate(
                    {
                        _id: withdrawalId,
                        status: 'OTP_SENT',
                        otp,
                        otpExpiresAt: { $gt: new Date() }
                    },
                    {
                        status: 'COMPLETED',
                        verifiedAt: new Date(),
                        otp: null
                    },
                    { session, new: true }
                );

                if (!lockedWithdrawal) {
                    throw new Error('Invalid or expired OTP');
                }

                const userDoc = await User.findOneAndUpdate(
                    { _id: withdrawal.userId, balance: { $gte: amount } },
                    { $inc: { balance: -amount } },
                    { session, new: false }
                );

                if (!userDoc) {
                    throw new Error('Insufficient balance');
                }

                balanceBefore = Number(userDoc.balance);
                balanceAfter = balanceBefore - amount;
            });
        } finally {
            await session.endSession();
        }

        await transactionService.createTransaction({
            userId: withdrawal.userId,
            type: TransactionType.WITHDRAWAL,
            amount: amount,
            balanceBefore: balanceBefore,
            balanceAfter: balanceAfter,
            currency: 'VND',
            description: `Rut tien ve ${withdrawal.bankName} - ${withdrawal.accountNumber}`,
            referenceId: withdrawalId,
            referenceType: 'WITHDRAWAL'
        });

        const updatedUser = await User.findById(withdrawal.userId);

        return {
            success: true,
            message: 'Withdrawal completed successfully',
            withdrawal: {
                id: withdrawalId,
                amount: amount,
                status: 'COMPLETED',
                accountNumber: withdrawal.accountNumber,
                bankName: withdrawal.bankName,
                accountName: withdrawal.accountName,
                verifiedAt: new Date()
            },
            user: {
                id: updatedUser!._id.toString(),
                balance: Number(updatedUser!.balance)
            }
        };
    },

    async getWithdrawalStatus(withdrawalId: string, userId: string): Promise<WithdrawalResponse> {
        const withdrawal = await Withdrawal.findById(withdrawalId);

        if (!withdrawal) {
            throw new Error('Withdrawal not found');
        }

        if (withdrawal.userId !== userId) {
            throw new Error('Permission denied');
        }

        return transformWithdrawal(withdrawal);
    },

    async getUserWithdrawals(userId: string): Promise<WithdrawalResponse[]> {
        const withdrawals = await Withdrawal.find({ userId }).sort({ createdAt: -1 });

        return withdrawals.map(transformWithdrawal);
    }
};
