import { Request, Response, NextFunction } from 'express';
import { authService } from '../service/authService';
import { JWTPayLoad } from '../type/auth';

declare global {
    namespace Express {
        interface Request {
            user?: JWTPayLoad;
        }
    }
}

export const authMiddleware = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
        const authHeader = req.headers.authorization;
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            res.status(401).json({ success: false, message: 'Missing or invalid token' });
            return;
        }
        const token = authHeader.substring(7);
        const decodedToken = authService.verifyToken(token);
        if (!decodedToken) {
            res.status(401).json({ success: false, message: 'Invalid token' });
            return;
        }
        req.user = decodedToken;
        next();
    } catch (error) {
        res.status(401).json({ success: false, message: 'Authencation failed' });
    }
}

export const authMiddlewareOptional = async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    try {
        const authHeader = req.headers.authorization;
        if (authHeader && authHeader.startsWith('Bearer ')) {
            const token = authHeader.substring(7);
            const decodedToken = authService.verifyToken(token);
            if (decodedToken) {
                req.user = decodedToken;
            }
        }
        next();
    } catch (error) {
        next();
    }
}