import Redis from 'ioredis';

let redisClient: Redis | null = null;
let redisConnected = false;

const REDIS_URL = process.env.REDIS_URL;
const REDIS_PREFIX = process.env.REDIS_PREFIX || 'splitpal';

function createClient(): Redis | null {
    if (!REDIS_URL) {
        return null;
    }

    if (redisClient) {
        return redisClient;
    }

    redisClient = new Redis(REDIS_URL, {
        maxRetriesPerRequest: 1,
        enableReadyCheck: true,
        lazyConnect: true,
        connectTimeout: Number(process.env.REDIS_CONNECT_TIMEOUT_MS || 5000),
    });

    redisClient.on('connect', () => {
        redisConnected = true;
        console.log('Connected to Redis');
    });

    redisClient.on('ready', () => {
        redisConnected = true;
    });

    redisClient.on('error', (error) => {
        redisConnected = false;
        console.error('Redis error:', error.message);
    });

    redisClient.on('close', () => {
        redisConnected = false;
    });

    return redisClient;
}

export async function connectRedis(): Promise<void> {
    const client = createClient();
    if (!client) {
        console.log('Redis not configured. Running without Redis.');
        return;
    }

    try {
        await client.connect();
    } catch (error) {
        redisConnected = false;
        console.error('Redis connection failed. Continuing without Redis.');
    }
}

export function getRedis(): Redis | null {
    const client = createClient();
    if (!client || !redisConnected) {
        return null;
    }
    return client;
}

export async function disconnectRedis(): Promise<void> {
    if (!redisClient) {
        return;
    }

    try {
        await redisClient.quit();
    } catch {
        try {
            redisClient.disconnect();
        } catch {
            // Ignore forced disconnect errors during shutdown.
        }
    } finally {
        redisClient = null;
        redisConnected = false;
    }
}

export function buildRedisKey(...parts: string[]): string {
    return [REDIS_PREFIX, ...parts].join(':');
}

export async function getJsonCache<T>(key: string): Promise<T | null> {
    const redis = getRedis();
    if (!redis) {
        return null;
    }

    try {
        const raw = await redis.get(key);
        if (!raw) {
            return null;
        }
        return JSON.parse(raw) as T;
    } catch (error) {
        console.error('Redis getJsonCache failed:', error);
        return null;
    }
}

export async function setJsonCache(key: string, value: unknown, ttlSeconds: number): Promise<void> {
    const redis = getRedis();
    if (!redis) {
        return;
    }

    try {
        await redis.set(key, JSON.stringify(value), 'EX', ttlSeconds);
    } catch (error) {
        console.error('Redis setJsonCache failed:', error);
    }
}

export async function deleteKeysByPrefix(prefix: string): Promise<void> {
    const redis = getRedis();
    if (!redis) {
        return;
    }

    try {
        let cursor = '0';
        const matchPattern = `${prefix}*`;

        do {
            const result = await redis.scan(cursor, 'MATCH', matchPattern, 'COUNT', 100);
            cursor = result[0];
            const keys = result[1];

            if (keys.length > 0) {
                await redis.del(...keys);
            }
        } while (cursor !== '0');
    } catch (error) {
        console.error('Redis deleteKeysByPrefix failed:', error);
    }
}
