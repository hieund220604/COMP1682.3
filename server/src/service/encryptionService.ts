import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;   // GCM recommended IV length
const TAG_LENGTH = 16;  // Auth tag length
const PREFIX = 'enc:v1:';

/**
 * Get the 32-byte encryption key from environment variable.
 * CHAT_ENCRYPTION_KEY must be a 64-character hex string (32 bytes).
 */
function getKey(): Buffer {
    const keyHex = process.env.CHAT_ENCRYPTION_KEY;
    if (!keyHex || keyHex.length !== 64) {
        throw new Error(
            'CHAT_ENCRYPTION_KEY must be a 64-character hex string (32 bytes). '
            + 'Generate one with: node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"'
        );
    }
    return Buffer.from(keyHex, 'hex');
}

export const encryptionService = {
    /**
     * Encrypt a plaintext string using AES-256-GCM.
     * Returns a prefixed base64 string: "enc:v1:<base64(iv + tag + ciphertext)>"
     */
    encrypt(plaintext: string): string {
        if (!plaintext) return plaintext;

        const key = getKey();
        const iv = crypto.randomBytes(IV_LENGTH);
        const cipher = crypto.createCipheriv(ALGORITHM, key, iv);

        const encrypted = Buffer.concat([
            cipher.update(plaintext, 'utf8'),
            cipher.final()
        ]);

        const tag = cipher.getAuthTag();

        // Pack: iv (12) + tag (16) + ciphertext (variable)
        const packed = Buffer.concat([iv, tag, encrypted]);
        return PREFIX + packed.toString('base64');
    },

    /**
     * Decrypt an encrypted string back to plaintext.
     * If the string is not encrypted (no prefix), returns it as-is (backward compat).
     */
    decrypt(text: string): string {
        if (!text || !encryptionService.isEncrypted(text)) {
            return text; // Not encrypted — passthrough
        }

        try {
            const key = getKey();
            const packed = Buffer.from(text.slice(PREFIX.length), 'base64');

            const iv = packed.subarray(0, IV_LENGTH);
            const tag = packed.subarray(IV_LENGTH, IV_LENGTH + TAG_LENGTH);
            const ciphertext = packed.subarray(IV_LENGTH + TAG_LENGTH);

            const decipher = crypto.createDecipheriv(ALGORITHM, key, iv);
            decipher.setAuthTag(tag);

            const decrypted = Buffer.concat([
                decipher.update(ciphertext),
                decipher.final()
            ]);

            return decrypted.toString('utf8');
        } catch (error) {
            console.error('[Encryption] Decryption failed, returning raw text:', (error as Error).message);
            return text; // Fail-safe: return raw text if decryption fails
        }
    },

    /**
     * Check if a string is encrypted (has the enc:v1: prefix).
     */
    isEncrypted(text: string): boolean {
        return typeof text === 'string' && text.startsWith(PREFIX);
    }
};
