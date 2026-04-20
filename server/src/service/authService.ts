import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { User } from '../models/User';
import { emailService } from './emailService';
import { JWTPayLoad } from '../type/auth';
import { admin } from '../config/firebase-config';

const normalizeEmail = (email: string): string => email.trim().toLowerCase();
const toPushNotificationsEnabled = (value: boolean | undefined): boolean => value !== false;

export const authService = {
    async hashPassword(password: string): Promise<string> {
        const salt = await bcrypt.genSalt(10);
        return bcrypt.hash(password, salt);
    },

    async comparePassword(password: string, hashedPassword: string): Promise<boolean> {
        return bcrypt.compare(password, hashedPassword);
    },

    generateToken(userId: string, email: string): string {
        const payload: JWTPayLoad = { userId, email };
        const options: any = { expiresIn: '7d' };
        return jwt.sign(payload, process.env.JWT_SECRET || 'default_secret', options);
    },

    verifyToken(token: string): JWTPayLoad | null {
        try {
            const decode = jwt.verify(token, process.env.JWT_SECRET || 'hieu2206') as JWTPayLoad;
            return decode;
        }
        catch (error) {
            return null;
        }
    },

    async SignUpUser(email: string, password: string, displayName?: string): Promise<any> {
        const normalizedEmail = normalizeEmail(email);
        const existingUser = await User.findOne({ email: normalizedEmail });

        // If user exists:
        if (existingUser) {
            // Case 1: Account is already active -> Throw error
            if (existingUser.status === 'active') {
                throw new Error('Email is already registered');
            }

            // Case 2: Account is inactive -> Treat as retry sign up
            // Update password and display name (if provided)
            const hashedPassword = await this.hashPassword(password);
            existingUser.passwordHash = hashedPassword;
            if (displayName) {
                existingUser.displayName = displayName;
            }
            await existingUser.save();

            // Resend OTP
            await emailService.sendOTP(normalizedEmail);

            return {
                userId: existingUser._id.toString(),
                email: existingUser.email,
                displayName: existingUser.displayName,
                pushNotificationsEnabled: toPushNotificationsEnabled(existingUser.pushNotificationsEnabled),
                message: 'Account already exists but was inactive. A new verification code has been sent to your email.'
            };
        }

        // New User creation
        const hashedPassword = await this.hashPassword(password);
        const newUser = await User.create({
            email: normalizedEmail,
            passwordHash: hashedPassword,
            displayName: displayName || normalizedEmail.split('@')[0],
            status: "inactive"
        });
        await emailService.sendOTP(normalizedEmail);
        return {
            userId: newUser._id.toString(),
            email: newUser.email,
            displayName: newUser.displayName,
            avatarUrl: newUser.avatarUrl,
            pushNotificationsEnabled: toPushNotificationsEnabled(newUser.pushNotificationsEnabled),
            message: 'User registered successfully. Please verify your email to activate your account.'
        };
    },

    async verifyOTP(email: string, otp: string): Promise<any> {
        const normalizedEmail = normalizeEmail(email);
        const user = await User.findOne({ email: normalizedEmail });
        if (!user) {
            throw new Error('User not found');
        }
        if (!(await emailService.verifyOTP(normalizedEmail, otp))) {
            throw new Error('Invalid or expired OTP');
        }
        user.status = 'active';
        await user.save();

        await emailService.sendWelcomeEmail(normalizedEmail, user.displayName || '');
        return {
            user: {
                userId: user._id.toString(),
                email: user.email,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl,
                pushNotificationsEnabled: toPushNotificationsEnabled(user.pushNotificationsEnabled),
                message: 'Email verified successfully. Your account is now active.'
            },
            token: this.generateToken(user._id.toString(), user.email)
        };
    },

    async loginUser(email: string, password: string): Promise<any> {
        const normalizedEmail = normalizeEmail(email);
        const user = await User.findOne({ email: normalizedEmail });
        if (!user) {
            throw new Error('Invalid email or password');
        }
        if (user.status !== 'active') {
            throw new Error('Account is not active. Please verify your email.');
        }

        const isPasswordValid = await this.comparePassword(password, user.passwordHash);
        if (!isPasswordValid) {
            throw new Error('Invalid email or password');
        }

        // Check if 2FA is enabled
        if (user.twoFactorEnabled) {
            // Return a short-lived temp token for 2FA verification
            const tempToken = jwt.sign(
                { userId: user._id.toString(), email: user.email, pending2FA: true } as any,
                process.env.JWT_SECRET || 'default_secret',
                { expiresIn: '5m' }
            );
            return {
                requires2FA: true,
                tempToken,
                user: {
                    userId: user._id.toString(),
                    email: user.email,
                    displayName: user.displayName,
                    twoFactorEnabled: true,
                    pushNotificationsEnabled: toPushNotificationsEnabled(user.pushNotificationsEnabled),
                },
            };
        }

        const token = this.generateToken(user._id.toString(), user.email);
        return {
            user: {
                userId: user._id.toString(),
                email: user.email,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl,
                balance: user.balance,
                currency: user.currency,
                twoFactorEnabled: false,
                pushNotificationsEnabled: toPushNotificationsEnabled(user.pushNotificationsEnabled),
            },
            token
        };
    },

    async loginWithGoogle(idToken: string): Promise<any> {
        // Verify the Firebase ID token
        const decodedToken = await admin.auth().verifyIdToken(idToken);
        const email = decodedToken.email;
        const displayName = decodedToken.name || email?.split('@')[0];

        if (!email) {
            throw new Error('Google sign-in failed: Null email');
        }

        const normalizedEmail = normalizeEmail(email);
        let user = await User.findOne({ email: normalizedEmail });

        if (!user) {
            // Create a new user with a random strong password since it's a Google account
            const randomPassword = Math.random().toString(36).slice(-8) + Math.random().toString(36).slice(-8) + 'A1!';
            const hashedPassword = await this.hashPassword(randomPassword);
            
            user = await User.create({
                email: normalizedEmail,
                passwordHash: hashedPassword,
                displayName: displayName,
                status: 'active', // Google emails are already verified
                avatarUrl: decodedToken.picture || null
            });
        } else if (user.status !== 'active') {
             // If they signed up manually but didn't verify, then signed in with Google -> activate them
            user.status = 'active';
            await user.save();
        }

        const token = this.generateToken(user._id.toString(), user.email);
        return {
            user: {
                userId: user._id.toString(),
                email: user.email,
                displayName: user.displayName,
                avatarUrl: user.avatarUrl,
                balance: user.balance,
                currency: user.currency,
                twoFactorEnabled: user.twoFactorEnabled || false,
                pushNotificationsEnabled: toPushNotificationsEnabled(user.pushNotificationsEnabled),
            },
            token
        };
    },

    async passwordResetRequest(email: string): Promise<string> {
        const normalizedEmail = normalizeEmail(email);
        const user = await User.findOne({ email: normalizedEmail });
        if (!user) {
            return 'If the email is registered, a password reset link has been sent.';
        }
        const resetOptions: any = { expiresIn: '1h' };
        const resetToken = jwt.sign({ userId: user._id.toString(), email: user.email, type: 'reset' }, process.env.JWT_SECRET || 'default_secret', resetOptions);
        await emailService.sendPasswordResetEmail(normalizedEmail, resetToken);
        return 'If the email is registered, a password reset link has been sent.';
    },

    async resetPassword(resetToken: string, newPassword: string): Promise<any> {
        try {
            const decoded = jwt.verify(resetToken, process.env.JWT_SECRET || 'default_secret') as any;
            if (decoded.type !== 'reset') {
                throw new Error('Invalid token type');
            }
            const passsowrdHash = await this.hashPassword(newPassword);
            const updatedUser = await User.findByIdAndUpdate(
                decoded.userId,
                { passwordHash: passsowrdHash },
                { new: true }
            );

            if (!updatedUser) {
                throw new Error('User not found');
            }

            return {
                email: updatedUser.email,
                message: 'Password has been reset successfully.'
            };
        }
        catch (error) {
            throw new Error('Invalid or expired reset token');
        }
    },

    async resendOTP(email: string): Promise<string> {
        const normalizedEmail = normalizeEmail(email);
        const user = await User.findOne({ email: normalizedEmail });
        if (!user) {
            throw new Error('User not found');
        }
        if (user.status === 'active') {
            throw new Error('Account is already active');
        }
        await emailService.sendOTP(normalizedEmail);
        return 'A new OTP has been sent to your email.';
    },

    // Forgot Password - Send OTP to existing user
    async forgotPasswordOTP(email: string): Promise<string> {
        const normalizedEmail = normalizeEmail(email);
        const user = await User.findOne({ email: normalizedEmail });
        if (!user) {
            // Return generic message for security (don't reveal if email exists)
            return 'If the email is registered, an OTP has been sent.';
        }
        if (user.status !== 'active') {
            throw new Error('Account is not active. Please verify your email first.');
        }
        await emailService.sendOTP(normalizedEmail);
        return 'An OTP has been sent to your email for password reset.';
    },

    // Verify OTP for password reset (doesn't activate account, just validates OTP)
    async verifyResetOTP(email: string, otp: string): Promise<{ valid: boolean; resetToken: string }> {
        const normalizedEmail = normalizeEmail(email);
        const user = await User.findOne({ email: normalizedEmail });
        if (!user) {
            throw new Error('User not found');
        }
        if (!(await emailService.verifyOTP(normalizedEmail, otp))) {
            throw new Error('Invalid or expired OTP');
        }
        // Generate a short-lived reset token
        const resetToken = jwt.sign(
            { userId: user._id.toString(), email: user.email, type: 'otp_reset' },
            process.env.JWT_SECRET || 'default_secret',
            { expiresIn: '10m' }
        );
        return { valid: true, resetToken };
    },

    // Reset password with OTP-verified token
    async resetPasswordWithToken(resetToken: string, newPassword: string): Promise<any> {
        try {
            const decoded = jwt.verify(resetToken, process.env.JWT_SECRET || 'default_secret') as any;
            if (decoded.type !== 'otp_reset') {
                throw new Error('Invalid token type');
            }
            const passwordHash = await this.hashPassword(newPassword);
            const updatedUser = await User.findByIdAndUpdate(
                decoded.userId,
                { passwordHash },
                { new: true }
            );

            if (!updatedUser) {
                throw new Error('User not found');
            }

            return {
                email: updatedUser.email,
                message: 'Password has been reset successfully.'
            };
        } catch (error) {
            throw new Error('Invalid or expired reset token');
        }
    },

    async getUserProfilebyID(userId: string): Promise<any> {
        const user = await User.findById(userId).select('_id email displayName avatarUrl status balance currency pushNotificationsEnabled twoFactorEnabled createdAt updatedAt');
        if (!user) {
            throw new Error('User not found');
        }
        return {
            id: user._id.toString(),
            email: user.email,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            status: user.status,
            balance: user.balance,
            currency: user.currency,
            pushNotificationsEnabled: toPushNotificationsEnabled(user.pushNotificationsEnabled),
            twoFactorEnabled: user.twoFactorEnabled || false,
            createdAt: user.createdAt,
            updatedAt: user.updatedAt
        };
    },

    async updateProfile(userId: string, data: { displayName?: string, avatarUrl?: string }): Promise<any> {
        const user = await User.findByIdAndUpdate(
            userId,
            data,
            { new: true }
        ).select('_id email displayName avatarUrl balance currency pushNotificationsEnabled');

        if (!user) {
            throw new Error('User not found');
        }

        return {
            id: user._id.toString(),
            email: user.email,
            displayName: user.displayName,
            avatarUrl: user.avatarUrl,
            balance: user.balance,
            currency: user.currency,
            pushNotificationsEnabled: toPushNotificationsEnabled(user.pushNotificationsEnabled)
        };
    },

    async initiateChangePassword(userId: string, oldPassword: string, newPassword: string): Promise<string> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        const isPasswordValid = await this.comparePassword(oldPassword, user.passwordHash);
        if (!isPasswordValid) throw new Error('Incorrect current password');

        if (oldPassword === newPassword) {
            throw new Error('New password must be different from the current password');
        }

        // Check if new password is same as old password (hash comparison)
        const isSameAsCurrent = await this.comparePassword(newPassword, user.passwordHash);
        if (isSameAsCurrent) {
            throw new Error('New password must be different from the current password');
        }

        // Send OTP
        await emailService.sendOTP(user.email);
        return 'OTP sent to your email. Please verify to complete password change.';
    },

    async confirmChangePassword(userId: string, otp: string, newPassword: string): Promise<string> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        if (!(await emailService.verifyOTP(user.email, otp))) {
            throw new Error('Invalid or expired OTP');
        }

        const passwordHash = await this.hashPassword(newPassword);
        user.passwordHash = passwordHash;
        await user.save();

        return 'Password changed successfully.';
    },

    async contactUs(userId: string, subject: string, message: string): Promise<string> {
        const user = await User.findById(userId);
        if (!user) throw new Error('User not found');

        await emailService.sendContactEmail(user.email, user.displayName || 'User', subject, message);
        return 'Message sent successfully.';
    }
};
