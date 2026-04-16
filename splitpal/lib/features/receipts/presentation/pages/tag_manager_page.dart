import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:splitpal/models/receipt.dart';
import 'package:splitpal/features/receipts/receipt_provider.dart';

class TagManagerPage extends StatefulWidget {
  const TagManagerPage({super.key});

  @override
  State<TagManagerPage> createState() => _TagManagerPageState();
}

class _TagManagerPageState extends State<TagManagerPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  String _selectedColor = _colors.first;

  static const List<String> _colors = [
    '#4F46E5', // indigo
    '#0EA5E9', // sky
    '#22C55E', // green
    '#F59E0B', // amber
    '#EF4444', // red
    '#EC4899', // pink
    '#10B981', // teal
    '#6366F1', // blue
  ];

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty) return;
    final provider = context.read<ReceiptProvider>();
    await provider.createTag(_nameCtrl.text.trim(), _selectedColor);
    _nameCtrl.clear();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceiptProvider>().loadTags();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final tags = provider.tags;

    return Scaffold(
      appBar: AppBar(title: const Text('Manage tags')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Tag name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _selectedColor,
                  items: _colors
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _colorFromHex(c),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.black12),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedColor = v ?? _selectedColor),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _create, child: const Text('Add')),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: tags.isEmpty
                  ? const Center(child: Text('No tags yet'))
                  : ListView.separated(
                      itemCount: tags.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (_, i) {
                        final t = tags[i];
                        return _TagRow(tag: t);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatefulWidget {
  final ReceiptTag tag;
  const _TagRow({required this.tag});

  @override
  State<_TagRow> createState() => _TagRowState();
}

class _TagRowState extends State<_TagRow> {
  bool _editing = false;
  late TextEditingController _ctrl;
  String _selectedColor = TagManagerPageStateColors.defaultColor;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.tag.name);
    _selectedColor = widget.tag.color;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ReceiptProvider>();
    return ListTile(
      title: _editing
          ? TextField(
              controller: _ctrl,
              decoration: const InputDecoration(border: UnderlineInputBorder()),
            )
          : Text(widget.tag.name),
      subtitle: const SizedBox.shrink(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_editing)
            DropdownButton<String>(
              value: _selectedColor,
              items: _TagPalette.colors
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedColor = v ?? _selectedColor),
            ),
          IconButton(
            icon: Icon(_editing ? Icons.check : Icons.edit),
            onPressed: () async {
              if (_editing) {
                await provider.updateTag(
                  widget.tag.id,
                  name: _ctrl.text.trim(),
                  color: _selectedColor,
                );
              }
              setState(() => _editing = !_editing);
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Delete tag?'),
                      content: const Text('Cannot delete if the tag is used by receipts.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                      ],
                    ),
                  ) ??
                  false;
              if (!ok) return;
              await provider.deleteTag(widget.tag.id);
            },
          ),
        ],
      ),
    );
  }
}

class _TagPalette {
  static const colors = [
    'blue',
    'green',
    'red',
    'orange',
    'purple',
    'pink',
    'teal',
    'gray',
  ];
}

Color _colorFromHex(String hex) {
  final buffer = StringBuffer();
  if (hex.length == 6 || hex.length == 7) buffer.write('ff');
  buffer.write(hex.replaceFirst('#', ''));
  return Color(int.parse(buffer.toString(), radix: 16));
}

class TagManagerPageStateColors {
  static const defaultColor = 'blue';
}
