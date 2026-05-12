import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';
import { savingsService } from '../service/savingsService';

export const savingsController = {

    // ── Goals ─────────────────────────────────────────────────────────────────

    /**
     * POST /api/savings/goals
     * Create a new savings goal.
     */
    async createGoal(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const { name, targetAmount, icon, deadline } = req.body;
            const goal = await savingsService.createGoal(userId, {
                name, targetAmount, icon, deadline,
            });
            ResponseUtil.created(res, goal, 'Savings goal created');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create savings goal');
        }
    },

    /**
     * GET /api/savings/goals
     * List all savings goals with deposits and summary.
     */
    async getGoals(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const data = await savingsService.getGoals(userId);
            ResponseUtil.success(res, data);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to fetch savings goals');
        }
    },

    /**
     * GET /api/savings/goals/:id
     * Get a single goal with its deposits.
     */
    async getGoalById(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const goal = await savingsService.getGoalById(req.params.id, userId);
            ResponseUtil.success(res, goal);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to fetch savings goal');
        }
    },

    /**
     * PUT /api/savings/goals/:id
     * Update a savings goal (name, target, icon, deadline).
     */
    async updateGoal(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const { name, targetAmount, icon, deadline } = req.body;
            const goal = await savingsService.updateGoal(req.params.id, userId, {
                name, targetAmount, icon, deadline,
            });
            ResponseUtil.success(res, goal, 'Savings goal updated');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to update savings goal');
        }
    },

    /**
     * DELETE /api/savings/goals/:id
     * Cancel a savings goal (must withdraw all deposits first).
     */
    async cancelGoal(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const goal = await savingsService.cancelGoal(req.params.id, userId);
            ResponseUtil.success(res, goal, 'Savings goal cancelled');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to cancel savings goal');
        }
    },

    // ── Deposits ──────────────────────────────────────────────────────────────

    /**
     * POST /api/savings/goals/:id/deposits
     * Create a deposit into a savings goal.
     */
    async createDeposit(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const { amount, term } = req.body;
            const deposit = await savingsService.createDeposit(
                req.params.id,
                userId,
                { amount: Number(amount), term: Number(term) },
            );
            ResponseUtil.created(res, deposit, 'Deposit created successfully');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to create deposit');
        }
    },

    /**
     * POST /api/savings/deposits/:id/withdraw
     * Withdraw a deposit (with interest).
     */
    async withdrawDeposit(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const result = await savingsService.withdrawDeposit(req.params.id, userId);
            ResponseUtil.success(res, result, 'Withdrawal completed');
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to withdraw deposit');
        }
    },

    // ── Utilities ─────────────────────────────────────────────────────────────

    /**
     * GET /api/savings/interest-preview?amount=X&term=Y
     * Preview interest rate and estimated return.
     */
    async getInterestPreview(req: Request, res: Response): Promise<void> {
        try {
            const amount = Number(req.query.amount);
            const term = Number(req.query.term);

            if (!amount || amount <= 0) {
                return ResponseUtil.validationError(res, 'Amount must be a positive number');
            }

            const preview = savingsService.getInterestPreview(amount, term);
            ResponseUtil.success(res, preview);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get interest preview');
        }
    },

    /**
     * GET /api/savings/goals/:id/projection
     * Get goal completion projection.
     */
    async getGoalProjection(req: Request, res: Response): Promise<void> {
        try {
            const userId = req.user?.userId;
            if (!userId) return ResponseUtil.unauthorized(res);

            const projection = await savingsService.getGoalProjection(req.params.id, userId);
            ResponseUtil.success(res, projection);
        } catch (error) {
            ResponseUtil.handleError(res, error, 'Failed to get goal projection');
        }
    },
};
