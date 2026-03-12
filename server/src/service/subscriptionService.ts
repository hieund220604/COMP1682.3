import mongoose from 'mongoose';
import { Subscription } from '../models/Subscription';
import { SubscriptionMember } from '../models/SubscriptionMember';
import { BillingHistory } from '../models/BillingHistory';
import { GroupMember } from '../models/GroupMember';
import { User } from '../models/User';
import {
    CreateSubscriptionRequest,
    SubscriptionResponse,
    BillingCycle,
    SubscriptionStatus,
    ChargeResult,
    ProcessChargesResponse
} from '../type/subscription';
import { transactionService } from './transactionService';
import { TransactionType } from '../type/transaction';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function transformUser(user: any) {
    if (!user) return undefined;
    return {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName ?? undefined,
        avatarUrl: user.avatarUrl ?? undefined
    };
}

function calculateNextBillingDate(fromDate: Date, cycle: BillingCycle): Date {
    const next = new Date(fromDate);
    switch (cycle) {
        case BillingCycle.WEEKLY:
            next.setDate(next.getDate() + 7);
            break;
        case BillingCycle.MONTHLY:
            next.setMonth(next.getMonth() + 1);
            break;
        case BillingCycle.YEARLY:
            next.setFullYear(next.getFullYear() + 1);
            break;
    }
    return next;
}

// ─────────────────────────────────────────────────────────────────────────────
// Service
// ─────────────────────────────────────────────────────────────────────────────

export const subscriptionService = {

    // ── CREATE ──────────────────────────────────────────────────────────────

    async createSubscription(userId: string, data: CreateSubscriptionRequest): Promise<SubscriptionResponse> {
        const membership = await GroupMember.findOne({ groupId: data.groupId, userId, leftAt: null });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Only group owner or admin can create subscriptions');
        }

        const groupMembers = await GroupMember.find({ groupId: data.groupId, leftAt: null });

        if (groupMembers.length === 0) {
            throw new Error('Group has no active members');
        }

        // Integer division to avoid rounding errors (VND has no decimals)
        const decimals = 0;
        const totalMinor = Math.round(data.amount * Math.pow(10, decimals));
        const memberCount = groupMembers.length;
        const baseShare = Math.floor(totalMinor / memberCount);
        const remainder = totalMinor - (baseShare * memberCount);

        const startDate = data.startDate || new Date();

        const subscription = await Subscription.create({
            groupId: data.groupId,
            name: data.name,
            description: data.description,
            amount: data.amount,
            currency: 'VND',
            billingCycle: data.billingCycle,
            status: SubscriptionStatus.ACTIVE,
            nextBillingDate: startDate,
            createdBy: userId,
            retryCount: 0
        });

        // First member gets base + remainder; others get base
        const memberShares = groupMembers.map((gm, index) => ({
            subscriptionId: subscription._id.toString(),
            userId: gm.userId,
            shareAmount: index === 0 ? baseShare + remainder : baseShare,
            status: 'ACTIVE'
        }));

        await SubscriptionMember.insertMany(memberShares);

        return this.getSubscriptionById(userId, subscription._id.toString());
    },

    // ── READ ─────────────────────────────────────────────────────────────────

    async getSubscriptionById(userId: string, subscriptionId: string): Promise<SubscriptionResponse> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        const members = await SubscriptionMember.find({ subscriptionId: subscription._id.toString() });
        const users = await User.find({ _id: { $in: members.map(m => m.userId) } }).select('_id email displayName avatarUrl');
        const userMap = new Map();
        users.forEach(u => userMap.set(u._id.toString(), u));

        const { Group } = await import('../models/Group');
        const group = await Group.findById(subscription.groupId).select('name');
        const creator = await User.findById(subscription.createdBy).select('displayName email');

        return {
            id: subscription._id.toString(),
            groupId: subscription.groupId,
            groupName: group?.name ?? 'Unknown Group',
            name: subscription.name,
            description: subscription.description ?? undefined,
            amount: Number(subscription.amount),
            currency: subscription.currency,
            billingCycle: subscription.billingCycle as BillingCycle,
            status: subscription.status as SubscriptionStatus,
            nextBillingDate: subscription.nextBillingDate,
            lastBilledAt: subscription.lastBilledAt ?? undefined,
            createdBy: subscription.createdBy,
            createdByName: creator?.displayName ?? creator?.email ?? 'Unknown',
            createdAt: subscription.createdAt,
            cancelledAt: subscription.cancelledAt ?? undefined,
            members: members.map(m => ({
                id: m._id.toString(),
                userId: m.userId,
                shareAmount: Number(m.shareAmount),
                status: m.status,
                joinedAt: m.joinedAt,
                leftAt: m.leftAt ?? undefined,
                user: transformUser(userMap.get(String(m.userId)))
            })),
            memberCount: members.length
        };
    },

    async getSubscriptionsForUser(userId: string): Promise<SubscriptionResponse[]> {
        const memberSubscriptions = await SubscriptionMember.find({ userId, status: 'ACTIVE' });
        const subscriptionIds = memberSubscriptions.map(m => m.subscriptionId);

        const subscriptions = await Subscription.find({
            _id: { $in: subscriptionIds },
            status: { $ne: SubscriptionStatus.CANCELLED }
        }).sort({ createdAt: -1 });

        return Promise.all(subscriptions.map(s => this.getSubscriptionById(userId, s._id.toString())));
    },

    // ── GET BILLING HISTORY ──────────────────────────────────────────────────

    async getBillingHistory(userId: string, subscriptionId: string): Promise<any[]> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        // Verify user is a member
        const membership = await GroupMember.findOne({ groupId: subscription.groupId, userId, leftAt: null });
        if (!membership) throw new Error('Access denied');

        const history = await BillingHistory.find({ subscriptionId })
            .sort({ billingDate: -1 })
            .limit(50);

        return history.map(h => ({
            id: h._id.toString(),
            billingDate: h.billingDate,
            amount: h.amount,
            currency: h.currency,
            status: h.status,
            membersCharged: h.membersCharged,
            membersFailed: h.membersFailed,
            totalCollected: h.totalCollected,
            failureReason: h.failureReason ?? undefined,
            memberResults: h.memberResults
        }));
    },

    // ── CANCEL ───────────────────────────────────────────────────────────────

    async cancelSubscription(userId: string, subscriptionId: string): Promise<SubscriptionResponse> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        const membership = await GroupMember.findOne({
            groupId: subscription.groupId,
            userId,
            leftAt: null
        });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Only group owner or admin can cancel subscriptions');
        }

        await Subscription.findByIdAndUpdate(subscriptionId, {
            status: SubscriptionStatus.CANCELLED,
            cancelledAt: new Date()
        });

        // Notify all active members
        const activeMembers = await SubscriptionMember.find({ subscriptionId, status: 'ACTIVE' });
        const memberUserIds = activeMembers.map(m => m.userId).filter(uid => uid !== userId);
        if (memberUserIds.length > 0) {
            await notificationService.createBulkNotifications(
                memberUserIds,
                NotificationType.SUBSCRIPTION_CANCELLED,
                'Subscription Cancelled',
                `The subscription "${subscription.name}" has been cancelled by an admin.`,
                { subscriptionId }
            );
        }

        return this.getSubscriptionById(userId, subscriptionId);
    },

    // ── LEAVE (Member self-withdrawal) ────────────────────────────────────────

    /**
     * NEW: Allows a regular member to leave a specific subscription
     * without leaving the group.
     */
    async leaveSubscription(userId: string, subscriptionId: string): Promise<void> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        // Check if user is actually in this subscription
        const subMember = await SubscriptionMember.findOne({
            subscriptionId,
            userId,
            status: 'ACTIVE'
        });

        if (!subMember) {
            throw new Error('You are not an active member of this subscription');
        }

        // Creator cannot leave their own subscription (they are the receiver)
        if (subscription.createdBy === userId) {
            throw new Error('Subscription creator cannot leave. Cancel the subscription instead.');
        }

        // Mark member as LEFT in SubscriptionMember
        await SubscriptionMember.findByIdAndUpdate(subMember._id, {
            status: 'LEFT',
            leftAt: new Date()
        });

        // Redistribute remaining amount among still-active members (excluding creator)
        const remainingMembers = await SubscriptionMember.find({
            subscriptionId,
            status: 'ACTIVE',
            userId: { $ne: subscription.createdBy }
        });

        if (remainingMembers.length > 0) {
            const decimals = 0;
            const totalMinor = Math.round(Number(subscription.amount) * Math.pow(10, decimals));
            const baseShare = Math.floor(totalMinor / remainingMembers.length);
            const remainder = totalMinor - (baseShare * remainingMembers.length);

            for (let i = 0; i < remainingMembers.length; i++) {
                const newShare = i === 0 ? baseShare + remainder : baseShare;
                await SubscriptionMember.findByIdAndUpdate(remainingMembers[i]._id, {
                    shareAmount: newShare
                });
            }
        } else {
            // ── AUTO-CANCEL: No active non-creator members remain ───────────
            await Subscription.findByIdAndUpdate(subscriptionId, {
                status: SubscriptionStatus.CANCELLED,
                cancelledAt: new Date()
            });
        }
    },

    // ── PAUSE ────────────────────────────────────────────────────────────────

    /**
     * NEW: Pause an active subscription. Billing will skip until resumed.
     */
    async pauseSubscription(userId: string, subscriptionId: string): Promise<SubscriptionResponse> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        const membership = await GroupMember.findOne({
            groupId: subscription.groupId,
            userId,
            leftAt: null
        });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Only group owner or admin can pause subscriptions');
        }

        if (subscription.status !== SubscriptionStatus.ACTIVE) {
            throw new Error('Only active subscriptions can be paused');
        }

        await Subscription.findByIdAndUpdate(subscriptionId, {
            status: SubscriptionStatus.PAUSED
        });

        return this.getSubscriptionById(userId, subscriptionId);
    },

    // ── RESUME ───────────────────────────────────────────────────────────────

    async resumeSubscription(userId: string, subscriptionId: string): Promise<SubscriptionResponse> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        const membership = await GroupMember.findOne({
            groupId: subscription.groupId,
            userId,
            leftAt: null
        });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Only group owner or admin can resume subscriptions');
        }

        if (subscription.status !== SubscriptionStatus.CANCELLED &&
            subscription.status !== SubscriptionStatus.PAST_DUE &&
            subscription.status !== SubscriptionStatus.PAUSED) {
            throw new Error('Subscription is not cancelled, paused, or past due');
        }

        // Attempt to process immediately for CANCELLED/PAST_DUE
        if (subscription.status !== SubscriptionStatus.PAUSED) {
            const result = await this.processSingleSubscription(subscription, true);
            if (!result.success) {
                const reason = result.failedMembers.map(m => m.reason).join(', ');
                throw new Error(`Cannot resume: ${reason}`);
            }
        } else {
            // PAUSED → just set back to ACTIVE
            await Subscription.findByIdAndUpdate(subscriptionId, {
                status: SubscriptionStatus.ACTIVE
            });
        }

        return this.getSubscriptionById(userId, subscriptionId);
    },

    // ── UPDATE ───────────────────────────────────────────────────────────────

    async updateSubscription(userId: string, subscriptionId: string, updates: any): Promise<SubscriptionResponse> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        const membership = await GroupMember.findOne({
            groupId: subscription.groupId,
            userId,
            leftAt: null
        });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Only group owner or admin can update subscriptions');
        }

        if (subscription.status === SubscriptionStatus.CANCELLED) {
            throw new Error('Cannot update cancelled subscription');
        }

        // If amount changed, recalculate shares for active members (excl. creator)
        if (updates.amount && updates.amount !== subscription.amount) {
            const members = await SubscriptionMember.find({
                subscriptionId,
                status: 'ACTIVE',
                userId: { $ne: subscription.createdBy }
            });

            if (members.length > 0) {
                const decimals = 0;
                const totalMinor = Math.round(updates.amount * Math.pow(10, decimals));
                const memberCount = members.length;
                const baseShare = Math.floor(totalMinor / memberCount);
                const remainder = totalMinor - (baseShare * memberCount);

                for (let i = 0; i < members.length; i++) {
                    const newShare = i === 0 ? baseShare + remainder : baseShare;
                    await SubscriptionMember.findByIdAndUpdate(members[i]._id, { shareAmount: newShare });
                }
            }
        }

        // If billing cycle changed, recalculate next billing date
        if (updates.billingCycle && updates.billingCycle !== subscription.billingCycle) {
            updates.nextBillingDate = calculateNextBillingDate(
                subscription.nextBillingDate,
                updates.billingCycle as BillingCycle
            );
        }

        await Subscription.findByIdAndUpdate(subscriptionId, updates);
        return this.getSubscriptionById(userId, subscriptionId);
    },

    // ── PROCESS RENEWALS (Cron) ───────────────────────────────────────────────

    async processRenewals(): Promise<ProcessChargesResponse> {
        const now = new Date();
        const RETRY_DELAY_HOURS = 24;
        const retryThreshold = new Date(now.getTime() - RETRY_DELAY_HOURS * 60 * 60 * 1000);

        const dueSubscriptions = await Subscription.find({
            $or: [
                // Active subscriptions due for billing
                { status: SubscriptionStatus.ACTIVE, nextBillingDate: { $lte: now } },
                // Past due subscriptions ready for retry (24h gap)
                {
                    status: SubscriptionStatus.PAST_DUE,
                    $or: [
                        { lastAttemptAt: { $exists: false } },
                        { lastAttemptAt: { $lte: retryThreshold } }
                    ]
                }
            ]
        });

        const results: ChargeResult[] = [];

        for (const sub of dueSubscriptions) {
            // Guard: skip PAUSED subscriptions
            if (sub.status === SubscriptionStatus.PAUSED) continue;

            if (sub.status === SubscriptionStatus.PAST_DUE && sub.retryCount >= 3) {
                await Subscription.findByIdAndUpdate(sub._id, { status: SubscriptionStatus.CANCELLED });
                continue;
            }

            // ── OPTIMISTIC LOCKING: Prevent concurrent billing ──────────────
            // Atomically mark as PROCESSING only if status hasn't changed
            const locked = await Subscription.findOneAndUpdate(
                { _id: sub._id, status: sub.status },
                { $set: { status: 'PROCESSING' as any } },
                { new: false }
            );
            if (!locked) {
                // Another process already picked this up — skip
                continue;
            }

            let result: ChargeResult;
            try {
                result = await this.processSingleSubscription(sub, false);
            } catch (err: any) {
                // Restore status if something went wrong mid-process
                await Subscription.findByIdAndUpdate(sub._id, { status: sub.status });
                result = {
                    subscriptionId: sub._id.toString(),
                    subscriptionName: sub.name,
                    success: false,
                    totalCharged: 0,
                    membersCharged: 0,
                    membersFailed: 0,
                    failedMembers: [{ userId: 'system', reason: err.message }],
                    autoCancelled: false
                };
            }

            results.push(result);
        }

        return {
            processedAt: now,
            totalSubscriptions: dueSubscriptions.length,
            successfulCharges: results.filter(r => r.success).length,
            failedCharges: results.filter(r => !r.success).length,
            results
        };
    },

    // ── CORE BILLING LOGIC ────────────────────────────────────────────────────

    /**
     * Processes a single subscription billing cycle.
     * Uses MongoDB transactions to prevent balance race conditions.
     */
    async processSingleSubscription(subscription: any, isResume: boolean): Promise<ChargeResult> {
        const members = await SubscriptionMember.find({
            subscriptionId: subscription._id.toString(),
            status: 'ACTIVE'
        });

        const result: ChargeResult = {
            subscriptionId: subscription._id.toString(),
            subscriptionName: subscription.name,
            success: true,
            totalCharged: 0,
            membersCharged: 0,
            membersFailed: 0,
            failedMembers: [],
            autoCancelled: false
        };

        const creatorId = subscription.createdBy;
        const failedMembers: { userId: string; reason: string }[] = [];

        // ── 1. ATOMIC BALANCE CHECK (before any deduction) ─────────────────
        for (const member of members) {
            if (member.userId === creatorId) continue; // Creator receives, doesn't pay

            const user = await User.findById(member.userId);
            if (!user || user.balance < member.shareAmount) {
                failedMembers.push({
                    userId: member.userId,
                    reason: `Insufficient balance: ${user?.balance ?? 0} < ${member.shareAmount}`
                });
            }
        }

        // ── 2. HANDLE FAILURE ──────────────────────────────────────────────
        if (failedMembers.length > 0) {
            result.success = false;
            result.failedMembers = failedMembers;
            result.membersFailed = failedMembers.length;

            const newRetryCount = (subscription.retryCount || 0) + 1;

            if (isResume) return result;

            if (newRetryCount <= 3) {
                await Subscription.findByIdAndUpdate(subscription._id, {
                    status: SubscriptionStatus.PAST_DUE,
                    retryCount: newRetryCount,
                    lastAttemptAt: new Date(),
                    failureReason: `Failed members: ${failedMembers.map(m => m.userId).join(', ')}`
                });
            } else {
                await Subscription.findByIdAndUpdate(subscription._id, {
                    status: SubscriptionStatus.CANCELLED,
                    cancelledAt: new Date(),
                    retryCount: newRetryCount,
                    failureReason: `Cancelled after 3 retries. Failed: ${failedMembers.map(m => m.userId).join(', ')}`
                });
                result.autoCancelled = true;
            }

            // Log billing failure
            await BillingHistory.create({
                subscriptionId: subscription._id.toString(),
                groupId: subscription.groupId,
                billingDate: new Date(),
                amount: Number(subscription.amount),
                currency: subscription.currency,
                status: 'FAILED',
                membersCharged: 0,
                membersFailed: failedMembers.length,
                totalCollected: 0,
                failureReason: failedMembers.map(m => `${m.userId}: ${m.reason}`).join('; '),
                memberResults: failedMembers.map(m => ({
                    userId: m.userId,
                    shareAmount: members.find(mem => mem.userId === m.userId)?.shareAmount ?? 0,
                    success: false,
                    reason: m.reason
                }))
            });

            // Notify failed members
            try {
                const failedUserIds = failedMembers.map(m => m.userId);
                await notificationService.createBulkNotifications(
                    failedUserIds,
                    NotificationType.SUBSCRIPTION_BILLING_FAILED,
                    'Subscription Payment Failed',
                    `Your payment for "${subscription.name}" failed due to insufficient balance.`,
                    { subscriptionId: subscription._id.toString() }
                );
            } catch (_) { /* Notification failure should not block billing result */ }

            return result;
        }

        // ── 3. EXECUTE TRANSFERS using MongoDB session (race condition guard) ──
        const session = await mongoose.startSession();
        let totalCollected = 0;
        const memberResultsSuccess: any[] = [];

        try {
            session.startTransaction();

            for (const member of members) {
                if (member.userId === creatorId) continue;

                const shareAmount = Number(member.shareAmount);

                const memberDoc = await User.findById(member.userId).session(session);
                const balanceBefore = memberDoc?.balance || 0;

                // Deduct from member
                await User.findByIdAndUpdate(
                    member.userId,
                    { $inc: { balance: -shareAmount } },
                    { session }
                );

                // Add to creator
                await User.findByIdAndUpdate(
                    creatorId,
                    { $inc: { balance: shareAmount } },
                    { session }
                );

                totalCollected += shareAmount;
                result.membersCharged++;
                memberResultsSuccess.push({
                    userId: member.userId,
                    shareAmount,
                    success: true
                });

                // Log transaction for member (outside transaction to avoid nested writes issue)
                const memberAfter = await User.findById(member.userId);
                await transactionService.createTransaction({
                    userId: member.userId,
                    groupId: subscription.groupId,
                    type: TransactionType.SUBSCRIPTION_FEE,
                    amount: shareAmount,
                    balanceBefore,
                    balanceAfter: memberAfter?.balance || 0,
                    currency: subscription.currency,
                    description: `Paid for subscription: ${subscription.name}`,
                    referenceId: subscription._id.toString(),
                    referenceType: 'SUBSCRIPTION'
                });
            }

            await session.commitTransaction();
        } catch (err) {
            await session.abortTransaction();
            throw err;
        } finally {
            session.endSession();
        }

        // Log creator receipts (after commit)
        for (const member of members) {
            if (member.userId === creatorId) continue;
            const shareAmount = Number(member.shareAmount);
            const creatorDoc = await User.findById(creatorId);
            await transactionService.createTransaction({
                userId: creatorId,
                groupId: subscription.groupId,
                type: TransactionType.TRANSFER_RECEIVED,
                amount: shareAmount,
                balanceBefore: (creatorDoc?.balance || 0) - shareAmount,
                balanceAfter: creatorDoc?.balance || 0,
                currency: subscription.currency,
                description: `Received subscription share from member for: ${subscription.name}`,
                referenceId: subscription._id.toString(),
                referenceType: 'SUBSCRIPTION'
            });
        }

        // ── 4. UPDATE SUBSCRIPTION ────────────────────────────────────────────
        let nextDate = calculateNextBillingDate(subscription.nextBillingDate, subscription.billingCycle as BillingCycle);
        if (nextDate < new Date()) {
            nextDate = calculateNextBillingDate(new Date(), subscription.billingCycle as BillingCycle);
        }

        await Subscription.findByIdAndUpdate(subscription._id, {
            status: SubscriptionStatus.ACTIVE,
            retryCount: 0,
            failureReason: null,
            lastBilledAt: new Date(),
            nextBillingDate: nextDate
        });

        // ── 5. SAVE BILLING HISTORY ───────────────────────────────────────────
        await BillingHistory.create({
            subscriptionId: subscription._id.toString(),
            groupId: subscription.groupId,
            billingDate: new Date(),
            amount: Number(subscription.amount),
            currency: subscription.currency,
            status: 'SUCCESS',
            membersCharged: result.membersCharged,
            membersFailed: 0,
            totalCollected,
            memberResults: memberResultsSuccess
        });

        // ── 6. NOTIFY ALL CHARGED MEMBERS ────────────────────────────────────
        try {
            const chargedUserIds = members
                .filter(m => m.userId !== creatorId)
                .map(m => m.userId);

            if (chargedUserIds.length > 0) {
                await notificationService.createBulkNotifications(
                    chargedUserIds,
                    NotificationType.SUBSCRIPTION_BILLING_SUCCESS,
                    'Subscription Payment Charged',
                    `Your share for "${subscription.name}" (${totalCollected / chargedUserIds.length} ${subscription.currency}) has been deducted.`,
                    { subscriptionId: subscription._id.toString() }
                );
            }
        } catch (_) { /* Notification failure should not block billing result */ }

        result.totalCharged = totalCollected;
        return result;
    }
};
