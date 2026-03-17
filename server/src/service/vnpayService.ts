import crypto from 'crypto';
import { transferService } from './transferService';
import { accountService } from './accountService';
import { PaymentResponse } from '../type/vnpay';
import { Transfer } from '../models/Transfer';
import { TopUp } from '../models/TopUp';

const formatVNPayDate = (date: Date): string => {
    const gmt7Date = new Date(date.getTime() + 7 * 60 * 60 * 1000);
    const year = gmt7Date.getUTCFullYear();
    const month = String(gmt7Date.getUTCMonth() + 1).padStart(2, '0');
    const day = String(gmt7Date.getUTCDate()).padStart(2, '0');
    const hour = String(gmt7Date.getUTCHours()).padStart(2, '0');
    const minute = String(gmt7Date.getUTCMinutes()).padStart(2, '0');
    const second = String(gmt7Date.getUTCSeconds()).padStart(2, '0');
    return `${year}${month}${day}${hour}${minute}${second}`;
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

const VNPAY_VERSION = '2.1.0';
const VNPAY_COMMAND = 'pay';
const VNPAY_CURR_CODE = 'VND';
const VNPAY_LOCALE = 'vn';
const VNPAY_ORDER_TYPE = 'other';

const getVNPayPaymentUrl = (): string => {
    const paymentUrl = process.env.VNPAY_PAYMENT_URL?.trim() || process.env.VNPAY_URL?.trim() || 'https://sandbox.vnpayment.vn/paymentv2/vpcpay.html';

    try {
        const parsed = new URL(paymentUrl);
        if (!/^https?:$/.test(parsed.protocol)) {
            throw new Error('invalid protocol');
        }
    } catch (_error) {
        throw new Error('VNPAY_URL/VNPAY_PAYMENT_URL is invalid. Please provide a valid absolute URL.');
    }

    return paymentUrl;
};

const getVNPayTmnCode = (): string => {
    const tmnCode = process.env.VNPAY_TMN_CODE?.trim();
    if (!tmnCode) {
        throw new Error('VNPAY_TMN_CODE is required');
    }

    if (!/^[A-Za-z0-9]{8}$/.test(tmnCode)) {
        throw new Error('VNPAY_TMN_CODE is invalid. Expected 8 alphanumeric characters.');
    }

    return tmnCode;
};

const getVNPaySecret = (): string => {
    const secret = process.env.VNPAY_HASH_SECRET?.trim();
    if (!secret) {
        throw new Error('VNPAY_HASH_SECRET is required');
    }

    return secret;
};

const vnpEncode = (value: string): string => {
    return encodeURIComponent(value).replace(/%20/g, '+');
};

const sortVnpParams = (params: Record<string, string>): Record<string, string> => {
    const filtered = Object.entries(params)
        .filter(([_key, value]) => value !== undefined && value !== null && value !== '')
        .map(([key, value]) => [key, value]);

    return Object.fromEntries(filtered.sort(([a], [b]) => a.localeCompare(b)));
};

const buildSignData = (params: Record<string, string>): string => {
    return Object.entries(sortVnpParams(params))
        .map(([key, value]) => `${vnpEncode(key)}=${vnpEncode(value)}`)
        .join('&');
};

const createSecureHash = (params: Record<string, string>): string => {
    const signData = buildSignData(params);
    return crypto
        .createHmac('sha512', getVNPaySecret())
        .update(signData, 'utf-8')
        .digest('hex');
};

const buildPaymentUrl = (params: Record<string, string>): string => {
    const queryString = buildSignData(params);
    const secureHash = createSecureHash(params);
    return `${getVNPayPaymentUrl()}?${queryString}&vnp_SecureHash=${secureHash}`;
};

const verifySecureHash = (query: Record<string, string>): boolean => {
    const receivedHash = (query.vnp_SecureHash || '').toLowerCase();
    if (!receivedHash) {
        return false;
    }

    const payload = { ...query };
    delete payload.vnp_SecureHash;
    delete payload.vnp_SecureHashType;

    const calculatedHash = createSecureHash(payload).toLowerCase();
    return calculatedHash === receivedHash;
};

const isPaymentSuccess = (query: Record<string, string>): boolean => {
    return query.vnp_ResponseCode === '00' && query.vnp_TransactionStatus === '00';
};

const shouldProcessOnReturnUrl = (): boolean => {
    if (process.env.VNPAY_PROCESS_ON_RETURN_URL === 'true') {
        return true;
    }
    if (process.env.VNPAY_PROCESS_ON_RETURN_URL === 'false') {
        return false;
    }

    return process.env.NODE_ENV !== 'production';
};

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
        const paymentUrl = buildPaymentUrl({
            vnp_Version: VNPAY_VERSION,
            vnp_Command: VNPAY_COMMAND,
            vnp_TmnCode: getVNPayTmnCode(),
            vnp_Amount: resolveAmountForVNPay(transfer.amount).toString(),
            vnp_CreateDate: formatVNPayDate(new Date()),
            vnp_CurrCode: VNPAY_CURR_CODE,
            vnp_IpAddr: ipAddr,
            vnp_Locale: VNPAY_LOCALE,
            vnp_OrderInfo: normalizeOrderInfo(`Thanh toan transfer ${transferId}`),
            vnp_OrderType: VNPAY_ORDER_TYPE,
            vnp_ReturnUrl: returnUrl,
            vnp_TxnRef: txnRef,
            vnp_ExpireDate: formatVNPayDate(new Date(Date.now() + 15 * 60 * 1000)),
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

        const paymentUrl = buildPaymentUrl({
            vnp_Version: VNPAY_VERSION,
            vnp_Command: VNPAY_COMMAND,
            vnp_TmnCode: getVNPayTmnCode(),
            vnp_Amount: resolveAmountForVNPay(amount).toString(),
            vnp_CreateDate: formatVNPayDate(new Date()),
            vnp_CurrCode: VNPAY_CURR_CODE,
            vnp_IpAddr: ipAddr,
            vnp_Locale: VNPAY_LOCALE,
            vnp_OrderInfo: normalizeOrderInfo(`Nap tien tai khoan ${topUpId}`),
            vnp_OrderType: VNPAY_ORDER_TYPE,
            vnp_ReturnUrl: returnUrl,
            vnp_TxnRef: txnRef,
            vnp_ExpireDate: formatVNPayDate(new Date(Date.now() + 15 * 60 * 1000)),
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
            if (!verifySecureHash(query)) {
                return { isValid: false, message: 'Invalid signature' };
            }

            const txnRef = query.vnp_TxnRef;
            if (!txnRef) {
                return { isValid: false, message: 'Missing vnp_TxnRef' };
            }

            if (!isPaymentSuccess(query)) {
                return { isValid: false, message: 'Payment failed' };
            }

            if (txnRef.startsWith('TU')) {
                const topUp = await TopUp.findOne({ vnpayTxnRef: txnRef });

                if (!topUp) {
                    return { isValid: false, message: 'Top-up transaction not found' };
                }

                if (shouldProcessOnReturnUrl() && topUp.status === 'PENDING') {
                    await accountService.completeTopUp(topUp._id.toString(), txnRef);
                }

                return {
                    isValid: true,
                    transferId: topUp._id.toString(),
                    message: 'Top-up verification successful'
                };
            }

            const transfer = await Transfer.findOne({ vnpayTxnRef: txnRef });

            if (!transfer) {
                return { isValid: false, message: 'Transfer not found' };
            }

            if (shouldProcessOnReturnUrl() && transfer.status === 'PENDING') {
                await transferService.updateTransferStatus(transfer._id.toString(), 'COMPLETED', txnRef);
            }

            return {
                isValid: true,
                transferId: transfer._id.toString(),
                message: 'Payment verification successful'
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
            if (!verifySecureHash(query)) {
                return { RspCode: '97', Message: 'Fail checksum' };
            }

            const txnRef = query.vnp_TxnRef;
            if (!txnRef) {
                return { RspCode: '01', Message: 'Order not found' };
            }

            const vnpAmount = Number.parseInt(query.vnp_Amount || '0', 10);
            const success = isPaymentSuccess(query);

            if (txnRef.startsWith('TU')) {
                const topUp = await TopUp.findOne({ vnpayTxnRef: txnRef });

                if (!topUp) {
                    return { RspCode: '01', Message: 'Top-up not found' };
                }

                if (topUp.status !== 'PENDING') {
                    return { RspCode: '02', Message: 'Top-up already confirmed' };
                }

                if (resolveAmountForVNPay(Number(topUp.amount)) !== vnpAmount) {
                    return { RspCode: '04', Message: 'Invalid amount' };
                }

                if (success) {
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

            if (transfer.status !== 'PENDING') {
                return { RspCode: '02', Message: 'Order already confirmed' };
            }

            if (resolveAmountForVNPay(Number(transfer.amount)) !== vnpAmount) {
                return { RspCode: '04', Message: 'Invalid amount' };
            }

            if (success) {
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
