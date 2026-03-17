import { Lock } from '../models/Lock';
import { randomUUID } from 'crypto';
import { buildRedisKey, getRedis } from '../redis';

export class LockNotAcquiredError extends Error {
    constructor(message: string) {
        super(message);
        this.name = 'LockNotAcquiredError';
    }
}

export interface LockHandle {
    release: () => Promise<void>;
}

/**
 * Acquire a short-lived lock keyed by name/groupId.
 * Returns null if lock cannot be acquired (someone else holds it).
 */
export async function acquireLock(
    name: string,
    groupId?: string,
    ttlMs: number = 15_000
): Promise<LockHandle | null> {
    const redisLock = await acquireRedisLock(name, groupId, ttlMs);
    if (redisLock) {
        return redisLock;
    }

    // Fallback to Mongo lock if Redis is unavailable.
    return acquireMongoLock(name, groupId, ttlMs);
}

async function acquireRedisLock(
    name: string,
    groupId?: string,
    ttlMs: number = 15_000
): Promise<LockHandle | null> {
    const redis = getRedis();
    if (!redis) {
        return null;
    }

    const lockKey = buildRedisKey('lock', name, groupId || 'global');
    const lockToken = randomUUID();

    try {
        const result = await redis.set(lockKey, lockToken, 'PX', ttlMs, 'NX');
        if (result !== 'OK') {
            return null;
        }

        return {
            release: async () => {
                const releaseScript = `
                    if redis.call('GET', KEYS[1]) == ARGV[1] then
                        return redis.call('DEL', KEYS[1])
                    else
                        return 0
                    end
                `;

                try {
                    await redis.eval(releaseScript, 1, lockKey, lockToken);
                } catch (error) {
                    console.error('Failed to release Redis lock:', error);
                }
            }
        };
    } catch (error) {
        console.error('Failed to acquire Redis lock, fallback to Mongo lock:', error);
        return null;
    }
}

async function acquireMongoLock(
    name: string,
    groupId?: string,
    ttlMs: number = 15_000
): Promise<LockHandle | null> {
    const now = new Date();
    const expiresAt = new Date(now.getTime() + ttlMs);

    const filter: any = { name };
    if (groupId) {
        filter.groupId = groupId;
    }
    filter.$or = [
        { expiresAt: { $lte: now } },
        { expiresAt: { $exists: false } }
    ];

    try {
        const lock = await Lock.findOneAndUpdate(
            filter,
            {
                name,
                groupId,
                expiresAt
            },
            {
                new: true,
                upsert: true,
                setDefaultsOnInsert: true
            }
        );

        if (!lock) {
            return null;
        }

        return {
            release: async () => {
                await Lock.findByIdAndUpdate(lock._id, { expiresAt: new Date() });
            }
        };
    } catch (error: any) {
        // Most likely duplicate key => lock already held
        if (error.code === 11000) {
            return null;
        }
        throw error;
    }
}
