import { Router } from 'express';
import { billTemplateController } from '../controller/billTemplateController';
import { authMiddleware } from '../middleware/authMiddleware';

const router = Router({ mergeParams: true }); // access :groupId from parent

router.use(authMiddleware);

// ── Template CRUD ──────────────────────────────────────────────────────────
router.post('/', billTemplateController.createTemplate);
router.get('/', billTemplateController.getTemplates);
router.get('/:templateId', billTemplateController.getTemplateById);
router.put('/:templateId', billTemplateController.updateTemplate);
router.delete('/:templateId', billTemplateController.archiveTemplate);

// ── Template actions ───────────────────────────────────────────────────────
router.patch('/:templateId/pause', billTemplateController.pauseTemplate);
router.patch('/:templateId/resume', billTemplateController.resumeTemplate);
router.post('/:templateId/generate-now', billTemplateController.generateNow);

export default router;
