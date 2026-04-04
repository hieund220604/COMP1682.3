import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/receipt.dart';
import '../providers/receipt_provider.dart';
import 'tag_manager_page.dart';

class ReceiptDetailPage extends StatefulWidget {
  final String receiptId;
  final String date;

  const ReceiptDetailPage({
    super.key,
    required this.receiptId,
    required this.date,
  });

  static const routeName = '/receipts/detail';

  @override
  State<ReceiptDetailPage> createState() => _ReceiptDetailPageState();
}

class _ReceiptDetailPageState extends State<ReceiptDetailPage> {
  Receipt? _receipt;
  final TextEditingController _noteCtrl = TextEditingController();
  final Set<String> _selectedTagIds = {};

  String _fixUrl(String url) {
    if (url.contains('localhost')) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<ReceiptProvider>();
      await provider.loadDay(widget.date);
      Receipt? found;
      if (provider.dayReceipts.isNotEmpty) {
        try {
          found = provider.dayReceipts.firstWhere((r) => r.id == widget.receiptId);
        } catch (_) {
          found = provider.dayReceipts.first;
        }
      }
      if (found != null) {
        _receipt = found;
        _noteCtrl.text = found.note ?? '';
        _selectedTagIds.addAll(found.tags.map((t) => t.id));
        setState(() {});
      }
    });
  }

  Future<void> _save() async {
    if (_receipt == null) return;
    final provider = context.read<ReceiptProvider>();
    await provider.updateReceipt(
      id: _receipt!.id,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      tagIds: _selectedTagIds.toList(),
    );
    await provider.loadDay(widget.date);
    Navigator.of(context).pop();
  }

  void _openTagManager() async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TagManagerPage()));
    await context.read<ReceiptProvider>().loadTags();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    Receipt? receipt = _receipt;
    if (receipt == null && provider.dayReceipts.isNotEmpty) {
      try {
        receipt = provider.dayReceipts.firstWhere((r) => r.id == widget.receiptId);
      } catch (_) {
        receipt = provider.dayReceipts.first;
      }
    }

    if (receipt == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final Receipt currentReceipt = receipt;
    final tags = provider.tags;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt details'),
        actions: [
          IconButton(onPressed: _openTagManager, icon: const Icon(Icons.settings)),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                _fixUrl(receipt.imageUrl),
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteCtrl,
              maxLines: null,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Text('Tags (required)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (tags.isEmpty)
              Row(
                children: [
                  const Text('No tag yet.'),
                  TextButton(onPressed: _openTagManager, child: const Text('Create tag')),
                ],
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: tags
                    .map(
                      (t) => FilterChip(
                        label: Text(t.name),
                        selected: _selectedTagIds.contains(t.id),
                        onSelected: (_) {
                          setState(() {
                            if (_selectedTagIds.contains(t.id)) {
                              _selectedTagIds.remove(t.id);
                            } else {
                              _selectedTagIds.add(t.id);
                            }
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: provider.isSaving ? null : _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: provider.isSaving
                      ? null
                      : () async {
                          final ok = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Delete receipt?'),
                                  content: const Text('This receipt will be permanently removed.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                                  ],
                                ),
                              ) ??
                              false;
                          if (!ok) return;
                          await provider.deleteReceipt(currentReceipt.id);
                          if (mounted) Navigator.of(context).pop();
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}