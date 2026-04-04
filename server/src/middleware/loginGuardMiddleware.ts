import { NextFunction, Request, Response } from 'express';
import { buildRedisKey, getRedis } from '../redis';

declare global {
    namespace Express {
        interface Request {
            loginAttemptKey?: string;
        }
    }
}

const MAX_FAILURES = 3;
const BLOCK_TTL_MS = 30_000;
const fallbackStore = new Map<string, { count: number; expiresAt: number }>();

const sanitize = (value: string): string =>
    value.trim().toLowerCase().replace(/[^a-z0-9:_-]/g, '_');

function getAttemptKey(req: Request): string {
    const email = typeof req.body?.email === 'string' ? sanitize(req.body.email) : '';
    const ip = (req.ip || req.headers['x-forwarded-for'] || 'unknown').toString();
    return buildRedisKey('login_attempt', email || sanitize(ip));
}

async function getCount(key: string): Promise<{ count: number; ttlMs: number }> {
    const redis = getRedis();
    if (redis) {
        const [rawCount, ttl] = await Promise.all([
            redis.get(key),
            redis.pttl(key)
        ]);
        return {
            count: rawCount ? Number(rawCount) : 0,
            ttlMs: ttl && ttl > 0 ? ttl : BLOCK_TTL_MS
        };
    }

    const now = Date.now();
    const current = fallbackStore.get(key);
    if (!current || current.expiresAt <= now) {
        fallbackStore.delete(key);
        return { count: 0, ttlMs: BLOCK_TTL_MS };
    }
    return { count: current.count, ttlMs: current.expiresAt - now };
}

async function incrementFailure(key: string): Promise<{ count: number; ttlMs: number }> {
    const redis = getRedis();
    if (redis) {
        const count = await redis.incr(key);
        await redis.pexpire(key, BLOCK_TTL_MS);
        const ttlMs = await redis.pttl(key);
        return { count, ttlMs: ttlMs && ttlMs > 0 ? ttlMs : BLOCK_TTL_MS };
    }

    const now = Date.now();
    const current = fallbackStore.get(key);
    const count = current && current.expiresAt > now ? current.count + 1 : 1;
    const expiresAt = now + BLOCK_TTL_MS;
    fallbackStore.set(key, { count, expiresAt });
    return { count, ttlMs: BLOCK_TTL_MS };
}

async function resetFailures(key: string): Promise<void> {
    const redis = getRedis();
    if (redis) {
        await redis.del(key);
    } else {
        fallbackStore.delete(key);
    }
}

export async function loginGuard(req: Request, res: Response, next: NextFunction): Promise<void> {
    const key = getAttemptKey(req);
    req.loginAttemptKey = key;
    const { count, ttlMs } = await getCount(key);

    if (count >= MAX_FAILURES) {
        const retryAfter = Math.max(1, Math.ceil(ttlMs / 1000));
        res.setHeader('Retry-After', retryAfter);
        res.status(429).json({
            success: false,
            error: {
                message: `Too many failed login attempts. Please wait ${retryAfter}s before retrying.`,
                code: 'LOGIN_RATE_LIMIT'
            }
        });
        return;
    }

    next();
}

export async function recordLoginSuccess(req: Request): Promise<void> {
    const key = req.loginAttemptKey || getAttemptKey(req);
    await resetFailures(key);
}

export async function recordLoginFailure(req: Request): Promise<{ count: number; blocked: boolean; retryAfterSec: number }> {
    const key = req.loginAttemptKey || getAttemptKey(req);
    const { count, ttlMs } = await incrementFailure(key);
    return {
        count,
        blocked: count >= MAX_FAILURES,
        retryAfterSec: Math.max(1, Math.ceil(ttlMs / 1000))
    };
}
