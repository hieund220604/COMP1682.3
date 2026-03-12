import { Request, Response } from 'express';
import { groupService } from '../service/groupService';
import { ledgerService } from '../service/ledgerService';
import { ResponseUtil } from '../util/responseUtil';
import {
    CreateGroupRequest,
    UpdateGroupRequest,
    InviteRequest,
    AcceptInviteRequest,
    UpdateMemberRoleRequest,
    ApiResponse,
    GroupResponse,
    GroupMemberResponse,
    InviteResponse,
    GroupBalanceResponse
} from '../type/group';

export const groupController = {
    // Create a new group
    async createGroup(req: Request<{}, {}, CreateGroupRequest>, res: Response<ApiResponse<GroupResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { name } = req.body;
            if (!name) {
                return ResponseUtil.validationError(res, 'Group name is required');
            }
            const group = await groupService.createGroup(req.user.userId, req.body);
            ResponseUtil.success(res, group, 'Group created successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create group');
        }
    },

    // Get group by ID
    async getGroupById(req: Request<{ groupId: string }>, res: Response<ApiResponse<GroupResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            const group = await groupService.getGroupById(req.user.userId, groupId);
            ResponseUtil.success(res, group, 'Group retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get group');
        }
    },

    // Get all groups for current user
    async getUserGroups(req: Request, res: Response<ApiResponse<GroupResponse[]>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const groups = await groupService.getGroupsForUser(req.user.userId);
            ResponseUtil.success(res, groups, 'Groups retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get groups');
        }
    },

    // Update group
    async updateGroup(req: Request<{ groupId: string }, {}, UpdateGroupRequest>, res: Response<ApiResponse<GroupResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            const group = await groupService.updateGroup(req.user.userId, groupId, req.body);
            ResponseUtil.success(res, group, 'Group updated successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update group');
        }
    },

    // Delete group
    async deleteGroup(req: Request<{ groupId: string }>, res: Response<ApiResponse<null>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            await groupService.deleteGroup(req.user.userId, groupId);
            ResponseUtil.success(res, null, 'Group deleted successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to delete group');
        }
    },

    // Create invite
    async createInvite(req: Request<{ groupId: string }, {}, InviteRequest>, res: Response<ApiResponse<InviteResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            const { emailInvite } = req.body;
            if (!emailInvite) {
                return ResponseUtil.validationError(res, 'Email is required');
            }
            const invite = await groupService.createInvite(req.user.userId, groupId, req.body);
            ResponseUtil.success(res, invite, 'Invite sent successfully', 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to send invite');
        }
    },

    // Accept invite
    async acceptInvite(req: Request<{}, {}, AcceptInviteRequest>, res: Response<ApiResponse<GroupMemberResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { token } = req.body;
            if (!token) {
                return ResponseUtil.validationError(res, 'Token is required');
            }
            const member = await groupService.acceptInvite(req.user.userId, token);
            ResponseUtil.success(res, member, 'Invite accepted successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to accept invite');
        }
    },

    // Get group members
    async getGroupMembers(req: Request<{ groupId: string }>, res: Response<ApiResponse<GroupMemberResponse[]>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            const members = await groupService.getGroupMembers(req.user.userId, groupId);
            ResponseUtil.success(res, members, 'Group members retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get group members');
        }
    },

    // Update member role
    async updateMemberRole(req: Request<{ groupId: string; memberId: string }, {}, UpdateMemberRoleRequest>, res: Response<ApiResponse<GroupMemberResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId, memberId } = req.params;
            const { role } = req.body;
            if (!role) {
                return ResponseUtil.validationError(res, 'Role is required');
            }
            const member = await groupService.updateMemberRole(req.user.userId, groupId, memberId, role);
            ResponseUtil.success(res, member, 'Member role updated successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update member role');
        }
    },

    // Grant admin privileges to a member
    async grantAdmin(req: Request<{ groupId: string; memberId: string }>, res: Response<ApiResponse<GroupMemberResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId, memberId } = req.params;
            const member = await groupService.grantAdmin(req.user.userId, groupId, memberId);
            ResponseUtil.success(res, member, 'Admin privileges granted successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to grant admin privileges');
        }
    },

    // Transfer ownership to another member
    async transferOwnership(req: Request<{ groupId: string }, {}, { newOwnerId: string }>, res: Response<ApiResponse<{
        oldOwner: GroupMemberResponse;
        newOwner: GroupMemberResponse;
    }>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            const { newOwnerId } = req.body;

            if (!newOwnerId) {
                return ResponseUtil.validationError(res, 'newOwnerId is required');
            }

            const result = await groupService.transferOwnership(req.user.userId, groupId, newOwnerId);
            ResponseUtil.success(res, result, 'Ownership transferred successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to transfer ownership');
        }
    },

    // Remove member from group
    async removeMember(req: Request<{ groupId: string; memberId: string }>, res: Response<ApiResponse<null>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId, memberId } = req.params;
            await groupService.removeMember(req.user.userId, groupId, memberId);
            ResponseUtil.success(res, null, 'Member removed successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to remove member');
        }
    },

    // Leave group
    async leaveGroup(req: Request<{ groupId: string }>, res: Response<ApiResponse<null>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            await groupService.leaveGroup(req.user.userId, groupId);
            ResponseUtil.success(res, null, 'You have left the group successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to leave group');
        }
    },

    // Get group balance
    async getGroupBalance(req: Request<{ groupId: string }>, res: Response<ApiResponse<GroupBalanceResponse>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;
            const balance = await groupService.calculateGroupBalance(req.user.userId, groupId);
            ResponseUtil.success(res, balance, 'Group balance retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to calculate group balance');
        }
    },

    // Get pending invites for current user
    async getPendingInvites(req: Request, res: Response<ApiResponse<InviteResponse[]>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const invites = await groupService.getPendingInvitesForUser(req.user.userId);
            ResponseUtil.success(res, invites, 'Pending invites retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get pending invites');
        }
    },

    // Get all member balances from ledger
    async getGroupBalances(req: Request<{ groupId: string }>, res: Response<ApiResponse<any>>): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }
            const { groupId } = req.params;

            // Get all member balances from ledger
            const balances = await ledgerService.getGroupBalances(groupId);

            ResponseUtil.success(res, balances, 'Group balances retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get group balances');
        }
    }
};
