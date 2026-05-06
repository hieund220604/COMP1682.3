import e from "express";

export interface SignUpRequest {
    email: string;
    password: string;
    displayName?: string
}

export interface LoginRequest {
    email: string;
    password: string;
}

export interface VerifyOTPRequest {
    email: string;
    otp: string;
}

export interface ResetPasswordRequest {
    email: string;
    newPassword: string;
}

export interface VeriftEmailRequest {
    email: string;
    otp: string;
}

export interface AuthResponse {
    success: boolean;
    message: string;
    data?: {
        token?: string;
        refreshToken?: string;
        resetToken?: string;
        user?: {
            id: string;
            email: string;
            displayName?: string;
        };
    };

    error?: string;
}

export interface JWTPayLoad {
    userId: string;
    email: string;
    pending2FA?: boolean;
    iat?: number;
    exp?: number;
}

export interface TwoFactorSetupResponse {
    qrCodeUrl: string;
    manualKey: string;
}

export interface TwoFactorVerifyRequest {
    token: string;
}

export interface TwoFactorLoginRequest {
    tempToken: string;
    token: string;
}

export interface OTPRecord {
    email: string;
    otp: string;
    createdAt: Date;
    expiresAt: Date;
    attemptCount: number;
}