import { Request, Response } from 'express';
import { ResponseUtil } from '../util/responseUtil';
import { uploadToCloudinary } from '../util/cloudinaryStorage';

export const uploadFile = async (req: Request, res: Response) => {
    try {
        if (!req.file) {
            return ResponseUtil.validationError(res, 'No file uploaded');
        }

        // Upload to Cloudinary instead of local filesystem
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        const filename = `${req.file.fieldname}-${uniqueSuffix}`;

        const result = await uploadToCloudinary(
            req.file.buffer,
            filename,
            req.file.mimetype,
        );

        ResponseUtil.success(res, {
            url: result.url,
            filename: filename,
            mimetype: req.file.mimetype,
            size: req.file.size
        }, 'File uploaded successfully');
    } catch (error) {
        ResponseUtil.handleError(res, error, 'Upload failed');
    }
};
