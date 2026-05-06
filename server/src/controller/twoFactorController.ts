import { Request, Response } from 'express';
import jwt from 'jsonwebtoken';
import { twoFactorService } from '../service/twoFactorService';
import { authService } from '../service/authService';
import { ResponseUtil } from '../util/responseUtil';
import { JWTPayLoad } from '../type/auth';
import { User } from '../models/User';

export const twoFactorController = {
    /**
     * POST /auth/2fa/setup
     * Generate QR code and manual key for 2FA setup.
     * Requires auth (user must be logged in).
     */
    async setup(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const result = await twoFactorService.generateSetup(userId);
            ResponseUtil.success(res, result, 'Two-factor setup initiated');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to setup 2FA');
        }
    },

    /**
     * POST /auth/2fa/verify-setup
     * Verify TOTP code to complete 2FA setup.
     * Body: { token: "123456" }
     */
    async verifySetup(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            let { token } = req.body;
            if (!token) {
                return ResponseUtil.validationError(res, 'Verification code is required');
            }

            // Trim whitespace from token
            token = String(token).trim();
            console.log('[2FA Setup Verify] Token received:', token, 'Length:', token.length);

            const result = await twoFactorService.verifyAndEnable(userId, token);
            ResponseUtil.success(res, result, 'Two-factor authentication enabled successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to verify 2FA setup');
        }
    },

    /**
     * POST /auth/2fa/verify
     * Verify TOTP code during login (uses tempToken instead of full auth).
     * Body: { tempToken: "...", token: "123456" }
     */
    async verifyLogin(req: Request, res: Response): Promise<void> {
        try {
            let { tempToken, token } = req.body;
            if (!tempToken || !token) {
                return ResponseUtil.validationError(res, 'Temporary token and verification code are required');
            }

            // Trim whitespace from token
            token = String(token).trim();
            console.log('[2FA Login Verify] Token received:', token, 'Length:', token.length);

            // Verify the temp token
            let decoded: JWTPayLoad;
            try {
                decoded = jwt.verify(tempToken, process.env.JWT_SECRET || 'default_secret') as JWTPayLoad;
            } catch {
                return ResponseUtil.unauthorized(res, 'Invalid or expired temporary token. Please login again.');
            }

            if (!decoded.pending2FA) {
                return ResponseUtil.unauthorized(res, 'Invalid token type');
            }

            // Verify TOTP
            const isValid = await twoFactorService.verify(decoded.userId, token);
            if (!isValid) {
                return ResponseUtil.error(res, 'Invalid verification code', 401);
            }

            // Fetch user for response
            const user = await User.findById(decoded.userId);
            if (!user) {
                return ResponseUtil.error(res, 'User not found', 404);
            }

            // Issue full JWT + refresh token
            const fullToken = authService.generateToken(decoded.userId, decoded.email);
            const refreshToken = authService.generateRefreshToken();
            await authService.storeRefreshToken(decoded.userId, refreshToken);

            ResponseUtil.success(res, {
                user: {
                    userId: user._id.toString(),
                    email: user.email,
                    displayName: user.displayName,
                    avatarUrl: user.avatarUrl,
                    balance: user.balance,
                    currency: user.currency,
                    twoFactorEnabled: user.twoFactorEnabled,
                },
                token: fullToken,
                refreshToken,
            }, 'Two-factor verification successful');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to verify 2FA');
        }
    },

    /**
     * POST /auth/2fa/disable
     * Disable 2FA. Requires auth + valid TOTP code.
     * Body: { token: "123456" }
     */
    async disable(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            let { token } = req.body;
            if (!token) {
                return ResponseUtil.validationError(res, 'Verification code is required');
            }

            // Trim whitespace from token
            token = String(token).trim();
            console.log('[2FA Disable] Token received:', token, 'Length:', token.length);

            await twoFactorService.disable(userId, token);
            ResponseUtil.success(res, null, 'Two-factor authentication disabled');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to disable 2FA');
        }
    },

    /**
     * GET /auth/2fa/status
     * Check if 2FA is enabled for the current user.
     */
    async status(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const enabled = await twoFactorService.isEnabled(userId);
            ResponseUtil.success(res, { twoFactorEnabled: enabled }, 'Two-factor status retrieved');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get 2FA status');
        }
    },
};
