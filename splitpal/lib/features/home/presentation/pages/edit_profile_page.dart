import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/core/app_services.dart';
import 'package:splitpal/core/icons/app_icons.dart';
import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/core/utils/upload_repository.dart';
import 'package:splitpal/core/widgets/app_card.dart';
import 'package:splitpal/features/auth/auth_provider.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late final TextEditingController _nameController;
  late final TextEditingController _avatarUrlController;
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.displayName ?? '');
    _avatarUrlController = TextEditingController(text: user?.avatarUrl ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _avatarUrlController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image == null) return;

      setState(() => _isUploading = true);

      // Use bytes universally — works on Web, Mobile, Desktop
      final bytes = await image.readAsBytes();
      final url = await AppServices.upload.uploadImageBytes(bytes, image.name);

      if (!mounted) return;
      setState(() {
        _avatarUrlController.text = url;
        _isUploading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final success = await context.read<AuthProvider>().updateProfile(
          displayName: _nameController.text.trim(),
          avatarUrl: _avatarUrlController.text.trim(),
        );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final avatarUrl = _avatarUrlController.text.trim();
    final hasAvatar = avatarUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SingleChildScrollView(
        padding: AppSpacing.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: InkWell(
                onTap: _isUploading ? null : _pickImage,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      height: 112,
                      width: 112,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scheme.surfaceContainerLowest,
                        border: Border.all(
                          color: scheme.outlineVariant.withAlpha(140),
                          width: 2,
                        ),
                        image: hasAvatar
                            ? DecorationImage(
                                image: NetworkImage(avatarUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: hasAvatar
                          ? null
                          : Icon(
                              AppIcons.person,
                              size: 56,
                              color: scheme.onSurfaceVariant,
                            ),
                    ),
                    if (_isUploading)
                      Container(
                        height: 112,
                        width: 112,
                        decoration: BoxDecoration(
                          color: scheme.surface.withAlpha(200),
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        height: 34,
                        width: 34,
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.surface, width: 2),
                        ),
                        child: Icon(
                          AppIcons.camera,
                          color: scheme.onPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Tap to upload a new profile photo',
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name',
                      prefixIcon: Icon(AppIcons.person),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _avatarUrlController,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Avatar URL',
                      hintText: 'Upload to generate URL',
                      prefixIcon: Icon(AppIcons.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isUploading ? null : _saveProfile,
                child: const Text('Save changes'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
