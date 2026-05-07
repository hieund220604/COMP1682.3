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

// ── Periodic cleanup: prevent memory leak when Redis is down ────────────
setInterval(() => {
    const now = Date.now();
    for (const [key, value] of fallbackStore.entries()) {
        if (value.resetAt <= now) fallbackStore.delete(key);
    }
}, 60_000);

// ── Lua script: atomic INCR + PEXPIRE (no race condition) ──────────────
const RATE_LIMIT_LUA = `
    local count = redis.call('INCR', KEYS[1])
    if count == 1 then
        redis.call('PEXPIRE', KEYS[1], ARGV[1])
    end
    local ttl = redis.call('PTTL', KEYS[1])
    return {count, ttl}
`;

function sanitizeKeyPart(value: string): string {
    return value.trim().toLowerCase().replace(/[^a-z0-9:_-]/g, '_');
}

function getFallbackKey(options: RateLimitOptions, req: Request): string {
    const baseKey = options.keyGenerator ? options.keyGenerator(req) : (req.ip || 'unknown');
    return `${options.keyPrefix}:${sanitizeKeyPart(baseKey)}`;
}

function setRateLimitHeaders(res: Response, limit: number, remaining: number, resetMs: number): void {
    res.setHeader('X-RateLimit-Limit', limit);
    res.setHeader('X-RateLimit-Remaining', Math.max(0, remaining));
    res.setHeader('X-RateLimit-Reset', Math.ceil((Date.now() + Math.max(0, resetMs)) / 1000));
}

function applyFallbackRateLimit(options: RateLimitOptions, req: Request): { allowed: boolean; retryAfterSec: number; count: number; resetMs: number } {
    const now = Date.now();
    const key = getFallbackKey(options, req);
    const current = fallbackStore.get(key);

    if (!current || current.resetAt <= now) {
        fallbackStore.set(key, { count: 1, resetAt: now + options.windowMs });
        return { allowed: true, retryAfterSec: Math.ceil(options.windowMs / 1000), count: 1, resetMs: options.windowMs };
    }

    current.count += 1;
    fallbackStore.set(key, current);
    const resetMs = current.resetAt - now;

    if (current.count > options.maxRequests) {
        return {
            allowed: false,
            retryAfterSec: Math.max(1, Math.ceil(resetMs / 1000)),
            count: current.count,
            resetMs
        };
    }

    return {
        allowed: true,
        retryAfterSec: Math.max(1, Math.ceil(resetMs / 1000)),
        count: current.count,
        resetMs
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
                const result = await redis.eval(RATE_LIMIT_LUA, 1, redisKey, options.windowMs) as [number, number];
                const currentCount = result[0];
                const ttlMs = result[1] > 0 ? result[1] : options.windowMs;

                setRateLimitHeaders(res, options.maxRequests, options.maxRequests - currentCount, ttlMs);

                if (currentCount > options.maxRequests) {
                    const retryAfterSec = Math.ceil(ttlMs / 1000);
                    res.setHeader('Retry-After', retryAfterSec);
                    console.warn(`[RATE_LIMIT] Blocked: prefix=${options.keyPrefix} key=${sanitizeKeyPart(baseKey)} count=${currentCount}/${options.maxRequests}`);
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
        setRateLimitHeaders(res, options.maxRequests, options.maxRequests - fallbackResult.count, fallbackResult.resetMs);

        if (!fallbackResult.allowed) {
            res.setHeader('Retry-After', fallbackResult.retryAfterSec);
            console.warn(`[RATE_LIMIT] Blocked (fallback): prefix=${options.keyPrefix} key=${sanitizeKeyPart(baseKey)}`);
            res.status(429).json({ success: false, message });
            return;
        }

        next();
    };
}
