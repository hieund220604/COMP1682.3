export interface CreatePaymentRequest {
    transferId: string;
    returnUrl: string;
}

export interface PaymentResponse {
    paymentUrl: string;
    transferId: string;
    txnRef: string;
    amount: number;
}

export interface VNPayReturnParams {
    vnp_TmnCode?: string;
    vnp_Amount?: string;
    vnp_BankCode?: string;
    vnp_BankTranNo?: string;
    vnp_CardType?: string;
    vnp_PayDate?: string;
    vnp_OrderInfo?: string;
    vnp_TransactionNo?: string;
    vnp_ResponseCode?: string;
    vnp_TransactionStatus?: string;
    vnp_TxnRef?: string;
    vnp_SecureHashType?: string;
    vnp_SecureHash?: string;
}

export interface VNPayIPNParams extends VNPayReturnParams { }

export interface VNPayConfig {
    tmnCode: string;
    secureSecret: string;
    vnpayHost: string;
    returnUrl: string;
    testMode: boolean;
}
