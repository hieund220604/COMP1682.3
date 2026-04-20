/**
 * Subscription Service â€” v2
 *
 * Core model:
 *   Subscription   = container (ACTIVE | CANCELLED)
 *   SubscriptionMember = billing unit per member, independent cycle from joinedAt
 *
 * Key rules:
 *   1. Charge on accept (member pays first cycle immediately)
 *   2. Billing per-member: each member has their own nextBillingDate
 *   3. Leave = pay current cycle obligation only
 *   4. Billing fail = kick that member (sub stays ACTIVE)
 *   5. Cancel = owner action, no refund (members only paid per cycle)
 */

import mongoose from 'mongoose';
import { Subscription } from '../models/Subscription';
import { SubscriptionMember } from '../models/SubscriptionMember';
import { SubInvitation } from '../models/SubInvitation';
import { BillingHistory } from '../models/BillingHistory';
import { GroupMember } from '../models/GroupMember';
import { User } from '../models/User';
import {
    BillingCycle,
    SubscriptionStatus,
    CreateSubscriptionRequest,
    SubscriptionResponse,
    SubscriptionMemberResponse,
    SubInvitationResponse,
    ProcessChargesResponse,
    MemberChargeResult,
} from '../type/subscription';
import { transactionService } from './transactionService';
import { TransactionType } from '../type/transaction';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import { buildRedisKey, deleteKeysByPrefix, getJsonCache, setJsonCache } from '../redis';

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Helpers
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

function transformUser(user: any) {
    if (!user) return undefined;
    return {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName ?? undefined,
        avatarUrl: user.avatarUrl ?? undefined,
    };
}

/**
 * Calculate the next billing date given a start date and billing cycle.
 * Handles month-end overflow (e.g. Jan 31 â†’ Feb 28) and leap years.
 */
function calculateNextBillingDate(fromDate: Date, cycle: BillingCycle): Date {
    const next = new Date(fromDate);
    switch (cycle) {
        case BillingCycle.DAILY:
            next.setDate(next.getDate() + 1);
            break;
        case BillingCycle.WEEKLY:
            next.setDate(next.getDate() + 7);
            break;
        case BillingCycle.MONTHLY: {
            const originalDay = fromDate.getDate();
            next.setMonth(next.getMonth() + 1);
            if (next.getDate() !== originalDay) next.setDate(0);
            break;
        }
        case BillingCycle.YEARLY: {
            const originalDay = fromDate.getDate();
            const originalMonth = fromDate.getMonth();
            next.setFullYear(next.getFullYear() + 1);
            if (next.getDate() !== originalDay || next.getMonth() !== originalMonth) {
                next.setDate(0);
            }
            break;
        }
    }
    return next;
}

/**
 * Warning window before the billing date based on cycle length.
 */
function warningWindowMs(cycle: BillingCycle): number {
    switch (cycle) {
        case BillingCycle.DAILY:  return 0;                            // no warning â€” too short
        case BillingCycle.WEEKLY: return 1 * 24 * 60 * 60 * 1000;    // 1 day
        case BillingCycle.MONTHLY: return 3 * 24 * 60 * 60 * 1000;   // 3 days
        case BillingCycle.YEARLY: return 7 * 24 * 60 * 60 * 1000;    // 7 days
    }
}

// â”€â”€ Cache helpers â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

const DETAIL_TTL = 60;
const LIST_TTL = 45;
const BILLING_HISTORY_TTL = 30;

const detailKey = (subId: string, userId: string) =>
    buildRedisKey('cache', 'sub2', 'detail', subId, userId);

const userListKey = (userId: string) =>
    buildRedisKey('cache', 'sub2', 'user', userId, 'list');

const billingHistoryKey = (subId: string, userId: string) =>
    buildRedisKey('cache', 'sub2', 'history', subId, userId);

async function invalidateSubCache(subscriptionId: string): Promise<void> {
    await deleteKeysByPrefix(buildRedisKey('cache', 'sub2', 'detail', subscriptionId));
    await deleteKeysByPrefix(buildRedisKey('cache', 'sub2', 'history', subscriptionId));

    const members = await SubscriptionMember.find({ subscriptionId }).select('userId');
    const userIds = [...new Set(members.map((m) => m.userId))];
    for (const uid of userIds) {
        await deleteKeysByPrefix(userListKey(uid));
    }
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Service
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

export const subscriptionService = {

    // â”€â”€ CREATE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Owner creates a subscription. Status is ACTIVE immediately.
     * No members are added â€” owner invites them separately.
     */
    async createSubscription(
        userId: string,
        data: CreateSubscriptionRequest,
    ): Promise<SubscriptionResponse> {
        // Only group owner/admin can create
        const membership = await GroupMember.findOne({
            groupId: data.groupId,
            userId,
            leftAt: null,
        });
        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Only group owner or admin can create subscriptions');
        }

        const subscription = await Subscription.create({
            groupId: data.groupId,
            name: data.name,
            description: data.description ?? null,
            amount: data.amount,
            currency: 'VND',
            billingCycle: data.billingCycle,
            status: SubscriptionStatus.ACTIVE,
            createdBy: userId,
        });

        await invalidateSubCache(subscription._id.toString());
        return this.getSubscriptionById(userId, subscription._id.toString());
    },

    // â”€â”€ READ â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    async getSubscriptionById(userId: string, subscriptionId: string): Promise<SubscriptionResponse> {
        const cacheKey = detailKey(subscriptionId, userId);
        const cached = await getJsonCache<SubscriptionResponse>(cacheKey);
        if (cached) return cached;

        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        const [members, pendingInvitations] = await Promise.all([
            SubscriptionMember.find({ subscriptionId: subscription._id.toString() }),
            SubInvitation.find({ subscriptionId: subscription._id.toString(), status: 'PENDING' }),
        ]);

        const allUserIds = [
            ...new Set([
                ...members.map((m) => m.userId),
                ...pendingInvitations.map((i) => i.inviteeId),
            ]),
        ];
        const users = await User.find({ _id: { $in: allUserIds } }).select('_id email displayName avatarUrl');
        const userMap = new Map<string, any>();
        users.forEach((u) => userMap.set(u._id.toString(), u));

        const { Group } = await import('../models/Group');
        const [group, creator] = await Promise.all([
            Group.findById(subscription.groupId).select('name'),
            User.findById(subscription.createdBy).select('displayName email'),
        ]);

        const memberResponses: SubscriptionMemberResponse[] = members.map((m) => ({
            id: m._id.toString(),
            userId: m.userId,
            amount: Number(m.amount),
            status: m.status,
            joinedAt: m.joinedAt,
            nextBillingDate: m.nextBillingDate,
            lastChargedAt: m.lastChargedAt,
            retryCount: m.retryCount,
            leftAt: m.leftAt ?? undefined,
            user: transformUser(userMap.get(m.userId)),
        }));

        const invitationResponses: SubInvitationResponse[] = pendingInvitations.map((inv) => ({
            id: inv._id.toString(),
            subscriptionId: inv.subscriptionId,
            inviteeId: inv.inviteeId,
            invitedBy: inv.invitedBy,
            status: inv.status,
            expiresAt: inv.expiresAt,
            createdAt: inv.createdAt,
            invitee: transformUser(userMap.get(inv.inviteeId)),
        }));

        const response: SubscriptionResponse = {
            id: subscription._id.toString(),
            groupId: subscription.groupId,
            groupName: group?.name ?? 'Unknown Group',
            name: subscription.name,
            description: subscription.description ?? undefined,
            amount: Number(subscription.amount),
            currency: subscription.currency,
            billingCycle: subscription.billingCycle as BillingCycle,
            status: subscription.status as SubscriptionStatus,
            createdBy: subscription.createdBy,
            createdByName: creator?.displayName ?? creator?.email ?? 'Unknown',
            createdAt: subscription.createdAt,
            cancelledAt: subscription.cancelledAt ?? undefined,
            members: memberResponses,
            memberCount: members.filter((m) => m.status === 'ACTIVE').length,
            pendingInvitations: invitationResponses,
        };

        await setJsonCache(cacheKey, response, DETAIL_TTL);
        return response;
    },

    async getSubscriptionsForUser(userId: string): Promise<SubscriptionResponse[]> {
        const cacheKey = userListKey(userId);
        const cached = await getJsonCache<SubscriptionResponse[]>(cacheKey);
        if (cached) return cached;

        // User sees subs they own OR are an active member of
        const [memberSubs, ownedSubs] = await Promise.all([
            SubscriptionMember.find({ userId, status: 'ACTIVE' }).select('subscriptionId'),
            Subscription.find({ createdBy: userId, status: SubscriptionStatus.ACTIVE }).select('_id'),
        ]);

        const idSet = new Set<string>([
            ...memberSubs.map((m) => m.subscriptionId),
            ...ownedSubs.map((s) => s._id.toString()),
        ]);

        const subscriptions = await Subscription.find({
            _id: { $in: [...idSet] },
        }).sort({ createdAt: -1 });

        const result = await Promise.all(
            subscriptions.map((s) => this.getSubscriptionById(userId, s._id.toString())),
        );

        await setJsonCache(cacheKey, result, LIST_TTL);
        return result;
    },

    // â”€â”€ BILLING HISTORY â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    async getBillingHistory(userId: string, subscriptionId: string): Promise<any[]> {
        const cacheKey = billingHistoryKey(subscriptionId, userId);
        const cached = await getJsonCache<any[]>(cacheKey);
        if (cached) return cached;

        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');

        // Verify user is owner or member
        const isMember = await SubscriptionMember.findOne({ subscriptionId, userId });
        const isOwner = subscription.createdBy === userId;
        if (!isMember && !isOwner) throw new Error('Access denied');

        const history = await BillingHistory.find({ subscriptionId })
            .sort({ billingDate: -1 })
            .limit(50);

        const result = history.map((h) => ({
            id: h._id.toString(),
            billingDate: h.billingDate,
            amount: h.amount,
            currency: h.currency,
            status: h.status,
            membersCharged: h.membersCharged,
            membersFailed: h.membersFailed,
            totalCollected: h.totalCollected,
            failureReason: h.failureReason ?? undefined,
            memberResults: h.memberResults,
        }));

        await setJsonCache(cacheKey, result, BILLING_HISTORY_TTL);
        return result;
    },

    // â”€â”€ INVITE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Owner invites a group member to the subscription.
     * Guard: no duplicate PENDING invitations.
     */
    async inviteMember(
        ownerId: string,
        subscriptionId: string,
        inviteeId: string,
    ): Promise<SubInvitationResponse> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');
        if (subscription.status === SubscriptionStatus.CANCELLED) {
            throw new Error('Cannot invite to a cancelled subscription');
        }
        if (subscription.createdBy !== ownerId) {
            throw new Error('Only the subscription owner can invite members');
        }
        if (inviteeId === ownerId) {
            throw new Error('Owner cannot invite themselves');
        }

        // Must be a group member
        const groupMembership = await GroupMember.findOne({
            groupId: subscription.groupId,
            userId: inviteeId,
            leftAt: null,
        });
        if (!groupMembership) throw new Error('Invitee is not a member of the group');

        // Already an active sub member?
        const existing = await SubscriptionMember.findOne({
            subscriptionId,
            userId: inviteeId,
            status: 'ACTIVE',
        });
        if (existing) throw new Error('User is already an active member of this subscription');

        // Duplicate PENDING check
        const pendingInvite = await SubInvitation.findOne({
            subscriptionId,
            inviteeId,
            status: 'PENDING',
        });
        if (pendingInvite) {
            throw new Error('A pending invitation already exists for this user');
        }

        const invite = await SubInvitation.create({
            subscriptionId,
            inviteeId,
            invitedBy: ownerId,
            status: 'PENDING',
            expiresAt: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
        });

        // Notify invitee
        const sub = subscription;
        const owner = await User.findById(ownerId).select('displayName email');
        const ownerName = owner?.displayName ?? owner?.email ?? 'Owner';

        try {
            await notificationService.notify(
                inviteeId,
                NotificationType.SUB_INVITE_RECEIVED,
                'Subscription Invitation',
                `${ownerName} invited you to join "${sub.name}". Fee: ${sub.amount.toLocaleString()} VND/${sub.billingCycle.toLowerCase()}. You will be charged immediately on accept.`,
                { subscriptionId, invitationId: invite._id.toString() },
            );
        } catch (_) { /* notification failure should not block */ }

        await invalidateSubCache(subscriptionId);

        return {
            id: invite._id.toString(),
            subscriptionId: invite.subscriptionId,
            inviteeId: invite.inviteeId,
            invitedBy: invite.invitedBy,
            status: invite.status,
            expiresAt: invite.expiresAt,
            createdAt: invite.createdAt,
        };
    },

    /**
     * Member responds to a subscription invitation.
     * - accept=true: charge first cycle immediately, create SubscriptionMember
     * - accept=false: mark invitation DECLINED
     */
    async respondToInvitation(
        userId: string,
        invitationId: string,
        accept: boolean,
        categoryTagId?: string,
    ): Promise<void> {
        const invite = await SubInvitation.findById(invitationId);
        if (!invite) throw new Error('Invitation not found');
        if (invite.inviteeId !== userId) throw new Error('This invitation is not for you');
        if (invite.status !== 'PENDING') throw new Error('Invitation is no longer pending');
        if (invite.expiresAt < new Date()) {
            await SubInvitation.findByIdAndUpdate(invitationId, { status: 'EXPIRED' });
            throw new Error('Invitation has expired');
        }

        const subscription = await Subscription.findById(invite.subscriptionId);
        if (!subscription) throw new Error('Subscription not found');
        if (subscription.status === SubscriptionStatus.CANCELLED) {
            throw new Error('Subscription has been cancelled');
        }

        if (!accept) {
            await SubInvitation.findByIdAndUpdate(invitationId, { status: 'DECLINED' });

            // Notify owner
            const decliner = await User.findById(userId).select('displayName email');
            const declinerName = decliner?.displayName ?? decliner?.email ?? 'A user';
            try {
                await notificationService.notify(
                    subscription.createdBy,
                    NotificationType.SUB_INVITE_DECLINED,
                    'Invitation Declined',
                    `${declinerName} declined the invitation to "${subscription.name}".`,
                    { subscriptionId: invite.subscriptionId, invitationId },
                );
            } catch (_) { /* */ }

            await invalidateSubCache(invite.subscriptionId);
            return;
        }

        // â”€â”€ ACCEPT: check balance then charge atomically â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

        const fee = Number(subscription.amount);
        const member = await User.findById(userId);
        if (!member) throw new Error('User not found');
        if (member.balance < fee) {
            throw new Error(
                `Insufficient balance. Need ${fee} VND to join. Current balance: ${member.balance} VND. Short by ${fee - member.balance} VND.`,
            );
        }

        const now = new Date();
        const nextBillingDate = calculateNextBillingDate(now, subscription.billingCycle as BillingCycle);

        const session = await mongoose.startSession();
        try {
            session.startTransaction();

            const memberDoc = await User.findById(userId).session(session);
            if (!memberDoc || memberDoc.balance < fee) {
                await session.abortTransaction();
                throw new Error('Insufficient balance (race condition). Please try again.');
            }

            await User.findByIdAndUpdate(userId, { $inc: { balance: -fee } }, { session });
            await User.findByIdAndUpdate(subscription.createdBy, { $inc: { balance: fee } }, { session });

            await SubInvitation.findByIdAndUpdate(invitationId, { status: 'ACCEPTED' }, { session });

            await SubscriptionMember.create([{
                subscriptionId: invite.subscriptionId,
                userId,
                amount: fee,
                status: 'ACTIVE',
                joinedAt: now,
                nextBillingDate,
                lastChargedAt: now,
                retryCount: 0,
                categoryTagId: categoryTagId ?? null,
            }], { session });

            await session.commitTransaction();
        } catch (err) {
            await session.abortTransaction();
            throw err;
        } finally {
            session.endSession();
        }

        // Log transactions
        const memberAfter = await User.findById(userId);
        const ownerAfter = await User.findById(subscription.createdBy);
        await Promise.all([
            transactionService.createTransaction({
                userId,
                groupId: subscription.groupId,
                type: TransactionType.SUBSCRIPTION_FEE,
                amount: fee,
                balanceBefore: (memberAfter?.balance ?? 0) + fee,
                balanceAfter: memberAfter?.balance ?? 0,
                currency: subscription.currency,
                description: `Joined subscription: ${subscription.name}`,
                referenceId: invite.subscriptionId,
                referenceType: 'SUBSCRIPTION',
            }),
            transactionService.createTransaction({
                userId: subscription.createdBy,
                groupId: subscription.groupId,
                type: TransactionType.TRANSFER_RECEIVED,
                amount: fee,
                balanceBefore: (ownerAfter?.balance ?? 0) - fee,
                balanceAfter: ownerAfter?.balance ?? 0,
                currency: subscription.currency,
                description: `Member joined "${subscription.name}"`,
                referenceId: invite.subscriptionId,
                referenceType: 'SUBSCRIPTION',
            }),
        ]);

        // Notify owner & member
        const joiner = await User.findById(userId).select('displayName email');
        const joinerName = joiner?.displayName ?? joiner?.email ?? 'A user';
        try {
            await Promise.all([
                notificationService.notify(
                    subscription.createdBy,
                    NotificationType.SUB_INVITE_ACCEPTED,
                    'New Member Joined',
                    `${joinerName} joined "${subscription.name}" and paid ${fee.toLocaleString()} VND.`,
                    { subscriptionId: invite.subscriptionId },
                ),
                notificationService.notify(
                    userId,
                    NotificationType.SUBSCRIPTION_BILLING_SUCCESS,
                    'Joined Subscription',
                    `You joined "${subscription.name}". ${fee.toLocaleString()} VND charged. Next renewal: ${nextBillingDate.toDateString()}.`,
                    { subscriptionId: invite.subscriptionId },
                ),
            ]);
        } catch (_) { /* */ }

        await invalidateSubCache(invite.subscriptionId);
    },

    // â”€â”€ GET MEMBERS â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    async getMembers(userId: string, subscriptionId: string): Promise<{
        members: SubscriptionMemberResponse[];
        pendingInvitations: SubInvitationResponse[];
    }> {
        const sub = await this.getSubscriptionById(userId, subscriptionId);
        return {
            members: sub.members,
            pendingInvitations: sub.pendingInvitations ?? [],
        };
    },

    // â”€â”€ CANCEL â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Owner cancels the subscription.
     * All active members are marked LEFT immediately. No refunds.
     */
    async cancelSubscription(userId: string, subscriptionId: string): Promise<SubscriptionResponse> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');
        if (subscription.createdBy !== userId) {
            throw new Error('Only the subscription owner can cancel');
        }
        if (subscription.status === SubscriptionStatus.CANCELLED) {
            throw new Error('Subscription is already cancelled');
        }

        const activeMembers = await SubscriptionMember.find({
            subscriptionId,
            status: 'ACTIVE',
        });

        const now = new Date();
        await Promise.all([
            Subscription.findByIdAndUpdate(subscriptionId, {
                status: SubscriptionStatus.CANCELLED,
                cancelledAt: now,
            }),
            SubscriptionMember.updateMany(
                { subscriptionId, status: 'ACTIVE' },
                { status: 'LEFT', leftAt: now },
            ),
        ]);

        // Notify all active members
        const memberIds = activeMembers
            .map((m) => m.userId)
            .filter((uid) => uid !== userId);
        if (memberIds.length > 0) {
            try {
                await notificationService.createBulkNotifications(
                    memberIds,
                    NotificationType.SUBSCRIPTION_CANCELLED,
                    'Subscription Cancelled',
                    `"${subscription.name}" has been cancelled by the owner. No further charges will be made.`,
                    { subscriptionId },
                );
            } catch (_) { /* */ }
        }

        await invalidateSubCache(subscriptionId);
        return this.getSubscriptionById(userId, subscriptionId);
    },

    // â”€â”€ LEAVE â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Member leaves a subscription.
     * Obligation = current cycle's fee (if not yet charged), or 0 (if already charged this cycle).
     */
    async leaveSubscription(userId: string, subscriptionId: string): Promise<void> {
        const subscription = await Subscription.findById(subscriptionId);
        if (!subscription) throw new Error('Subscription not found');
        if (subscription.status === SubscriptionStatus.CANCELLED) {
            throw new Error('Subscription is already cancelled');
        }
        if (subscription.createdBy === userId) {
            throw new Error('Owner cannot leave. Cancel the subscription instead.');
        }

        const subMember = await SubscriptionMember.findOne({
            subscriptionId,
            userId,
            status: 'ACTIVE',
        });
        if (!subMember) throw new Error('You are not an active member of this subscription');

        // â”€â”€ Obligation calculation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        // cycleStart = nextBillingDate - 1 billingCycle
        // If lastChargedAt >= cycleStart â†’ already paid this cycle â†’ obligation = 0
        // Otherwise â†’ obligation = amount (settle current cycle)
        const cycleStart = calculateNextBillingDate(
            subMember.nextBillingDate,
            // We need to go BACK one cycle from nextBillingDate
            // Pass the negative... actually recalculate: cycleStart = nextBillingDate - 1 cycle
            // Trick: calculate by computing what "now - 1 cycle" would be using the reverse
            subscription.billingCycle as BillingCycle,
        );
        // Actually compute cycleStart properly:
        // cycleStart is the point in time when the current cycle BEGAN
        // nextBillingDate is when the current cycle ENDS
        // So cycleStart = nextBillingDate - 1 cycleDuration
        // We'll compute it by subtracting the cycle duration from nextBillingDate
        const nbd = new Date(subMember.nextBillingDate);
        let cycleStartDate: Date;
        switch (subscription.billingCycle as BillingCycle) {
            case BillingCycle.DAILY:
                cycleStartDate = new Date(nbd.getTime() - 24 * 60 * 60 * 1000);
                break;
            case BillingCycle.WEEKLY:
                cycleStartDate = new Date(nbd.getTime() - 7 * 24 * 60 * 60 * 1000);
                break;
            case BillingCycle.MONTHLY: {
                const d = new Date(nbd);
                d.setMonth(d.getMonth() - 1);
                cycleStartDate = d;
                break;
            }
            case BillingCycle.YEARLY: {
                const d = new Date(nbd);
                d.setFullYear(d.getFullYear() - 1);
                cycleStartDate = d;
                break;
            }
        }

        const alreadyPaidThisCycle = subMember.lastChargedAt >= cycleStartDate;
        const obligation = alreadyPaidThisCycle ? 0 : Number(subMember.amount);

        if (obligation > 0) {
            const user = await User.findById(userId);
            if (!user || user.balance < obligation) {
                const balance = user?.balance ?? 0;
                throw new Error(
                    `Insufficient balance. Need ${obligation} VND to leave. Current balance: ${balance} VND. Short by ${obligation - balance} VND.`,
                );
            }

            // Atomic charge
            const session = await mongoose.startSession();
            try {
                session.startTransaction();

                const memberDoc = await User.findById(userId).session(session);
                if (!memberDoc || memberDoc.balance < obligation) {
                    await session.abortTransaction();
                    throw new Error('Insufficient balance (race condition).');
                }

                await User.findByIdAndUpdate(userId, { $inc: { balance: -obligation } }, { session });
                await User.findByIdAndUpdate(subscription.createdBy, { $inc: { balance: obligation } }, { session });
                await SubscriptionMember.findByIdAndUpdate(
                    subMember._id,
                    { status: 'LEFT', leftAt: new Date() },
                    { session },
                );

                await session.commitTransaction();
            } catch (err) {
                await session.abortTransaction();
                throw err;
            } finally {
                session.endSession();
            }

            // Log transactions
            const memberAfter = await User.findById(userId);
            const ownerAfter = await User.findById(subscription.createdBy);
            await Promise.all([
                transactionService.createTransaction({
                    userId,
                    groupId: subscription.groupId,
                    type: TransactionType.SUBSCRIPTION_FEE,
                    amount: obligation,
                    balanceBefore: (memberAfter?.balance ?? 0) + obligation,
                    balanceAfter: memberAfter?.balance ?? 0,
                    currency: subscription.currency,
                    description: `Left subscription: ${subscription.name} (current cycle settlement)`,
                    referenceId: subscriptionId,
                    referenceType: 'SUBSCRIPTION',
                }),
                transactionService.createTransaction({
                    userId: subscription.createdBy,
                    groupId: subscription.groupId,
                    type: TransactionType.TRANSFER_RECEIVED,
                    amount: obligation,
                    balanceBefore: (ownerAfter?.balance ?? 0) - obligation,
                    balanceAfter: ownerAfter?.balance ?? 0,
                    currency: subscription.currency,
                    description: `Member left "${subscription.name}" â€” cycle settlement`,
                    referenceId: subscriptionId,
                    referenceType: 'SUBSCRIPTION',
                }),
            ]);
        } else {
            // Already paid this cycle â€” just mark LEFT
            await SubscriptionMember.findByIdAndUpdate(subMember._id, {
                status: 'LEFT',
                leftAt: new Date(),
            });
        }

        // Notifications
        const leaver = await User.findById(userId).select('displayName email');
        const leaverName = leaver?.displayName ?? leaver?.email ?? 'A member';
        try {
            await Promise.all([
                notificationService.notify(
                    subscription.createdBy,
                    NotificationType.SUBSCRIPTION_MEMBER_LEFT,
                    'Member Left',
                    `${leaverName} left "${subscription.name}".${obligation > 0 ? ` Settlement: ${obligation.toLocaleString()} VND.` : ''}`,
                    { subscriptionId },
                ),
                notificationService.notify(
                    userId,
                    NotificationType.SUBSCRIPTION_MEMBER_LEFT,
                    'Left Subscription',
                    `You have left "${subscription.name}".${obligation > 0 ? ` ${obligation.toLocaleString()} VND deducted as current cycle settlement.` : ' No charges applied.'}`,
                    { subscriptionId },
                ),
            ]);
        } catch (_) { /* */ }

        await invalidateSubCache(subscriptionId);
    },

    // â”€â”€ SCHEDULER: PROCESS PER-MEMBER BILLING â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /**
     * Called by the scheduler every hour.
     * Processes each SubscriptionMember independently.
     * Fails only kick the individual member â€” not the whole subscription.
     */
    async processRenewals(): Promise<ProcessChargesResponse> {
        const now = new Date();

        // Find active members whose billing date has passed, in active subs
        const dueMembers = await SubscriptionMember.aggregate([
            {
                $match: {
                    status: 'ACTIVE',
                    nextBillingDate: { $lte: now },
                },
            },
            {
                $lookup: {
                    from: 'subscriptions',
                    let: { subId: '$subscriptionId' },
                    pipeline: [
                        { $match: { $expr: { $eq: [{ $toString: '$_id' }, '$$subId'] } } },
                        { $match: { status: 'ACTIVE' } },
                    ],
                    as: 'subscription',
                },
            },
            { $match: { 'subscription.0': { $exists: true } } },
        ]);

        const results: MemberChargeResult[] = [];

        for (const memberDoc of dueMembers) {
            const subscription = memberDoc.subscription[0];
            const result = await this.processSingleMember(memberDoc, subscription, now);
            results.push(result);
        }

        // Send pre-billing warnings for upcoming charges
        await this.sendBillingWarnings(now);

        // Expire stale invitations
        await SubInvitation.updateMany(
            { status: 'PENDING', expiresAt: { $lte: now } },
            { status: 'EXPIRED' },
        );

        return {
            processedAt: now,
            totalMembersChecked: dueMembers.length,
            charged: results.filter((r) => r.success && !r.kicked).length,
            failed: results.filter((r) => !r.success && !r.kicked).length,
            kicked: results.filter((r) => r.kicked).length,
            results,
        };
    },

    async processSingleMember(memberDoc: any, subscription: any, now: Date): Promise<MemberChargeResult> {
        const memberId = memberDoc._id.toString();
        const userId = memberDoc.userId;
        const fee = Number(memberDoc.amount);
        const subscriptionId = memberDoc.subscriptionId;

        const result: MemberChargeResult = {
            memberId,
            userId,
            subscriptionId,
            subscriptionName: subscription.name,
            amount: fee,
            success: false,
            kicked: false,
        };

        // Idempotency guard: check if already billed this cycle
        const cycleStart = new Date(memberDoc.nextBillingDate);
        switch (subscription.billingCycle as BillingCycle) {
            case BillingCycle.DAILY: cycleStart.setDate(cycleStart.getDate() - 1); break;
            case BillingCycle.WEEKLY: cycleStart.setDate(cycleStart.getDate() - 7); break;
            case BillingCycle.MONTHLY: cycleStart.setMonth(cycleStart.getMonth() - 1); break;
            case BillingCycle.YEARLY: cycleStart.setFullYear(cycleStart.getFullYear() - 1); break;
        }
        if (memberDoc.lastChargedAt >= cycleStart) {
            // Already charged this cycle â€” just advance nextBillingDate
            const newNextDate = calculateNextBillingDate(
                new Date(memberDoc.nextBillingDate),
                subscription.billingCycle as BillingCycle,
            );
            await SubscriptionMember.findByIdAndUpdate(memberId, { nextBillingDate: newNextDate });
            result.success = true;
            return result;
        }

        const user = await User.findById(userId);
        if (user && user.balance >= fee) {
            // â”€â”€ SUCCESS PATH â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
            const session = await mongoose.startSession();
            try {
                session.startTransaction();
                await User.findByIdAndUpdate(userId, { $inc: { balance: -fee } }, { session });
                await User.findByIdAndUpdate(subscription.createdBy, { $inc: { balance: fee } }, { session });

                const nextBillingDate = calculateNextBillingDate(
                    new Date(memberDoc.nextBillingDate),
                    subscription.billingCycle as BillingCycle,
                );
                await SubscriptionMember.findByIdAndUpdate(memberId, {
                    nextBillingDate,
                    lastChargedAt: now,
                    retryCount: 0,
                }, { session });

                await session.commitTransaction();

                result.success = true;
            } catch (err: any) {
                await session.abortTransaction();
                result.reason = err.message;
            } finally {
                session.endSession();
            }

            if (result.success) {
                // Log transactions
                const memberAfter = await User.findById(userId);
                const ownerAfter = await User.findById(subscription.createdBy);
                await Promise.all([
                    transactionService.createTransaction({
                        userId,
                        groupId: subscription.groupId,
                        type: TransactionType.SUBSCRIPTION_FEE,
                        amount: fee,
                        balanceBefore: (memberAfter?.balance ?? 0) + fee,
                        balanceAfter: memberAfter?.balance ?? 0,
                        currency: subscription.currency ?? 'VND',
                        description: `Subscription renewal: ${subscription.name}`,
                        referenceId: subscriptionId,
                        referenceType: 'SUBSCRIPTION',
                    }),
                    transactionService.createTransaction({
                        userId: subscription.createdBy,
                        groupId: subscription.groupId,
                        type: TransactionType.TRANSFER_RECEIVED,
                        amount: fee,
                        balanceBefore: (ownerAfter?.balance ?? 0) - fee,
                        balanceAfter: ownerAfter?.balance ?? 0,
                        currency: subscription.currency ?? 'VND',
                        description: `Subscription renewal payment from member: ${subscription.name}`,
                        referenceId: subscriptionId,
                        referenceType: 'SUBSCRIPTION',
                    }),
                ]);

                // Billing history entry
                await BillingHistory.create({
                    subscriptionId,
                    groupId: subscription.groupId,
                    billingDate: now,
                    amount: fee,
                    currency: subscription.currency ?? 'VND',
                    status: 'SUCCESS',
                    membersCharged: 1,
                    membersFailed: 0,
                    totalCollected: fee,
                    memberResults: [{ userId, shareAmount: fee, success: true, categoryTagId: memberDoc.categoryTagId }],
                });

                try {
                    const nextBillingDateForNotif = calculateNextBillingDate(
                        new Date(memberDoc.nextBillingDate),
                        subscription.billingCycle as BillingCycle,
                    );
                    await notificationService.notify(
                        userId,
                        NotificationType.SUBSCRIPTION_BILLING_SUCCESS,
                        'Subscription Renewed',
                        `"${subscription.name}" renewed. ${fee.toLocaleString()} VND charged. Next: ${nextBillingDateForNotif.toDateString()}.`,
                        { subscriptionId },
                    );
                } catch (_) { /* */ }
            }

            await invalidateSubCache(subscriptionId);
            return result;
        }

        // â”€â”€ FAIL PATH â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        const newRetryCount = (memberDoc.retryCount ?? 0) + 1;
        result.reason = `Insufficient balance: ${user?.balance ?? 0} < ${fee}`;

        if (newRetryCount >= 3) {
            // Kick member
            await SubscriptionMember.findByIdAndUpdate(memberId, {
                status: 'LEFT',
                leftAt: now,
                retryCount: newRetryCount,
            });
            result.kicked = true;

            await BillingHistory.create({
                subscriptionId,
                groupId: subscription.groupId,
                billingDate: now,
                amount: fee,
                currency: subscription.currency ?? 'VND',
                status: 'FAILED',
                membersCharged: 0,
                membersFailed: 1,
                totalCollected: 0,
                failureReason: `Member ${userId} kicked after 3 failed attempts`,
                memberResults: [{ userId, shareAmount: fee, success: false, reason: result.reason, categoryTagId: memberDoc.categoryTagId }],
            });

            try {
                await Promise.all([
                    notificationService.notify(
                        userId,
                        NotificationType.SUBSCRIPTION_MEMBER_KICKED,
                        'Removed from Subscription',
                        `You have been removed from "${subscription.name}" after 3 failed payment attempts.`,
                        { subscriptionId },
                    ),
                    notificationService.notify(
                        subscription.createdBy,
                        NotificationType.SUBSCRIPTION_MEMBER_KICKED,
                        'Member Removed',
                        `A member was removed from "${subscription.name}" due to insufficient balance after 3 attempts.`,
                        { subscriptionId },
                    ),
                ]);
            } catch (_) { /* */ }
        } else {
            // Retry later
            await SubscriptionMember.findByIdAndUpdate(memberId, { retryCount: newRetryCount });

            const retriesLeft = 3 - newRetryCount;
            try {
                await notificationService.notify(
                    userId,
                    NotificationType.SUBSCRIPTION_BILLING_FAILED,
                    'Payment Failed',
                    `Could not renew "${subscription.name}". Need ${fee.toLocaleString()} VND. ${retriesLeft} attempt(s) remaining before removal.`,
                    { subscriptionId },
                );
            } catch (_) { /* */ }
        }

        await invalidateSubCache(subscriptionId);
        return result;
    },

    /**
     * Send pre-billing warning notifications to members whose billing date
     * falls within the warning window for their cycle.
     */
    async sendBillingWarnings(now: Date): Promise<void> {
        // We query members per cycle type to apply the correct warning window
        const cycles: BillingCycle[] = [BillingCycle.WEEKLY, BillingCycle.MONTHLY, BillingCycle.YEARLY];

        for (const cycle of cycles) {
            const windowMs = warningWindowMs(cycle);
            if (windowMs === 0) continue;

            const windowEnd = new Date(now.getTime() + windowMs);

            // Members whose nextBillingDate is in (now, windowEnd] and haven't been warned yet
            // We use a simple heuristic: query members in active subs with this billing cycle
            const members = await SubscriptionMember.aggregate([
                {
                    $match: {
                        status: 'ACTIVE',
                        nextBillingDate: { $gt: now, $lte: windowEnd },
                    },
                },
                {
                    $lookup: {
                        from: 'subscriptions',
                        let: { subId: '$subscriptionId' },
                        pipeline: [
                            { $match: { $expr: { $eq: [{ $toString: '$_id' }, '$$subId'] } } },
                            { $match: { status: 'ACTIVE', billingCycle: cycle } },
                        ],
                        as: 'subscription',
                    },
                },
                { $match: { 'subscription.0': { $exists: true } } },
            ]);

            for (const m of members) {
                const sub = m.subscription[0];
                try {
                    await notificationService.notify(
                        m.userId,
                        NotificationType.SUBSCRIPTION_BILLING_WARNING,
                        'Upcoming Subscription Charge',
                        `${Number(m.amount).toLocaleString()} VND will be charged for "${sub.name}" on ${new Date(m.nextBillingDate).toDateString()}. Ensure your wallet has sufficient balance.`,
                        { subscriptionId: m.subscriptionId },
                    );
                } catch (_) { /* */ }
            }
        }
    },

    // â”€â”€ LEGACY COMPAT (kept so controller compiles) â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

    /** @deprecated - use processRenewals */
    async processCharges(): Promise<ProcessChargesResponse> {
        return this.processRenewals();
    },
};

