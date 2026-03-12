
import nodemailer from 'nodemailer';

// Store OTP in memory (in production, use Redis or database)
const otpStore = new Map<string, { otp: string; expiresAt: number; attempts: number }>();

// Configure your email service here
const transporter = nodemailer.createTransport({
  // For Gmail:
  service: 'gmail',
  auth: {
    user: process.env.EMAIL_USER || 'your-email@gmail.com',
    pass: process.env.EMAIL_PASSWORD || 'your-app-password',
  },
  // host: process.env.EMAIL_HOST,
  // port: parseInt(process.env.EMAIL_PORT || '587'),
  // secure: process.env.EMAIL_SECURE === 'true',
  // auth: {
  //   user: process.env.EMAIL_USER,
  //   pass: process.env.EMAIL_PASSWORD,
  // },
});

// Verify connection configuration
transporter.verify(function (error, success) {
  if (error) {
    console.error('Email service incorrect configuration:', error);
  } else {
    console.log('Server is ready to take our messages. Email configured: ' + (process.env.EMAIL_USER ? 'Yes' : 'No'));
  }
});

function generateOTP(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

export const emailService = {
  /**
   * Send OTP to email
   */
  async sendOTP(email: string): Promise<string> {
    const otp = generateOTP();
    const expiresAt = Date.now() + 10 * 60 * 1000; // 10 minutes

    otpStore.set(email, {
      otp,
      expiresAt,
      attempts: 0,
    });

    // Log OTP to console for development/testing
    console.log(`[DEV MODE] OTP for ${email}: ${otp}`);

    await transporter.sendMail({
      from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
      to: email,
      subject: '🔐 Your Verification Code - SplitPal',
      html: `
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
          </head>
          <body style="margin: 0; padding: 0; background-color: #f4f7fa; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
            <table role="presentation" cellspacing="0" cellpadding="0" width="100%" style="background-color: #f4f7fa;">
              <tr>
                <td style="padding: 40px 20px;">
                  <table role="presentation" cellspacing="0" cellpadding="0" width="600" style="margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);">
                    <!-- Header -->
                    <tr>
                      <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 40px; text-align: center;">
                        <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700; letter-spacing: -0.5px;">SplitPal</h1>
                        <p style="margin: 8px 0 0; color: rgba(255,255,255,0.9); font-size: 14px;">Secure Account Verification</p>
                      </td>
                    </tr>
                    <!-- Body -->
                    <tr>
                      <td style="padding: 48px 40px;">
                        <h2 style="margin: 0 0 16px; color: #1a1a2e; font-size: 24px; font-weight: 600;">Verify Your Email Address</h2>
                        <p style="margin: 0 0 32px; color: #4a5568; font-size: 16px; line-height: 1.6;">
                          Hello! We received a request to verify your email address. Please use the verification code below to complete your registration:
                        </p>
                        <!-- OTP Box -->
                        <div style="background: linear-gradient(135deg, #f8f9ff 0%, #f0f4ff 100%); border: 2px dashed #667eea; border-radius: 12px; padding: 32px; text-align: center; margin: 0 0 32px;">
                          <p style="margin: 0 0 8px; color: #667eea; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 2px;">Your Verification Code</p>
                          <h1 style="margin: 0; color: #1a1a2e; font-size: 42px; font-weight: 700; letter-spacing: 12px; font-family: 'Courier New', monospace;">${otp}</h1>
                        </div>
                        <!-- Timer Notice -->
                        <div style="background-color: #fff8e6; border-left: 4px solid #f6ad55; border-radius: 0 8px 8px 0; padding: 16px 20px; margin: 0 0 32px;">
                          <p style="margin: 0; color: #744210; font-size: 14px;">
                            <strong>⏱️ Time Sensitive:</strong> This code will expire in <strong>10 minutes</strong>. Please use it promptly.
                          </p>
                        </div>
                        <p style="margin: 0; color: #718096; font-size: 14px; line-height: 1.6;">
                          If you didn't request this verification code, you can safely ignore this email. Someone may have entered your email address by mistake.
                        </p>
                      </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                      <td style="background-color: #f8fafc; padding: 32px 40px; border-top: 1px solid #e2e8f0;">
                        <table role="presentation" cellspacing="0" cellpadding="0" width="100%">
                          <tr>
                            <td style="text-align: center;">
                              <p style="margin: 0 0 8px; color: #1a1a2e; font-size: 16px; font-weight: 600;">SplitPal</p>
                              <p style="margin: 0 0 16px; color: #718096; font-size: 13px;">Split bills effortlessly with friends</p>
                              <p style="margin: 0; color: #a0aec0; font-size: 12px;">
                                © ${new Date().getFullYear()} SplitPal. All rights reserved.<br>
                                This is an automated message, please do not reply directly to this email.
                              </p>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </body>
          </html>
        `,
    });

    console.log(`[SUCCESS] OTP email sent successfully to ${email}`);
    return otp;
  },

  /**
   * Send OTP email with a pre-generated OTP (for withdrawal, password reset, etc.)
   * Does not create a new OTP, only sends the provided one
   */
  async sendOTPEmail(email: string, otp: string): Promise<void> {
    // Log OTP to console for development/testing
    console.log(`[DEV MODE] OTP for ${email}: ${otp}`);

    await transporter.sendMail({
      from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
      to: email,
      subject: '🔐 Your Verification Code - SplitPal',
      html: `
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
          </head>
          <body style="margin: 0; padding: 0; background-color: #f4f7fa; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
            <table role="presentation" cellspacing="0" cellpadding="0" width="100%" style="background-color: #f4f7fa;">
              <tr>
                <td style="padding: 40px 20px;">
                  <table role="presentation" cellspacing="0" cellpadding="0" width="100%" style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 12px; overflow: hidden; box-shadow: 0 10px 40px rgba(0, 0, 0, 0.1);">
                    <tr>
                      <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px; text-align: center;">
                        <h1 style="margin: 0; color: #ffffff; font-size: 24px; font-weight: 700;">SplitPal</h1>
                      </td>
                    </tr>
                    <tr>
                      <td style="padding: 40px;">
                        <p style="margin: 0 0 32px; color: #4a5568; font-size: 16px; line-height: 1.6;">
                          Hello! We received a request to verify your email address. Please use the verification code below to complete your request:
                        </p>
                        <!-- OTP Box -->
                        <div style="background: linear-gradient(135deg, #f8f9ff 0%, #f0f4ff 100%); border: 2px dashed #667eea; border-radius: 12px; padding: 32px; text-align: center; margin: 0 0 32px;">
                          <p style="margin: 0 0 8px; color: #667eea; font-size: 12px; font-weight: 600; text-transform: uppercase; letter-spacing: 2px;">Your Verification Code</p>
                          <h1 style="margin: 0; color: #1a1a2e; font-size: 42px; font-weight: 700; letter-spacing: 12px; font-family: 'Courier New', monospace;">${otp}</h1>
                        </div>
                        <!-- Timer Notice -->
                        <div style="background-color: #fff8e6; border-left: 4px solid #f6ad55; border-radius: 0 8px 8px 0; padding: 16px 20px; margin: 0 0 32px;">
                          <p style="margin: 0; color: #744210; font-size: 14px;">
                            <strong>⏱️ Time Sensitive:</strong> This code will expire in <strong>10 minutes</strong>. Please use it promptly.
                          </p>
                        </div>
                        <p style="margin: 0; color: #718096; font-size: 14px; line-height: 1.6;">
                          If you didn't request this verification code, you can safely ignore this email. Someone may have entered your email address by mistake.
                        </p>
                      </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                      <td style="background-color: #f8fafc; padding: 32px 40px; border-top: 1px solid #e2e8f0;">
                        <table role="presentation" cellspacing="0" cellpadding="0" width="100%">
                          <tr>
                            <td style="text-align: center;">
                              <p style="margin: 0 0 8px; color: #1a1a2e; font-size: 16px; font-weight: 600;">SplitPal</p>
                              <p style="margin: 0; color: #718096; font-size: 12px;">Expense Sharing Made Easy</p>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </body>
          </html>
        `,
    });
  },

  /**
   * Verify OTP
   */
  verifyOTP(email: string, otp: string): boolean {
    const record = otpStore.get(email);

    if (!record) {
      return false;
    }

    // Check if OTP is expired
    if (Date.now() > record.expiresAt) {
      otpStore.delete(email);
      return false;
    }

    // Check if OTP matches
    if (record.otp !== otp) {
      record.attempts += 1;

      // Delete after 3 failed attempts
      if (record.attempts >= 3) {
        otpStore.delete(email);
      } else {
        otpStore.set(email, record);
      }

      return false;
    }

    // OTP is valid, delete it
    otpStore.delete(email);
    return true;
  },

  /**
   * Send password reset email
   */
  async sendPasswordResetEmail(email: string, resetToken: string): Promise<void> {
    const resetLink = `${process.env.FRONTEND_URL || 'http://localhost:3000'}/reset-password?token=${resetToken}`;


    try {
      await transporter.sendMail({
        from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
        to: email,
        subject: '🔑 Reset Your Password - SplitPal',
        html: `
          <!DOCTYPE html>
          <html lang="en">
          <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
          </head>
          <body style="margin: 0; padding: 0; background-color: #f4f7fa; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;">
            <table role="presentation" cellspacing="0" cellpadding="0" width="100%" style="background-color: #f4f7fa;">
              <tr>
                <td style="padding: 40px 20px;">
                  <table role="presentation" cellspacing="0" cellpadding="0" width="600" style="margin: 0 auto; background-color: #ffffff; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 24px rgba(0, 0, 0, 0.08);">
                    <!-- Header -->
                    <tr>
                      <td style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 40px; text-align: center;">
                        <h1 style="margin: 0; color: #ffffff; font-size: 28px; font-weight: 700; letter-spacing: -0.5px;">SplitPal</h1>
                        <p style="margin: 8px 0 0; color: rgba(255,255,255,0.9); font-size: 14px;">Password Recovery</p>
                      </td>
                    </tr>
                    <!-- Body -->
                    <tr>
                      <td style="padding: 48px 40px;">
                        <h2 style="margin: 0 0 16px; color: #1a1a2e; font-size: 24px; font-weight: 600;">Reset Your Password</h2>
                        <p style="margin: 0 0 24px; color: #4a5568; font-size: 16px; line-height: 1.6;">
                          We received a request to reset the password for your SplitPal account. Click the button below to create a new password:
                        </p>
                        <!-- CTA Button -->
                        <table role="presentation" cellspacing="0" cellpadding="0" width="100%" style="margin: 0 0 32px;">
                          <tr>
                            <td style="text-align: center;">
                              <a href="${resetLink}" style="display: inline-block; background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #ffffff; text-decoration: none; padding: 16px 48px; border-radius: 50px; font-size: 16px; font-weight: 600; box-shadow: 0 4px 16px rgba(102, 126, 234, 0.4);">
                                🔐 Reset My Password
                              </a>
                            </td>
                          </tr>
                        </table>
                        <!-- Alternative Link -->
                        <div style="background-color: #f8fafc; border-radius: 8px; padding: 16px 20px; margin: 0 0 32px;">
                          <p style="margin: 0 0 8px; color: #4a5568; font-size: 13px;">
                            If the button doesn't work, copy and paste this link into your browser:
                          </p>
                          <p style="margin: 0; color: #667eea; font-size: 12px; word-break: break-all;">
                            ${resetLink}
                          </p>
                        </div>
                        <!-- Timer Notice -->
                        <div style="background-color: #fff8e6; border-left: 4px solid #f6ad55; border-radius: 0 8px 8px 0; padding: 16px 20px; margin: 0 0 32px;">
                          <p style="margin: 0; color: #744210; font-size: 14px;">
                            <strong>⏱️ Time Sensitive:</strong> This link will expire in <strong>1 hour</strong> for security reasons.
                          </p>
                        </div>
                        <!-- Security Notice -->
                        <div style="background-color: #f0fff4; border-left: 4px solid #48bb78; border-radius: 0 8px 8px 0; padding: 16px 20px; margin: 0 0 24px;">
                          <p style="margin: 0; color: #276749; font-size: 14px;">
                            <strong>🛡️ Security Tip:</strong> If you didn't request this password reset, please ignore this email. Your password will remain unchanged.
                          </p>
                        </div>
                        <p style="margin: 0; color: #718096; font-size: 14px; line-height: 1.6;">
                          Need help? Contact our support team if you have any questions.
                        </p>
                      </td>
                    </tr>
                    <!-- Footer -->
                    <tr>
                      <td style="background-color: #f8fafc; padding: 32px 40px; border-top: 1px solid #e2e8f0;">
                        <table role="presentation" cellspacing="0" cellpadding="0" width="100%">
                          <tr>
                            <td style="text-align: center;">
                              <p style="margin: 0 0 8px; color: #1a1a2e; font-size: 16px; font-weight: 600;">SplitPal</p>
                              <p style="margin: 0 0 16px; color: #718096; font-size: 13px;">Split bills effortlessly with friends</p>
                              <p style="margin: 0; color: #a0aec0; font-size: 12px;">
                                © ${new Date().getFullYear()} SplitPal. All rights reserved.<br>
                                This is an automated message, please do not reply directly to this email.
                              </p>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                </td>
              </tr>
            </table>
          </body>
          </html>
        `,
      });
    } catch (error) {
      console.error('Failed to send password reset email:', error);
      throw new Error('Failed to send password reset email');
    }
  },

  /**
   * Send welcome email
   */
  async sendWelcomeEmail(email: string, displayName?: string): Promise<void> {
    try {
      await transporter.sendMail({
        from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
        to: email,
        subject: 'Welcome to SplitPal',
        html: `
          <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2>Welcome ${displayName ? `${displayName}` : 'to SplitPal'}!</h2>
            <p>Your account has been successfully activated!</p>
            <p>You can now log in and start using the SplitPal app.</p>
            <p style="color: #666; font-size: 12px;">Thank you for joining our community!</p>
          </div>
        `,
      });
    } catch (error) {
      console.error('Failed to send welcome email:', error);
      // Don't throw error for welcome email
    }
  },

  async sendNotificationEmail(email: string, displayName: string, title: string, message: string): Promise<void> {
    try {
      await transporter.sendMail({
        from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
        to: email,
        subject: `🔔 ${title} - SplitPal`,
        html: `<html><body style="font-family: Arial; max-width: 600px; margin: 0 auto; padding: 20px;"><h2>Hi ${displayName},</h2><h3 style="color: #667eea;">${title}</h3><p>${message}</p><p style="color: #666; font-size: 14px;">Log in to SplitPal to view more details.</p><hr><p style="color: #999; font-size: 12px;">SplitPal</p></body></html>`
      });
    } catch (error) {
      console.error('Failed to send notification email:', error);
    }
  },

  async sendContactEmail(fromEmail: string, fromName: string, subject: string, message: string): Promise<void> {
    try {
      const recipient = process.env.EMAIL_USER; // Send to the configured system email
      if (!recipient) {
        console.error("EMAIL_USER not configured");
        return;
      }
      await transporter.sendMail({
        from: process.env.EMAIL_FROM || process.env.EMAIL_USER,
        to: recipient,
        replyTo: fromEmail,
        subject: `[Contact Us] ${subject}`,
        html: `
            <div style="font-family: Arial, sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 5px;">
              <h2>New Contact Message</h2>
              <p><strong>From:</strong> ${fromName} (${fromEmail})</p>
              <p><strong>Subject:</strong> ${subject}</p>
              <hr />
              <p style="white-space: pre-wrap;">${message}</p>
            </div>
            `
      });
    } catch (error) {
      console.error('Failed to send contact email:', error);
      throw new Error('Failed to send message');
    }
  }
};