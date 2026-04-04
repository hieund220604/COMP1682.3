import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/receipt.dart';
import '../providers/receipt_provider.dart';
import '../pages/tag_manager_page.dart';

class AddReceiptBottomSheet extends StatefulWidget {
  final DateTime defaultDate;
  final VoidCallback? onCreated;

  const AddReceiptBottomSheet({
    super.key,
    required this.defaultDate,
    this.onCreated,
  });

  @override
  State<AddReceiptBottomSheet> createState() => _AddReceiptBottomSheetState();
}

class _AddReceiptBottomSheetState extends State<AddReceiptBottomSheet> {
  final ImagePicker _picker = ImagePicker();
  File? _file;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _noteCtrl = TextEditingController();
  final Set<String> _selectedTagIds = {};
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.defaultDate;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceiptProvider>().loadTags();
    });
  }

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _file = File(picked.path));
    }
  }

  Future<void> _save() async {
    final provider = context.read<ReceiptProvider>();
    if (_file == null || _selectedTagIds.isEmpty) return;
    setState(() => _uploading = true);
    final result = await provider.createReceiptFromFile(
      file: _file!,
      receiptDate: _selectedDate,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      tagIds: _selectedTagIds.toList(),
    );
    setState(() => _uploading = false);
    if (result != null) {
      widget.onCreated?.call();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _openTagManager() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagManagerPage()));
    await context.read<ReceiptProvider>().loadTags();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final tags = provider.tags;
    final canSave = _file != null && _selectedTagIds.isNotEmpty && !_uploading;
    final colorScheme = Theme.of(context).colorScheme;

    if (_file == null) {
      return Container(
        height: 400,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            Icon(Icons.camera_alt, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            Text('Add Receipt', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Snap a photo of your receipt to upload it.', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600)),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera),
                label: const Text('Take Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('Choose from Gallery', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      );
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: Image.file(_file!, fit: BoxFit.cover),
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            height: 350,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black54, Colors.black87, Colors.black],
                ),
              ),
            ),
          ),
          Positioned(
            left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (provider.error != null)
                   Container(
                     padding: const EdgeInsets.all(8),
                     margin: const EdgeInsets.only(bottom: 8),
                     decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.8), borderRadius: BorderRadius.circular(8)),
                     child: Text(provider.error!, style: const TextStyle(color: Colors.white)),
                   ),
                if (tags.isEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(backgroundColor: Colors.black45),
                    onPressed: _openTagManager, 
                    icon: const Icon(Icons.add, color: Colors.amber),
                    label: const Text('Create required tag', style: TextStyle(color: Colors.amber))
                  )
                else 
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                         ...tags.map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              showCheckmark: false,
                              label: Text(t.name, style: TextStyle(color: _selectedTagIds.contains(t.id) ? Colors.black : Colors.white, fontWeight: FontWeight.bold)),
                              selected: _selectedTagIds.contains(t.id),
                              selectedColor: Colors.amber,
                              backgroundColor: Colors.black45,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                              onSelected: (_) {
                                 setState(() {
                                   if (_selectedTagIds.contains(t.id)) _selectedTagIds.remove(t.id);
                                   else _selectedTagIds.add(t.id);
                                 });
                              }
                            ),
                         )),
                         ActionChip(
                           label: const Icon(Icons.settings, size: 18, color: Colors.white),
                           backgroundColor: Colors.black45,
                           side: BorderSide.none,
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                           onPressed: _openTagManager,
                         )
                      ]
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                     Expanded(
                       child: Container(
                         decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(30)),
                         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                         child: TextField(
                           controller: _noteCtrl,
                           style: const TextStyle(color: Colors.white, fontSize: 16),
                           decoration: const InputDecoration(
                             hintText: 'Add a note...',
                             hintStyle: TextStyle(color: Colors.white70),
                             border: InputBorder.none,
                           )
                         ),
                       )
                     ),
                     const SizedBox(width: 12),
                     GestureDetector(
                       onTap: canSave ? _save : null,
                       child: CircleAvatar(
                         radius: 26,
                         backgroundColor: canSave ? Colors.amber : Colors.grey.shade800,
                         child: _uploading 
                             ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2)) 
                             : Icon(Icons.send, color: canSave ? Colors.black : Colors.white54, size: 24),
                       ),
                     )
                  ]
                )
              ]
            )
          ),
          Positioned(
            top: 24, left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => Navigator.of(context).pop()),
            )
          )
        ]
      )
    );
  }
}
