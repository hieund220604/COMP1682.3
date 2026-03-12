import { Response } from 'express';

/**
 * Standard API Response Interface
 */
export interface ApiResponse<T = any> {
    success: boolean;
    data?: T;
    message?: string;
    error?: {
        message: string;
        code?: string;
        details?: any;
    };
}

/**
 * Utility class for standardized API responses
 */
export class ResponseUtil {
    /**
     * Send success response
     */
    static success<T>(
        res: Response,
        data?: T,
        message?: string,
        statusCode: number = 200
    ): void {
        const response: ApiResponse<T> = {
            success: true,
            data,
            message
        };
        res.status(statusCode).json(response);
    }

    /**
     * Send error response
     */
    static error(
        res: Response,
        message: string,
        statusCode: number = 400,
        code?: string,
        details?: any
    ): void {
        const response: ApiResponse = {
            success: false,
            error: {
                message,
                code,
                details
            }
        };
        res.status(statusCode).json(response);
    }

    /**
     * Send validation error response
     */
    static validationError(
        res: Response,
        message: string = 'Validation failed',
        details?: any
    ): void {
        this.error(res, message, 400, 'VALIDATION_ERROR', details);
    }

    /**
     * Send unauthorized response
     */
    static unauthorized(
        res: Response,
        message: string = 'Unauthorized'
    ): void {
        this.error(res, message, 401, 'UNAUTHORIZED');
    }

    /**
     * Send forbidden response
     */
    static forbidden(
        res: Response,
        message: string = 'Forbidden'
    ): void {
        this.error(res, message, 403, 'FORBIDDEN');
    }

    /**
     * Send not found response
     */
    static notFound(
        res: Response,
        message: string = 'Resource not found'
    ): void {
        this.error(res, message, 404, 'NOT_FOUND');
    }

    /**
     * Send server error response
     */
    static serverError(
        res: Response,
        error: Error | string,
        code: string = 'SERVER_ERROR'
    ): void {
        const message = error instanceof Error ? error.message : error;
        console.error('Server Error:', message);
        this.error(res, 'Internal server error', 500, code);
    }

    /**
     * Handle controller errors automatically
     */
    static handleError(
        res: Response,
        error: any,
        defaultMessage: string = 'Operation failed'
    ): void {
        console.error('Controller Error:', error);

        if (error.message) {
            // Check for 2FA required
            if (error.code === '2FA_REQUIRED' || error.message === '2FA_REQUIRED') {
                this.error(res, 'Two-factor authentication required', 403, '2FA_REQUIRED');
            }
            // Check for specific error types
            else if (error.message.includes('not found')) {
                this.notFound(res, error.message);
            } else if (error.message.includes('unauthorized') || error.message.includes('Unauthorized')) {
                this.unauthorized(res, error.message);
            } else if (error.message.includes('forbidden') || error.message.includes('access denied')) {
                this.forbidden(res, error.message);
            } else if (error.message.includes('validation') || error.message.includes('invalid')) {
                this.validationError(res, error.message);
            } else {
                this.error(res, error.message, 400, 'OPERATION_FAILED');
            }
        } else {
            this.error(res, defaultMessage, 400, 'OPERATION_FAILED');
        }
    }

    /**
     * Send created response (201)
     */
    static created<T>(
        res: Response,
        data: T,
        message: string = 'Resource created successfully'
    ): void {
        this.success(res, data, message, 201);
    }

    /**
     * Send no content response (204)
     */
    static noContent(res: Response): void {
        res.status(204).send();
    }

    /**
     * Send accepted response (202)
     */
    static accepted<T>(
        res: Response,
        data?: T,
        message: string = 'Request accepted for processing'
    ): void {
        this.success(res, data, message, 202);
    }
}
