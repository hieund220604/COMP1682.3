import { Request, Response } from 'express';
import { settlementService } from '../service/settlementService';
import { ResponseUtil } from '../util/responseUtil';
import {
    CreateSettlementRequest,
    SettlementResponse,
    SuggestedSettlement
} from '../type/settlement';
import { ApiResponse } from '../type/group';

export const settlementController = {
    /**
     * Create optimized settlements for a group
     * No body required - automatically calculates and creates all needed settlements
     */
    async createSettlement(
        req: Request<{ groupId: string }>,
        res: Response<ApiResponse<SettlementResponse[]>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId } = req.params;
            const settlements = await settlementService.createSettlement(req.user.userId, groupId);

            ResponseUtil.success(res, settlements, `Created ${settlements.length} optimized settlement(s)`, 201);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create settlements');
        }
    },

    async getSettlementsByGroup(
        req: Request<{ groupId: string }>,
        res: Response<ApiResponse<SettlementResponse[]>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId } = req.params;
            const settlements = await settlementService.getSettlementsByGroup(req.user.userId, groupId);
            ResponseUtil.success(res, settlements, 'Settlements retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get settlements');
        }
    },

    async getSuggestedSettlements(
        req: Request<{ groupId: string }>,
        res: Response<ApiResponse<SuggestedSettlement[]>>
    ): Promise<void> {
        try {
            if (!req.user) {
                return ResponseUtil.unauthorized(res);
            }

            const { groupId } = req.params;
            const suggestions = await settlementService.getSuggestedSettlements(req.user.userId, groupId);
            ResponseUtil.success(res, suggestions, 'Suggested settlements retrieved successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get suggested settlements');
        }
    }
};
