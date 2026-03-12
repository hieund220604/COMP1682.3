import mongoose, { Schema, Document } from 'mongoose';

export interface ILock extends Document {
    name: string;
    groupId?: string;
    expiresAt: Date;
    createdAt: Date;
}

const LockSchema = new Schema<ILock>({
    name: { type: String, required: true, index: true },
    groupId: { type: String, index: true },
    expiresAt: { type: Date, required: true },
}, {
    timestamps: { createdAt: true, updatedAt: false },
    collection: 'locks'
});

// TTL index so expired locks get cleaned up automatically
LockSchema.index({ expiresAt: 1 }, { expireAfterSeconds: 0 });
LockSchema.index({ name: 1, groupId: 1 }, { unique: true });

export const Lock = mongoose.model<ILock>('Lock', LockSchema);
