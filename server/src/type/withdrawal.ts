export interface CreateWithdrawalRequest {
    amount: number;
    accountNumber: string;
    bankName: string;
    accountName: string;
    totpToken?: string;
}

export interface VerifyOtpRequest {
    withdrawalId: string;
    otp: string;
}

export interface WithdrawalResponse {
    id: string;
    userId: string;
    amount: number;
    currency: string;
    accountNumber: string;
    bankName: string;
    accountName: string;
    status: string;
    otpExpiresAt?: Date;
    verifiedAt?: Date;
    createdAt: Date;
}

export interface WithdrawalSuccessResponse {
    id: string;
    status: string;
    message: string;
}
