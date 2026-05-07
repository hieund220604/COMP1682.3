import { Request, Response, Router } from 'express';
import { User } from '../models/User';
import { authMiddleware } from '../middleware/authMiddleware';
import { ResponseUtil } from '../util/responseUtil';

const router = Router();

router.use(authMiddleware);

router.get('/search', async (req: Request, res: Response) => {
    try {
        const { email } = req.query;
        if (!email || typeof email !== 'string' || email.trim().length < 3) {
            return ResponseUtil.success(res, [], 'Search query too short');
        }

        const query = email.trim().toLowerCase();
        
        // Find top 10 matching users (excluding self)
        const users = await User.find({
            email: { $regex: query, $options: 'i' },
            _id: { $ne: req.user?.userId }
        })
        .select('_id email displayName avatarUrl')
        .limit(10);

        const result = users.map(u => ({
            id: u._id.toString(),
            email: u.email,
            displayName: u.displayName,
            avatarUrl: u.avatarUrl
        }));

        ResponseUtil.success(res, result, 'Users found');
    } catch (error) {
        ResponseUtil.handleError(res, error, 'Failed to search users');
    }
});

export default router;
