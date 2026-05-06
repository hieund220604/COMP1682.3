import speakeasy from 'speakeasy';
import * as QRCode from 'qrcode';
import bcrypt from 'bcryptjs';
import crypto from 'crypto';
import { User } from '../models/User';
import { TwoFactorSetupResponse } from '../type/auth';

const ISSUER = 'SplitPal';
const BACKUP_CODE_COUNT = 8;

function generateBackupCodes(): string[] {
    const codes: string[] = [];
    for (let i = 0; i < BACKUP_CODE_COUNT; i++) {
        // 8-char hex codes like "a3f1b2c4"
        codes.push(crypto.randomBytes(4).toString('hex'));
    }
    return codes;
}

export const twoFactorService = {
    /**
     * Generate 2FA setup data (QR code + manual key).
     * Stores the secret on the user doc but does NOT enable 2FA yet.
     */
    async generateSetup(userId: string): Promise<TwoFactorSetupResponse> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        if (user.twoFactorEnabled) {
            throw new Error('Two-factor authentication is already enabled');
        }

        const secret = speakeasy.generateSecret({
            name: `SplitPal (${user.email})`,
            issuer: ISSUER,
            length: 32,
        });

        console.log('[generateSetup] Generated secret:', secret.base32);
        console.log('[generateSetup] OTP Auth URI:', secret.otpauth_url);

        const qrCodeUrl = await QRCode.toDataURL(secret.otpauth_url!);

        // Store secret (not yet enabled) so verifyAndEnable can validate later
        user.twoFactorSecret = secret.base32;
        await user.save();

        // Verify it was saved
        const savedUser = await User.findById(userId);
        console.log('[generateSetup] Saved secret from DB:', savedUser?.twoFactorSecret);

        return {
            qrCodeUrl,
            manualKey: secret.base32,
        };
    },

    /**
     * Verify the TOTP code during setup and enable 2FA.
     * Returns one-time backup codes.
     */
    async verifyAndEnable(userId: string, token: string): Promise<{ backupCodes: string[] }> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        if (user.twoFactorEnabled) {
            throw new Error('Two-factor authentication is already enabled');
        }

        if (!user.twoFactorSecret) {
            throw new Error('Please initiate 2FA setup first');
        }

        console.log('[verifyAndEnable] Token:', token, 'Secret:', user.twoFactorSecret);
        console.log('[verifyAndEnable] Secret length:', user.twoFactorSecret?.length);

        // Debug: Check what code speakeasy generates for current time
        const currentTime = Math.floor(Date.now() / 1000);
        const generatedCodes = [];
        for (let i = -2; i <= 2; i++) {
            const timeStep = Math.floor((currentTime + (i * 30)) / 30);
            const code = speakeasy.totp({
                secret: user.twoFactorSecret,
                encoding: 'base32',
                time: currentTime + (i * 30),
            });
            generatedCodes.push({ offset: i, time: currentTime + (i * 30), code });
        }
        console.log('[verifyAndEnable] Generated codes for different times:', generatedCodes);

        // Verify with speakeasy
        const isValid = speakeasy.totp.verify({
            secret: user.twoFactorSecret,
            encoding: 'base32',
            token: token,
            window: 4, // ±4 time steps (±120 seconds)
        });

        console.log('[verifyAndEnable] Verify result:', isValid);

        if (!isValid) {
            throw new Error('Invalid verification code. Please try again.');
        }

        // Generate backup codes
        const plainCodes = generateBackupCodes();
        const hashedCodes = await Promise.all(
            plainCodes.map(code => bcrypt.hash(code, 10))
        );

        user.twoFactorEnabled = true;
        user.twoFactorBackupCodes = hashedCodes;
        await user.save();

        return { backupCodes: plainCodes };
    },

    /**
     * Verify a TOTP token (or batckup code) for an already-enabled user.
     * Returns true if valid.
     */
    async verify(userId: string, token: string): Promise<boolean> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        if (!user.twoFactorEnabled || !user.twoFactorSecret) {
            throw new Error('Two-factor authentication is not enabled');
        }

        console.log('[verify] Token:', token, 'Secret:', user.twoFactorSecret?.substring(0, 10) + '...');

        // Try TOTP first with speakeasy
        const isValid = speakeasy.totp.verify({
            secret: user.twoFactorSecret,
            encoding: 'base32',
            token: token,
            window: 4, // ±4 time steps (±120 seconds)
        });

        console.log('[verify] TOTP result:', isValid);

        if (isValid) return true;

        // Try backup codes
        // Normalize to lowercase because codes are generated as lowercase hex
        const normalizedToken = token.toLowerCase().trim();
        if (user.twoFactorBackupCodes && user.twoFactorBackupCodes.length > 0) {
            for (let i = 0; i < user.twoFactorBackupCodes.length; i++) {
                const match = await bcrypt.compare(normalizedToken, user.twoFactorBackupCodes[i]);
                if (match) {
                    // Remove used backup code
                    user.twoFactorBackupCodes.splice(i, 1);
                    await user.save();
                    return true;
                }
            }
        }

        return false;
    },

    /**
     * Disable 2FA. Requires a valid TOTP code to confirm.
     */
    async disable(userId: string, token: string): Promise<void> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        if (!user.twoFactorEnabled) {
            throw new Error('Two-factor authentication is not enabled');
        }

        const isValid = await this.verify(userId, token);
        if (!isValid) {
            throw new Error('Invalid verification code');
        }

        user.twoFactorSecret = undefined;
        user.twoFactorEnabled = false;
        user.twoFactorBackupCodes = [];
        await user.save();
    },

    /**
     * Check if a user has 2FA enabled.
     */
    async isEnabled(userId: string): Promise<boolean> {
        const user = await User.findById(userId);
        if (!user) return false;
        return user.twoFactorEnabled;
    },

    /**
     * Guard helper for sensitive actions.
     * If user has 2FA enabled, totpToken MUST be provided and valid.
     * If 2FA is not enabled, this is a no-op.
     * Throws a specific error code so the client knows to show the 2FA dialog.
     */
    async verify2FAIfEnabled(userId: string, totpToken?: string): Promise<void> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        if (!user.twoFactorEnabled) return; // 2FA not enabled, skip

        if (!totpToken) {
            const err = new Error('2FA_REQUIRED');
            (err as any).code = '2FA_REQUIRED';
            throw err;
        }

        const isValid = await this.verify(userId, totpToken);
        if (!isValid) {
            throw new Error('Invalid 2FA verification code');
        }
    },
};
