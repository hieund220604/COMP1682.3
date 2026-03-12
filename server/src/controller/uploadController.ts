import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';

export const uploadFile = (req: Request, res: Response) => {
    try {
        if (!req.file) {
            return ResponseUtil.validationError(res, 'No file uploaded');
        }

        // Construct the URL to access the file
        // Assumes the server is serving the 'uploads' directory statically
        const fileUrl = `${req.protocol}://${req.get('host')}/uploads/${req.file.filename}`;

        ResponseUtil.success(res, {
            url: fileUrl,
            filename: req.file.filename,
            mimetype: req.file.mimetype,
            size: req.file.size
        }, 'File uploaded successfully');
    } catch (error) {
        ResponseUtil.handleError(res, error, 'Upload failed');
    }
};
