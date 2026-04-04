import { Request, Response } from 'express';
import { authService } from '../service/authService';
import { twoFactorService } from '../service/twoFactorService';
import { SignUpRequest, LoginRequest, VerifyOTPRequest, ResetPasswordRequest, VeriftEmailRequest, AuthResponse } from '../type/auth';
import { ResponseUtil } from '../util/responseUtil';
import { recordLoginFailure, recordLoginSuccess } from '../middleware/loginGuardMiddleware';

export const authController = {
    async signUp(req: Request<{}, {}, SignUpRequest>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { email, password, displayName } = req.body;
            if (!email || !password) {
                return ResponseUtil.validationError(res, 'Email and password are required');
            }
            const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
            if (!emailRegex.test(email)) {
                return ResponseUtil.validationError(res, 'Invalid email format');
            }

            const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
            if (!passwordRegex.test(password)) {
                return ResponseUtil.validationError(res, 'Password must be at least 8 characters with uppercase, lowercase, number and special character');
            }

            const result = await authService.SignUpUser(email, password, displayName);
            ResponseUtil.created(res, { user: result }, 'Account created successfully');

        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create account');
        }
    },
    async verifyOTP(req: Request<{}, {}, VerifyOTPRequest>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { email, otp } = req.body;
            if (!email || !otp) {
                return ResponseUtil.validationError(res, 'Email and OTP are required');
            }
            const result = await authService.verifyOTP(email, otp);
            ResponseUtil.success(res, { user: result }, 'OTP verified successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Invalid or expired OTP');
        }
    },
    async resendOTP(req: Request<{}, {}, { email: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { email } = req.body;
            if (!email) {
                return ResponseUtil.validationError(res, 'Email is required');
            }
            const result = await authService.resendOTP(email);
            ResponseUtil.success(res, null, 'OTP resent successfully. Please check your email.');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to resend OTP');
        }
    },

    async loginUser(req: Request<{}, {}, LoginRequest>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { email, password } = req.body;
            if (!email || !password) {
                return ResponseUtil.validationError(res, 'Email and password are required');
            }
            const result = await authService.loginUser(email, password);
            await recordLoginSuccess(req);

            // If 2FA is required, return tempToken instead of full auth
            if (result.requires2FA) {
                ResponseUtil.success(res, {
                    requires2FA: true,
                    tempToken: result.tempToken,
                    user: result.user,
                }, 'Two-factor authentication required');
                return;
            }

            ResponseUtil.success(res, { user: result }, 'Login successful');
        } catch (error) {
            const failure = await recordLoginFailure(req);
            if (failure.blocked) {
                res.setHeader('Retry-After', failure.retryAfterSec);
                return ResponseUtil.error(
                    res,
                    `Too many failed attempts. Please wait ${failure.retryAfterSec}s before retrying.`,
                    429,
                    'LOGIN_RATE_LIMIT'
                );
            }

            ResponseUtil.handleError(res, error, 'Invalid email or password');
        }
    },
    async resetPassword(req: Request<{}, {}, ResetPasswordRequest>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { email, newPassword } = req.body;
            if (!email || !newPassword) {
                return ResponseUtil.validationError(res, 'Email and new password are required');
            }
            const user = await authService.resetPassword(email, newPassword);
            ResponseUtil.success(res, { user }, 'Password reset successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to reset password');
        }
    },
    async getCurrentUser(req: Request, res: Response<AuthResponse>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const user = await authService.getUserProfilebyID(req.user.userId);
            ResponseUtil.success(res, { user }, 'User profile retrieved successfully');
        }
        catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get user profile');
        }
    },

    async updateProfile(req: Request<{}, {}, { displayName?: string, avatarUrl?: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { displayName, avatarUrl } = req.body;
            const updatedUser = await authService.updateProfile(req.user.userId, { displayName, avatarUrl });
            ResponseUtil.success(res, { user: updatedUser }, 'Profile updated successfully');
        }
        catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update profile');
        }
    },

    // Forgot Password - Send OTP
    async forgotPassword(req: Request<{}, {}, { email: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { email } = req.body;
            if (!email) {
                return ResponseUtil.validationError(res, 'Email is required');
            }
            const result = await authService.forgotPasswordOTP(email);
            ResponseUtil.success(res, null, result);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to send password reset OTP');
        }
    },

    // Verify Reset OTP
    async verifyResetOTP(req: Request<{}, {}, { email: string; otp: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { email, otp } = req.body;
            if (!email || !otp) {
                return ResponseUtil.validationError(res, 'Email and OTP are required');
            }
            const result = await authService.verifyResetOTP(email, otp);
            ResponseUtil.success(res, { resetToken: result.resetToken }, 'Reset OTP verified successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Invalid or expired reset OTP');
        }
    },

    // Reset Password with Token
    async resetPasswordWithToken(req: Request<{}, {}, { resetToken: string; newPassword: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            const { resetToken, newPassword } = req.body;
            if (!resetToken || !newPassword) {
                return ResponseUtil.validationError(res, 'Reset token and new password are required');
            }
            const result = await authService.resetPasswordWithToken(resetToken, newPassword);
            ResponseUtil.success(res, null, result.message);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to reset password');
        }
    },

    // Change Password - Initiate (Verify old, check new, send OTP)
    async initiateChangePassword(req: Request<{}, {}, { oldPassword: string; newPassword: string; totpToken?: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { oldPassword, newPassword, totpToken } = req.body;
            if (!oldPassword || !newPassword) {
                return ResponseUtil.validationError(res, 'Old and new passwords are required');
            }
            // Password strength check
            const passwordRegex = /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
            if (!passwordRegex.test(newPassword)) {
                return ResponseUtil.validationError(res, 'New password must be at least 8 characters with uppercase, lowercase, number and special character');
            }

            // 2FA guard
            await twoFactorService.verify2FAIfEnabled(req.user.userId, totpToken);

            const result = await authService.initiateChangePassword(req.user.userId, oldPassword, newPassword);
            ResponseUtil.success(res, null, result);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to initiate password change');
        }
    },

    // Change Password - Confirm (Verify OTP and update)
    async confirmChangePassword(req: Request<{}, {}, { otp: string; newPassword: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { otp, newPassword } = req.body;
            if (!otp || !newPassword) {
                return ResponseUtil.validationError(res, 'OTP and new password are required');
            }
            const result = await authService.confirmChangePassword(req.user.userId, otp, newPassword);
            ResponseUtil.success(res, null, result);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to confirm password change');
        }
    },

    // Contact Us
    async contactUs(req: Request<{}, {}, { subject: string; message: string }>, res: Response<AuthResponse>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { subject, message } = req.body;
            if (!subject || !message) {
                return ResponseUtil.validationError(res, 'Subject and message are required');
            }
            const result = await authService.contactUs(req.user.userId, subject, message);
            ResponseUtil.success(res, null, result);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to send message');
        }
    }
};
