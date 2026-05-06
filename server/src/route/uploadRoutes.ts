import express from 'express';
import multer from 'multer';
import { uploadFile } from '../controller/uploadController';

const router = express.Router();

// Use memory storage — file stays in RAM buffer, uploaded directly to Cloudinary
const upload = multer({
    storage: multer.memoryStorage(),
    limits: {
        fileSize: 5 * 1024 * 1024 // 5MB limit
    },
    fileFilter: (req, file, cb) => {
        if (file.mimetype.startsWith('image/')) {
            cb(null, true);
        } else {
            cb(new Error('Only images are allowed'));
        }
    }
});

// Route
router.post('/', upload.single('file'), uploadFile);

export default router;
