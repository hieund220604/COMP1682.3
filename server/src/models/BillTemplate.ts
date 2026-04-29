import mongoose, { Schema, Document, Types } from 'mongoose';

export type BillTemplateCycle = 'DAILY' | 'WEEKLY' | 'MONTHLY';
export type BillTemplateStatus = 'ACTIVE' | 'PAUSED' | 'ARCHIVED';

export interface IBillTemplateItem {
    name: string;
    amount: number;      // 0 = "Nhập sau" (biến động như điện, nước)
    splitType: 'EQUAL' | 'PERCENTAGE' | 'CUSTOM' | 'WEIGHT';
    assignedTo: string[]; // [] = tất cả members active khi generate
    splits: { userId: string; value: number }[];
}

export interface IBillTemplate extends Document {
    _id: Types.ObjectId;
    groupId: string;           // ref: Group

    // Template info
    name: string;              // "Tiền điện", "Thuê nhà" — dùng làm Invoice.title
    description?: string;

    // Schedule
    billingCycle: BillTemplateCycle;
    billingDay?: number;       // WEEKLY: 1-7 (1=Mon), MONTHLY: 1-28, DAILY: không cần

    // Invoice config
    currency: string;
    items: IBillTemplateItem[];
    payerId: string;           // uploadedBy của invoice sẽ tạo (ai đại diện trả)

    // State
    status: BillTemplateStatus;
    createdBy: string;         // ref: User

    // Tracking
    lastGeneratedAt?: Date;
    nextBillDate: Date;        // Tính sẵn để scheduler query nhanh

    createdAt: Date;
    updatedAt: Date;
}

const BillTemplateItemSchema = new Schema<IBillTemplateItem>({
    name: { type: String, required: true, trim: true },
    amount: { type: Number, required: true, default: 0 },
    splitType: {
        type: String,
        enum: ['EQUAL', 'PERCENTAGE', 'CUSTOM', 'WEIGHT'],
        default: 'EQUAL'
    },
    assignedTo: [{ type: String, ref: 'User' }],
    splits: [{
        userId: { type: String, required: true },
        value: { type: Number, required: true }
    }]
}, { _id: false });

const BillTemplateSchema = new Schema<IBillTemplate>({
    groupId: {
        type: String,
        required: true,
        ref: 'Group'
    },
    name: {
        type: String,
        required: true,
        trim: true
    },
    description: {
        type: String,
        default: null
    },
    billingCycle: {
        type: String,
        enum: ['DAILY', 'WEEKLY', 'MONTHLY'],
        required: true
    },
    billingDay: {
        type: Number,
        default: null
        // WEEKLY: 1-7 (1=Monday), MONTHLY: 1-28, DAILY: ignored
    },
    currency: {
        type: String,
        default: 'VND',
        uppercase: true
    },
    items: {
        type: [BillTemplateItemSchema],
        required: true
    },
    payerId: {
        type: String,
        required: true,
        ref: 'User'
    },
    status: {
        type: String,
        enum: ['ACTIVE', 'PAUSED', 'ARCHIVED'],
        default: 'ACTIVE'
    },
    createdBy: {
        type: String,
        required: true,
        ref: 'User'
    },
    lastGeneratedAt: {
        type: Date,
        default: null
    },
    nextBillDate: {
        type: Date,
        required: true
    }
}, {
    timestamps: true,
    collection: 'bill_templates'
});

// Indexes
BillTemplateSchema.index({ groupId: 1 });
BillTemplateSchema.index({ status: 1, nextBillDate: 1 }); // Scheduler query
BillTemplateSchema.index({ createdBy: 1 });

export const BillTemplate = mongoose.model<IBillTemplate>('BillTemplate', BillTemplateSchema);
