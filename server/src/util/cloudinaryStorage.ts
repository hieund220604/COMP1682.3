import { v2 as cloudinary, UploadApiResponse } from 'cloudinary';

// Configure Cloudinary from env vars
cloudinary.config({
    cloud_name: process.env.CLOUDINARY_CLOUD_NAME,
    api_key: process.env.CLOUDINARY_API_KEY,
    api_secret: process.env.CLOUDINARY_API_SECRET,
});

/**
 * Upload a buffer to Cloudinary and return the public URL.
 */
export async function uploadToCloudinary(
    buffer: Buffer,
    filename: string,
    mimetype: string = 'image/jpeg'
): Promise<{ url: string; publicId: string }> {
    return new Promise((resolve, reject) => {
        const uploadStream = cloudinary.uploader.upload_stream(
            {
                folder: 'splitpal',
                public_id: filename.replace(/\.[^.]+$/, ''), // strip extension
                resource_type: 'image',
                overwrite: true,
            },
            (error, result?: UploadApiResponse) => {
                if (error) {
                    console.error('Cloudinary upload error:', error);
                    return reject(new Error(`Cloudinary upload failed: ${error.message}`));
                }
                if (!result) {
                    return reject(new Error('Cloudinary returned no result'));
                }
                resolve({
                    url: result.secure_url,
                    publicId: result.public_id,
                });
            }
        );
        uploadStream.end(buffer);
    });
}

/**
 * Delete a file from Cloudinary by its public ID.
 */
export async function deleteFromCloudinary(publicId: string): Promise<void> {
    try {
        await cloudinary.uploader.destroy(publicId);
    } catch (error) {
        console.error('Cloudinary delete error:', error);
    }
}
