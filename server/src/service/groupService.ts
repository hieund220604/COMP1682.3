import { Group } from '../models/Group';
import { GroupMember } from '../models/GroupMember';
import { Invite } from '../models/Invite';
import { User } from '../models/User';
import { OriginalDebt } from '../models/OriginalDebt';
import { originalDebtService } from './originalDebtService';
import { notificationService } from './notificationService';
import { NotificationType } from '../models/Notification';
import crypto from 'crypto';
import {
    CreateGroupRequest,
    UpdateGroupRequest,
    GroupResponse,
    GroupMemberResponse,
    InviteRequest,
    InviteResponse,
    GroupBalanceResponse,
    GroupRole
} from '../type/group';
import { buildRedisKey, deleteKeysByPrefix, getJsonCache, setJsonCache } from '../redis';

function transformUser(user: any) {
    if (!user) return undefined;
    return {
        id: user._id.toString(),
        email: user.email,
        displayName: user.displayName ?? undefined,
        avatarUrl: user.avatarUrl ?? undefined
    };
}

const GROUP_DETAIL_CACHE_TTL_SECONDS = 60;

function groupDetailCacheKey(userId: string, groupId: string): string {
    return buildRedisKey('cache', 'group', groupId, 'detail', userId);
}

async function invalidateGroupCache(groupId: string): Promise<void> {
    await deleteKeysByPrefix(buildRedisKey('cache', 'group', groupId));
}

export const groupService = {
    async createGroup(userId: string, data: CreateGroupRequest): Promise<GroupResponse> {
        const group = await Group.create({
            name: data.name,
            baseCurrency: data.baseCurrency || 'VND',
            createdBy: userId
        });

        const member = await GroupMember.create({
            groupId: group._id.toString(),
            userId: userId,
            role: 'OWNER'
        });

        const user = await User.findById(userId).select('_id email displayName avatarUrl');

        return {
            id: group._id.toString(),
            name: group.name,
            description: '',
            baseCurrency: group.baseCurrency,
            createdAt: group.createdAt,
            createdBy: group.createdBy,
            memberCount: 1,
            members: [{
                id: member._id.toString(),
                userId: member.userId,
                groupId: member.groupId,
                role: member.role as GroupRole,
                joinedAt: member.joinedAt,
                leftAt: member.leftAt ?? undefined,
                user: transformUser(user!)
            }]
        };
    },

    async getGroupById(userId: string, groupId: string): Promise<GroupResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('Group not found or access denied');
        }

        const cacheKey = groupDetailCacheKey(userId, groupId);
        const cached = await getJsonCache<GroupResponse>(cacheKey);
        if (cached) {
            return cached;
        }

        const group = await Group.findById(groupId);

        if (!group) {
            throw new Error('Group not found');
        }

        const members = await GroupMember.find({ groupId, leftAt: null });
        const users = await User.find({
            _id: { $in: members.map(m => m.userId) }
        }).select('_id email displayName avatarUrl');

        const userMap = new Map();
        users.forEach(u => userMap.set(u._id.toString(), u));

        const response: GroupResponse = {
            id: group._id.toString(),
            name: group.name,
            description: '',
            baseCurrency: group.baseCurrency,
            createdAt: group.createdAt,
            createdBy: group.createdBy,
            memberCount: members.length,
            members: members
                .filter(m => userMap.has(m.userId))
                .map(m => ({
                    id: m._id.toString(),
                    userId: m.userId,
                    groupId: m.groupId,
                    role: m.role as GroupRole,
                    joinedAt: m.joinedAt,
                    leftAt: m.leftAt ?? undefined,
                    user: transformUser(userMap.get(m.userId))
                }))
        };

        await setJsonCache(cacheKey, response, GROUP_DETAIL_CACHE_TTL_SECONDS);
        return response;
    },

    async getGroupsForUser(userId: string): Promise<GroupResponse[]> {
        const memberships = await GroupMember.find({ userId, leftAt: null });
        const groupIds = memberships.map(m => m.groupId);

        const groups = await Group.find({ _id: { $in: groupIds } });

        const groupResponses = await Promise.all(
            groups.map(async (group) => {
                const memberCount = await GroupMember.countDocuments({ groupId: group._id.toString(), leftAt: null });

                return {
                    id: group._id.toString(),
                    name: group.name,
                    description: '',
                    baseCurrency: group.baseCurrency,
                    createdAt: group.createdAt,
                    createdBy: group.createdBy,
                    memberCount
                };
            })
        );

        return groupResponses;
    },

    async updateGroup(userId: string, groupId: string, data: UpdateGroupRequest): Promise<GroupResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Permission denied. Only OWNER or ADMIN can update group.');
        }

        await Group.findByIdAndUpdate(groupId, {
            name: data.name,
            baseCurrency: data.baseCurrency
        });

        await invalidateGroupCache(groupId);

        return this.getGroupById(userId, groupId);
    },

    async grantAdmin(userId: string, groupId: string, targetMemberId: string): Promise<GroupMemberResponse> {
        // 1. Verify requester is OWNER
        const requester = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!requester || requester.role !== 'OWNER') {
            throw new Error('Only OWNER can grant admin privileges');
        }

        // 2. Verify target member exists and is active
        const targetMember = await GroupMember.findById(targetMemberId);

        if (!targetMember || targetMember.groupId !== groupId || targetMember.leftAt !== null) {
            throw new Error('Member not found in this group');
        }

        if (targetMember.role === 'OWNER') {
            throw new Error('Cannot grant admin to owner');
        }

        if (targetMember.role === 'ADMIN') {
            throw new Error('Member is already an admin');
        }

        // 3. Update role to ADMIN
        await GroupMember.findByIdAndUpdate(targetMemberId, { role: 'ADMIN' });
        await invalidateGroupCache(groupId);

        // 4. Return updated member
        const user = await User.findById(targetMember.userId).select('_id email displayName avatarUrl');

        return {
            id: targetMember._id.toString(),
            userId: targetMember.userId,
            groupId: targetMember.groupId,
            role: 'ADMIN' as GroupRole,
            joinedAt: targetMember.joinedAt,
            leftAt: targetMember.leftAt ?? undefined,
            user: transformUser(user!)
        };
    },

    async transferOwnership(userId: string, groupId: string, newOwnerId: string): Promise<{
        oldOwner: GroupMemberResponse;
        newOwner: GroupMemberResponse;
    }> {
        // 1. Verify requester is current OWNER
        const currentOwner = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!currentOwner || currentOwner.role !== 'OWNER') {
            throw new Error('Only OWNER can transfer ownership');
        }

        // 2. Verify new owner is an active member
        const newOwnerMember = await GroupMember.findOne({
            groupId,
            userId: newOwnerId,
            leftAt: null
        });

        if (!newOwnerMember) {
            throw new Error('New owner must be an active member of the group');
        }

        if (newOwnerMember.userId === userId) {
            throw new Error('You are already the owner');
        }

        // 3. Atomic update: Swap roles (old owner becomes ADMIN)
        await GroupMember.findByIdAndUpdate(currentOwner._id, { role: 'ADMIN' });
        await GroupMember.findByIdAndUpdate(newOwnerMember._id, { role: 'OWNER' });

        // 4. Update Group.createdBy
        await Group.findByIdAndUpdate(groupId, { createdBy: newOwnerId });
        await invalidateGroupCache(groupId);

        // 5. Return both members
        const [oldUser, newUser] = await Promise.all([
            User.findById(userId).select('_id email displayName avatarUrl'),
            User.findById(newOwnerId).select('_id email displayName avatarUrl')
        ]);

        return {
            oldOwner: {
                id: currentOwner._id.toString(),
                userId: currentOwner.userId,
                groupId,
                role: 'MEMBER' as GroupRole,
                joinedAt: currentOwner.joinedAt,
                leftAt: currentOwner.leftAt ?? undefined,
                user: transformUser(oldUser!)
            },
            newOwner: {
                id: newOwnerMember._id.toString(),
                userId: newOwnerMember.userId,
                groupId,
                role: 'OWNER' as GroupRole,
                joinedAt: newOwnerMember.joinedAt,
                leftAt: newOwnerMember.leftAt ?? undefined,
                user: transformUser(newUser!)
            }
        };
    },

    async deleteGroup(userId: string, groupId: string): Promise<void> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership || membership.role !== 'OWNER') {
            throw new Error('Permission denied. Only OWNER can delete group.');
        }

        // Import models needed for cascade
        const { Subscription } = await import('../models/Subscription');
        const { Invoice } = await import('../models/Invoice');

        // 1. Cancel all active subscriptions
        await Subscription.updateMany(
            { groupId, status: { $in: ['ACTIVE', 'PAST_DUE'] } },
            {
                status: 'CANCELLED',
                cancelledAt: new Date(),
                failureReason: 'Group deleted by owner',
                groupDeleted: true
            }
        );

        // 2. Mark invoices as archived (NOT delete)
        await Invoice.updateMany(
            { groupId },
            { groupDeleted: true }
        );

        // 3. Soft delete group
        await Group.findByIdAndUpdate(groupId, { deletedAt: new Date() });

        // 4. Mark all members as left
        await GroupMember.updateMany(
            { groupId, leftAt: null },
            { leftAt: new Date() }
        );

        await invalidateGroupCache(groupId);
    },

    async createInvite(userId: string, groupId: string, data: InviteRequest): Promise<InviteResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Permission denied. Only OWNER or ADMIN can create invites.');
        }

        const existingMember = await GroupMember.findOne({
            groupId,
            leftAt: null
        }).populate({ path: 'userId', select: 'email', model: 'User' });

        const existingInvite = await Invite.findOne({
            groupId,
            emailInvite: data.emailInvite,
            status: 'PENDING'
        });

        if (existingInvite) {
            throw new Error('An active invite already exists for this email.');
        }

        const token = crypto.randomBytes(32).toString('hex');
        const expiredAt = new Date();
        expiredAt.setDate(expiredAt.getDate() + 7);

        const invite = await Invite.create({
            groupId,
            emailInvite: data.emailInvite,
            role: data.role || 'USER',
            token,
            status: 'PENDING',
            expiredAt,
            invitedBy: userId
        });

        // Find the invited user and send notification if they exist
        const invitedUser = await User.findOne({ email: data.emailInvite });
        if (invitedUser) {
            const group = await Group.findById(groupId);
            const inviter = await User.findById(userId);

            await notificationService.createNotification({
                userId: invitedUser._id.toString(),
                type: NotificationType.INVITE_RECEIVED,
                title: 'Group Invitation',
                message: `${inviter?.displayName || 'Someone'} invited you to join ${group?.name || 'a group'}`,
                data: {
                    groupId,
                    inviteToken: token,
                    groupName: group?.name
                }
            });
        }

        return {
            id: invite._id.toString(),
            emailInvite: invite.emailInvite,
            role: invite.role as GroupRole,
            status: invite.status as 'PENDING' | 'ACCEPTED' | 'EXPIRED',
            expiresAt: invite.expiredAt,
            createdAt: invite.createdAt,
            token: invite.token
        };
    },

    async acceptInvite(userId: string, token: string): Promise<GroupMemberResponse> {
        const invite = await Invite.findOne({ token });

        if (!invite) {
            throw new Error('Invalid invite token.');
        }

        if (invite.status !== 'PENDING') {
            throw new Error('This invite has already been used or expired.');
        }

        if (new Date() > invite.expiredAt) {
            await Invite.findByIdAndUpdate(invite._id, { status: 'EXPIRED' });
            throw new Error('This invite has expired.');
        }

        const user = await User.findById(userId);

        if (!user || user.email !== invite.emailInvite) {
            throw new Error('This invite is not for your email address.');
        }

        const existingMember = await GroupMember.findOne({ groupId: invite.groupId, userId, leftAt: null });

        if (existingMember) {
            throw new Error('You are already a member of this group.');
        }

        const member = await GroupMember.create({
            groupId: invite.groupId,
            userId,
            role: invite.role
        });

        await Invite.findByIdAndUpdate(invite._id, { status: 'ACCEPTED' });
        await invalidateGroupCache(invite.groupId);

        // Notify all group members about the new member (except the new member themselves)
        const group = await Group.findById(invite.groupId);
        const allMembers = await GroupMember.find({ groupId: invite.groupId, leftAt: null });

        for (const memberDoc of allMembers) {
            if (memberDoc.userId !== userId) {
                await notificationService.createNotification({
                    userId: memberDoc.userId,
                    type: NotificationType.GROUP_JOINED,
                    title: 'New Member Joined',
                    message: `${user.displayName || user.email} joined ${group?.name || 'the group'}`,
                    data: {
                        groupId: invite.groupId,
                        newMemberId: userId,
                        groupName: group?.name
                    }
                });
            }
        }

        return {
            id: member._id.toString(),
            userId: member.userId,
            groupId: member.groupId,
            role: member.role as GroupRole,
            joinedAt: member.joinedAt,
            leftAt: member.leftAt ?? undefined,
            user: transformUser(user)
        };
    },

    async getGroupMembers(userId: string, groupId: string): Promise<GroupMemberResponse[]> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('Group not found or access denied');
        }

        const members = await GroupMember.find({ groupId, leftAt: null }).sort({ joinedAt: 1 });
        const users = await User.find({
            _id: { $in: members.map(m => m.userId) }
        }).select('_id email displayName avatarUrl');

        const userMap = new Map();
        users.forEach(u => userMap.set(u._id.toString(), u));

        return members
            .filter(m => userMap.has(m.userId))
            .map(m => ({
                id: m._id.toString(),
                userId: m.userId,
                groupId: m.groupId,
                role: m.role as GroupRole,
                joinedAt: m.joinedAt,
                leftAt: m.leftAt ?? undefined,
                user: transformUser(userMap.get(m.userId))
            }));
    },

    async updateMemberRole(userId: string, groupId: string, memberId: string, newRole: GroupRole): Promise<GroupMemberResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Permission denied. Only OWNER or ADMIN can update member roles.');
        }

        const targetMember = await GroupMember.findById(memberId);

        if (!targetMember || targetMember.groupId !== groupId || targetMember.leftAt !== null) {
            throw new Error('Member not found in this group.');
        }

        if (targetMember.role === 'OWNER') {
            throw new Error('Cannot change the role of the group owner.');
        }

        if (newRole === 'OWNER') {
            throw new Error('Cannot assign OWNER role. Use transfer ownership instead.');
        }

        // ADMIN can only update USER role, not ADMIN or OWNER
        if (membership.role === 'ADMIN' && targetMember.role !== 'USER') {
            throw new Error('Admin can only update USER roles.');
        }

        // ADMIN cannot grant ADMIN role
        if (membership.role === 'ADMIN' && newRole === 'ADMIN') {
            throw new Error('Admin cannot grant ADMIN role.');
        }

        await GroupMember.findByIdAndUpdate(memberId, { role: newRole });
        await invalidateGroupCache(groupId);

        const user = await User.findById(targetMember.userId).select('_id email displayName avatarUrl');

        return {
            id: targetMember._id.toString(),
            userId: targetMember.userId,
            groupId: targetMember.groupId,
            role: newRole,
            joinedAt: targetMember.joinedAt,
            leftAt: targetMember.leftAt ?? undefined,
            user: transformUser(user!)
        };
    },

    async removeMember(userId: string, groupId: string, memberId: string): Promise<void> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership || (membership.role !== 'OWNER' && membership.role !== 'ADMIN')) {
            throw new Error('Permission denied. Only OWNER or ADMIN can remove members.');
        }

        const targetMember = await GroupMember.findById(memberId);

        if (!targetMember || targetMember.groupId !== groupId || targetMember.leftAt !== null) {
            throw new Error('Member not found in this group.');
        }

        if (targetMember.role === 'OWNER') {
            throw new Error('Cannot remove the group owner.');
        }

        await GroupMember.findByIdAndUpdate(memberId, { leftAt: new Date() });

        // BUG FIX: Also mark member as LEFT in all subscriptions within this group
        const { SubscriptionMember } = await import('../models/SubscriptionMember');
        const { Subscription } = await import('../models/Subscription');
        const groupSubscriptions = await Subscription.find({ groupId }).select('_id');
        const subscriptionIds = groupSubscriptions.map(s => s._id.toString());
        if (subscriptionIds.length > 0) {
            await SubscriptionMember.updateMany(
                { userId: targetMember.userId, subscriptionId: { $in: subscriptionIds }, status: 'ACTIVE' },
                { status: 'LEFT', leftAt: new Date() }
            );
        }

        await invalidateGroupCache(groupId);
    },

    async leaveGroup(userId: string, groupId: string): Promise<void> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('You are not a member of this group.');
        }

        if (membership.role === 'OWNER') {
            throw new Error('Owner cannot leave the group. Transfer ownership first or delete the group.');
        }

        // Check net balance before leaving (UpBill requirement)
        const { originalDebtService } = await import('./originalDebtService');
        const balanceCheck = await originalDebtService.canUserLeaveGroup(groupId, userId);

        if (!balanceCheck.canLeave) {
            throw new Error(balanceCheck.reason || 'Cannot leave group with outstanding balance');
        }

        // BUG FIX: Update SubscriptionMember only for subscriptions in THIS group
        const { SubscriptionMember } = await import('../models/SubscriptionMember');
        const { Subscription } = await import('../models/Subscription');
        const groupSubscriptions = await Subscription.find({ groupId }).select('_id');
        const subscriptionIds = groupSubscriptions.map(s => s._id.toString());
        if (subscriptionIds.length > 0) {
            await SubscriptionMember.updateMany(
                { userId, subscriptionId: { $in: subscriptionIds }, status: 'ACTIVE' },
                { status: 'LEFT', leftAt: new Date() }
            );
        }

        await GroupMember.findByIdAndUpdate(membership._id, { leftAt: new Date() });
        await invalidateGroupCache(groupId);
    },

    async calculateGroupBalance(userId: string, groupId: string): Promise<GroupBalanceResponse> {
        const membership = await GroupMember.findOne({ groupId, userId, leftAt: null });

        if (!membership) {
            throw new Error('Group not found or access denied');
        }

        const members = await GroupMember.find({ groupId, leftAt: null });
        const users = await User.find({
            _id: { $in: members.map(m => m.userId) }
        }).select('_id displayName');

        // Get all unresolved debts in this group from the active debt engine.
        const allDebts = await OriginalDebt.find({
            groupId,
            remainingAmount: { $gt: 0.01 }
        });
        const debts = await originalDebtService.filterCancelledTransferDebts(allDebts);

        const balances = members.map(member => {
            const memberId = member.userId;

            let totalLent = 0;
            let totalOwed = 0;
            for (const debt of debts) {
                if (debt.creditorId === memberId) {
                    totalLent += debt.remainingAmount;
                } else if (debt.debtorId === memberId) {
                    totalOwed += debt.remainingAmount;
                }
            }

            const netBalance = totalLent - totalOwed;

            const user = users.find(u => u._id.toString() === memberId);

            return {
                userId: memberId,
                displayName: user?.displayName ?? undefined,
                totalOwed: Math.round(totalOwed * 100) / 100,
                totalLent: Math.round(totalLent * 100) / 100,
                netBalance: Math.round(netBalance * 100) / 100
            };
        });

        return {
            groupId,
            members: balances
        };
    },

    async getPendingInvitesForUser(userId: string): Promise<InviteResponse[]> {
        const user = await User.findById(userId).select('email');

        if (!user) {
            throw new Error('User not found');
        }

        const invites = await Invite.find({
            emailInvite: user.email,
            status: 'PENDING',
            expiredAt: { $gt: new Date() }
        }).sort({ createdAt: -1 });

        const groupIds = invites.map(i => i.groupId);
        const groups = await Group.find({ _id: { $in: groupIds } }).select('_id name');

        // Get inviter info
        const inviterIds = invites.map(i => i.invitedBy).filter(Boolean);
        const inviters = await User.find({ _id: { $in: inviterIds } }).select('_id displayName');

        const groupMap = new Map();
        groups.forEach(g => groupMap.set(g._id.toString(), g));

        const inviterMap = new Map();
        inviters.forEach(u => inviterMap.set(u._id.toString(), u.displayName));

        return invites.map(invite => ({
            id: invite._id.toString(),
            emailInvite: invite.emailInvite,
            role: invite.role as GroupRole,
            status: invite.status as 'PENDING' | 'ACCEPTED' | 'EXPIRED',
            expiresAt: invite.expiredAt,
            createdAt: invite.createdAt,
            token: invite.token,
            groupName: groupMap.get(invite.groupId)?.name,
            groupId: invite.groupId,
            invitedByName: invite.invitedBy ? inviterMap.get(invite.invitedBy) : 'Someone'
        }));
    }
};