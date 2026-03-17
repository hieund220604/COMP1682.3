import { VNPay, ProductCode, VnpLocale, HashAlgorithm } from 'vnpay';
import { transferService } from './transferService';
import { accountService } from './accountService';
import { PaymentResponse } from '../type/vnpay';
import { Transfer } from '../models/Transfer';
import { TopUp } from '../models/TopUp';

const formatVNPayDate = (date: Date): string => {
    const formatter = new Intl.DateTimeFormat('en-GB', {
        timeZone: 'Asia/Ho_Chi_Minh',
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit',
        second: '2-digit',
        hour12: false,
    });

    const parts = formatter.formatToParts(date);
    const partMap = Object.fromEntries(parts.map((part) => [part.type, part.value]));
    return `${partMap.year}${partMap.month}${partMap.day}${partMap.hour}${partMap.minute}${partMap.second}`;
};

const normalizeOrderInfo = (value: string): string => {
    const withoutAccent = value.normalize('NFD').replace(/[\u0300-\u036f]/g, '');
    const normalized = withoutAccent
        .replace(/[^a-zA-Z0-9 ]/g, ' ')
        .replace(/\s+/g, ' ')
        .trim();

    return normalized.slice(0, 255) || 'Thanh toan don hang';
};

const resolveAmountForVNPay = (amount: number): number => {
    const normalized = Math.round(amount * 100);
    if (!Number.isFinite(normalized) || normalized <= 0) {
        throw new Error('Invalid payment amount');
    }
    if (normalized.toString().length > 12) {
        throw new Error('Payment amount exceeds VNPay limit');
    }
    return normalized;
};

const buildTxnRef = (prefix: 'TR' | 'TU', sourceId: string): string => {
    const suffix = sourceId.replace(/[^a-zA-Z0-9]/g, '').slice(-8) || `${prefix}X`;
    return `${prefix}${Date.now()}${suffix}`.slice(0, 100);
};

// Initialize VNPay instance
const vnpay = new VNPay({
    tmnCode: process.env.VNPAY_TMN_CODE || 'DEMO',
    secureSecret: process.env.VNPAY_HASH_SECRET || 'DEMOSECRET',
    vnpayHost: 'https://sandbox.vnpayment.vn',
    testMode: true,
    hashAlgorithm: HashAlgorithm.SHA512,
    enableLog: true
});

export const vnpayService = {
    async createPaymentUrl(transferId: string, returnUrl: string, ipAddr: string): Promise<PaymentResponse> {
        const transfer = await transferService.getTransferById(transferId);

        if (!transfer) {
            throw new Error('Transfer not found');
        }

        if (transfer.status !== 'PENDING') {
            throw new Error('Transfer is not in pending status');
        }

        const txnRef = buildTxnRef('TR', transferId);
        const createDate = Number(formatVNPayDate(new Date()));
        const expireDate = Number(formatVNPayDate(new Date(Date.now() + 15 * 60 * 1000)));

        const paymentUrl = vnpay.buildPaymentUrl({
            vnp_Amount: resolveAmountForVNPay(transfer.amount),
            vnp_IpAddr: ipAddr,
            vnp_TxnRef: txnRef,
            vnp_OrderInfo: normalizeOrderInfo(`Thanh toan transfer ${transferId}`),
            vnp_OrderType: ProductCode.Other,
            vnp_ReturnUrl: returnUrl,
            vnp_Locale: VnpLocale.VN,
            vnp_CreateDate: createDate,
            vnp_ExpireDate: expireDate,
        });

        await Transfer.findByIdAndUpdate(transferId, { vnpayTxnRef: txnRef });

        return {
            paymentUrl,
            transferId,
            txnRef,
            amount: transfer.amount
        };
    },

    async createTopUpUrl(topUpId: string, amount: number, returnUrl: string, ipAddr: string): Promise<PaymentResponse> {
        const txnRef = buildTxnRef('TU', topUpId);
        const createDate = Number(formatVNPayDate(new Date()));
        const expireDate = Number(formatVNPayDate(new Date(Date.now() + 15 * 60 * 1000)));

        const paymentUrl = vnpay.buildPaymentUrl({
            vnp_Amount: resolveAmountForVNPay(amount),
            vnp_IpAddr: ipAddr,
            vnp_TxnRef: txnRef,
            vnp_OrderInfo: normalizeOrderInfo(`Nap tien tai khoan ${topUpId}`),
            vnp_OrderType: ProductCode.Other,
            vnp_ReturnUrl: returnUrl,
            vnp_Locale: VnpLocale.VN,
            vnp_CreateDate: createDate,
            vnp_ExpireDate: expireDate,
        });

        await TopUp.findByIdAndUpdate(topUpId, { vnpayTxnRef: txnRef });

        return {
            paymentUrl,
            transferId: topUpId,
            txnRef,
            amount: amount
        };
    },

    async verifyReturnUrl(query: Record<string, string>): Promise<{ isValid: boolean; transferId?: string; message: string }> {
        try {
            const result = vnpay.verifyReturnUrl(query as any);

            if (!result.isVerified) {
                return { isValid: false, message: 'Invalid signature' };
            }

            if (!result.isSuccess) {
                return { isValid: false, message: 'Payment failed' };
            }

            const txnRef = query.vnp_TxnRef;

            if (txnRef.startsWith('TU')) {
                const topUp = await TopUp.findOne({ vnpayTxnRef: txnRef });

                if (!topUp) {
                    return { isValid: false, message: 'Top-up transaction not found' };
                }

                await accountService.completeTopUp(topUp._id.toString(), txnRef);
                return {
                    isValid: true,
                    transferId: topUp._id.toString(),
                    message: 'Top-up successful'
                };
            }

            const transfer = await Transfer.findOne({ vnpayTxnRef: txnRef });

            if (!transfer) {
                return { isValid: false, message: 'Transfer not found' };
            }

            await transferService.updateTransferStatus(transfer._id.toString(), 'COMPLETED', txnRef);

            return {
                isValid: true,
                transferId: transfer._id.toString(),
                message: 'Payment successful'
            };
        } catch (error) {
            return {
                isValid: false,
                message: error instanceof Error ? error.message : 'Verification failed'
            };
        }
    },

    async handleIPN(query: Record<string, string>): Promise<{ RspCode: string; Message: string }> {
        try {
            const verify = vnpay.verifyIpnCall(query as any);

            if (!verify.isVerified) {
                return { RspCode: '97', Message: 'Fail checksum' };
            }

            const txnRef = query.vnp_TxnRef;
            const vnpAmount = parseInt(query.vnp_Amount || '0') / 100;

            if (txnRef.startsWith('TU')) {
                const topUp = await TopUp.findOne({ vnpayTxnRef: txnRef });

                if (!topUp) {
                    return { RspCode: '01', Message: 'Top-up not found' };
                }

                if (topUp.status === 'COMPLETED') {
                    return { RspCode: '02', Message: 'Top-up already confirmed' };
                }

                if (Number(topUp.amount) !== vnpAmount) {
                    return { RspCode: '04', Message: 'Invalid amount' };
                }

                if (verify.isSuccess) {
                    await accountService.completeTopUp(topUp._id.toString(), txnRef);
                } else {
                    await accountService.failTopUp(topUp._id.toString(), txnRef);
                }

                return { RspCode: '00', Message: 'Confirm Success' };
            }

            const transfer = await Transfer.findOne({ vnpayTxnRef: txnRef });

            if (!transfer) {
                return { RspCode: '01', Message: 'Order not found' };
            }

            if (transfer.status === 'COMPLETED') {
                return { RspCode: '02', Message: 'Order already confirmed' };
            }

            if (Number(transfer.amount) !== vnpAmount) {
                return { RspCode: '04', Message: 'Invalid amount' };
            }

            if (verify.isSuccess) {
                await transferService.updateTransferStatus(transfer._id.toString(), 'COMPLETED', txnRef);
            } else {
                await transferService.updateTransferStatus(transfer._id.toString(), 'FAILED', txnRef);
            }

            return { RspCode: '00', Message: 'Confirm Success' };
        } catch (error) {
            console.error('IPN Error:', error);
            return { RspCode: '99', Message: 'Unknown error' };
        }
    }
};
