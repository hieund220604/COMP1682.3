const mongoose = require('mongoose');
const cloudinary = require('cloudinary').v2;
const fs = require('fs');
const path = require('path');

cloudinary.config({
  cloud_name: 'dr8uilk5f',
  api_key: '839974654276511',
  api_secret: 'tvm5MCvFjBJZkt6a_lJxX3NDmnY',
});

async function migrateOldReceipts() {
  await mongoose.connect(
    'mongodb+srv://nguyenduchieu20042206_db_user:vRhk7SMKmqSkdHc5@comp1682.chk4okz.mongodb.net/splitpal?retryWrites=true&w=majority',
    { tls: true, tlsAllowInvalidCertificates: true }
  );

  const receipts = await mongoose.connection.db
    .collection('receipts')
    .find({ imageUrl: { $regex: /^http:\/\/(localhost|10\.0\.2\.2)/ } })
    .toArray();

  console.log('Found', receipts.length, 'old receipts to migrate');

  for (const r of receipts) {
    const filename = r.imageUrl.split('/').pop();
    const localPath = path.join(process.cwd(), 'uploads', filename);

    if (!fs.existsSync(localPath)) {
      console.log('SKIP (file not found locally):', filename);
      continue;
    }

    try {
      const result = await cloudinary.uploader.upload(localPath, {
        folder: 'splitpal',
        public_id: filename.replace(/\.[^.]+$/, ''),
        resource_type: 'image',
      });

      await mongoose.connection.db
        .collection('receipts')
        .updateOne({ _id: r._id }, { $set: { imageUrl: result.secure_url } });

      console.log('MIGRATED:', filename, '->', result.secure_url);
    } catch (err) {
      console.error('ERROR migrating', filename, ':', err.message);
    }
  }

  console.log('Done!');
  process.exit(0);
}

migrateOldReceipts().catch((e) => {
  console.error(e);
  process.exit(1);
});
