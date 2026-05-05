import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IUser extends Document {
    _id: Types.ObjectId;
    email: string;
    passwordHash: string;
    displayName: string;
    avatarUrl?: string;
    status: 'active' | 'inactive';
    balance: number;
    currency: string;
    fcmToken?: string;
    pushNotificationsEnabled: boolean;
    twoFactorSecret?: string;
    twoFactorEnabled: boolean;
    twoFactorBackupCodes?: string[];
    isPro: boolean;
    createdAt: Date;
    updatedAt: Date;
}

const UserSchema = new Schema<IUser>({
    email: {
        type: String,
        required: true,
        unique: true,
        lowercase: true,
        trim: true
    },
    passwordHash: {
        type: String,
        required: true
    },
    displayName: {
        type: String,
        required: true,
        trim: true
    },
    avatarUrl: {
        type: String,
        default: null
    },
    status: {
        type: String,
        enum: ['active', 'inactive'],
        default: 'inactive'
    },
    balance: {
        type: Number,
        default: 0
    },
    currency: {
        type: String,
        default: 'VND'
    },
    fcmToken: {
        type: String,
        default: null
    },
    pushNotificationsEnabled: {
        type: Boolean,
        default: true
    },
    twoFactorSecret: {
        type: String,
        default: null
    },
    twoFactorEnabled: {
        type: Boolean,
        default: false
    },
    twoFactorBackupCodes: {
        type: [String],
        default: []
    },
    isPro: {
        type: Boolean,
        default: false
    }
}, {
    timestamps: true,
    collection: 'users',
    toJSON: { getters: true },
    toObject: { getters: true }
});

// Indexes


export const User = mongoose.model<IUser>('User', UserSchema);
