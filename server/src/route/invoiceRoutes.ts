import { Router } from 'express';
import { invoiceController } from '../controller/invoiceController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router({ mergeParams: true }); // mergeParams to access :groupId from parent

// All routes require authentication
router.use(authMiddleware);

// User balance - MUST be before :invoiceId routes
router.get('/:groupId/my-balance', invoiceController.getMyBalance);

// Invoice CRUD
router.post('/:groupId', invoiceController.createInvoice);
router.get('/:groupId', invoiceController.getInvoices);
router.get('/:groupId/:invoiceId', invoiceController.getInvoiceById);
router.put('/:groupId/:invoiceId', invoiceController.updateInvoice);
router.delete('/:groupId/:invoiceId', invoiceController.deleteInvoice);

// Invoice actions
router.post('/:groupId/:invoiceId/submit', invoiceController.submitInvoice);
router.post('/:groupId/:invoiceId/adjust', invoiceController.createAdjustmentInvoice);

export default router;
