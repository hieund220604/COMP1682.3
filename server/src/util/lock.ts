import { Lock } from '../models/Lock';

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
