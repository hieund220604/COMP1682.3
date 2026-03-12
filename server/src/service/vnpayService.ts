import { VNPay, ProductCode, VnpLocale, dateFormat, HashAlgorithm } from 'vnpay';
import { transferService } from './transferService';
import { accountService } from './accountService';
import { TransferStatus } from '../models/Transfer';
import { PaymentResponse } from '../type/vnpay';
import { Transfer } from '../models/Transfer';
import { TopUp } from '../models/TopUp';

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

        const txnRef = `${transferId.substring(0, 8)}_${Date.now()}`;
        const createDate = dateFormat(new Date());

        const paymentUrl = vnpay.buildPaymentUrl({
            vnp_Amount: transfer.amount * 100, // VNPay requires amount in smallest unit (VND * 100)
            vnp_IpAddr: ipAddr,
            vnp_TxnRef: txnRef,
            vnp_OrderInfo: `Thanh toan transfer ${transferId}`,
            vnp_OrderType: ProductCode.Other,
            vnp_ReturnUrl: returnUrl,
            vnp_Locale: VnpLocale.VN,
            vnp_CreateDate: createDate
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
        const txnRef = `TU_${topUpId.substring(0, 8)}_${Date.now()}`;
        const createDate = dateFormat(new Date());

        const paymentUrl = vnpay.buildPaymentUrl({
            vnp_Amount: amount * 100, // VNPay requires amount in smallest unit (VND * 100)
            vnp_IpAddr: ipAddr,
            vnp_TxnRef: txnRef,
            vnp_OrderInfo: `Nap tien tai khoan ${topUpId}`,
            vnp_OrderType: ProductCode.Other,
            vnp_ReturnUrl: returnUrl,
            vnp_Locale: VnpLocale.VN,
            vnp_CreateDate: createDate
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

            if (txnRef.startsWith('TU_')) {
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

            if (txnRef.startsWith('TU_')) {
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
