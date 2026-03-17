import { NextFunction, Request, Response } from 'express';
import { buildRedisKey, getRedis } from '../redis';

interface RateLimitOptions {
    keyPrefix: string;
    windowMs: number;
    maxRequests: number;
    message?: string;
    keyGenerator?: (req: Request) => string;
}

const fallbackStore = new Map<string, { count: number; resetAt: number }>();

function sanitizeKeyPart(value: string): string {
    return value.trim().toLowerCase().replace(/[^a-z0-9:_-]/g, '_');
}

function getFallbackKey(options: RateLimitOptions, req: Request): string {
    const baseKey = options.keyGenerator ? options.keyGenerator(req) : (req.ip || 'unknown');
    return `${options.keyPrefix}:${sanitizeKeyPart(baseKey)}`;
}

function applyFallbackRateLimit(options: RateLimitOptions, req: Request): { allowed: boolean; retryAfterSec: number } {
    const now = Date.now();
    const key = getFallbackKey(options, req);
    const current = fallbackStore.get(key);

    if (!current || current.resetAt <= now) {
        fallbackStore.set(key, { count: 1, resetAt: now + options.windowMs });
        return { allowed: true, retryAfterSec: Math.ceil(options.windowMs / 1000) };
    }

    current.count += 1;
    fallbackStore.set(key, current);

    if (current.count > options.maxRequests) {
        return {
            allowed: false,
            retryAfterSec: Math.max(1, Math.ceil((current.resetAt - now) / 1000))
        };
    }

    return {
        allowed: true,
        retryAfterSec: Math.max(1, Math.ceil((current.resetAt - now) / 1000))
    };
}

export function createRateLimit(options: RateLimitOptions) {
    const message = options.message || 'Too many requests. Please try again later.';

    return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
        const baseKey = options.keyGenerator ? options.keyGenerator(req) : (req.ip || 'unknown');
        const redisKey = buildRedisKey('ratelimit', options.keyPrefix, sanitizeKeyPart(baseKey));
        const redis = getRedis();

        if (redis) {
            try {
                const currentCount = await redis.incr(redisKey);
                if (currentCount === 1) {
                    await redis.pexpire(redisKey, options.windowMs);
                }

                if (currentCount > options.maxRequests) {
                    const ttlMs = await redis.pttl(redisKey);
                    const retryAfterSec = ttlMs > 0 ? Math.ceil(ttlMs / 1000) : Math.ceil(options.windowMs / 1000);
                    res.setHeader('Retry-After', retryAfterSec);
                    res.status(429).json({ success: false, message });
                    return;
                }

                next();
                return;
            } catch (error) {
                console.error('Redis rate-limit failed, fallback to memory:', error);
            }
        }

        const fallbackResult = applyFallbackRateLimit(options, req);
        if (!fallbackResult.allowed) {
            res.setHeader('Retry-After', fallbackResult.retryAfterSec);
            res.status(429).json({ success: false, message });
            return;
        }

        next();
    };
}
