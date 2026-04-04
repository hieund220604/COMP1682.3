import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/receipt.dart';
import '../providers/receipt_provider.dart';
import '../widgets/add_receipt_bottom_sheet.dart';
import 'receipt_detail_page.dart';

class DayReceiptsPage extends StatefulWidget {
  final String date; // YYYY-MM-DD
  final Set<String> selectedTagIds;

  const DayReceiptsPage({
    super.key,
    required this.date,
    required this.selectedTagIds,
  });

  @override
  State<DayReceiptsPage> createState() => _DayReceiptsPageState();
}

class _DayReceiptsPageState extends State<DayReceiptsPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReceiptProvider>().loadDay(widget.date, tagIds: widget.selectedTagIds.toList());
    });
  }

  void _openAddSheet() {
    final provider = context.read<ReceiptProvider>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: provider,
        child: AddReceiptBottomSheet(
          defaultDate: DateTime.parse(widget.date),
          onCreated: () {
            provider.loadDay(widget.date, tagIds: widget.selectedTagIds.toList());
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReceiptProvider>();
    final receipts = provider.dayReceipts;

    return Scaffold(
      appBar: AppBar(
        title: Text('Receipts on ${widget.date}'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddSheet,
        child: const Icon(Icons.add),
      ),
      body: provider.isLoadingDay
          ? const Center(child: CircularProgressIndicator())
          : receipts.isEmpty
              ? const Center(child: Text('No receipts yet'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (_, i) {
                    final r = receipts[i];
                    return _ReceiptCard(
                      receipt: r,
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReceiptDetailPage(receiptId: r.id, date: widget.date),
                          ),
                        );
                        provider.loadDay(widget.date, tagIds: widget.selectedTagIds.toList());
                      },
                      onDelete: () async {
                        final confirmed = await showDialog<bool>(
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
                        if (!confirmed) return;
                        await provider.deleteReceipt(r.id);
                      },
                    );
                  },
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemCount: receipts.length,
                ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final Receipt receipt;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ReceiptCard({
    required this.receipt,
    required this.onTap,
    required this.onDelete,
  });

  String _fixUrl(String url) {
    if (url.contains('localhost')) {
      return url.replaceAll('localhost', '10.0.2.2');
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                _fixUrl(receipt.imageUrl),
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, error, ___) => Container(
                  color: Colors.grey.shade200,
                  alignment: Alignment.center,
                  child: Text(
                    'Failed to load: ${_fixUrl(receipt.imageUrl)}\nError: $error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((receipt.note ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(receipt.note!, style: Theme.of(context).textTheme.bodyMedium),
                    ),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: receipt.tags
                        .map((t) => Chip(
                              label: Text(t.name),
                              backgroundColor: colorScheme.surfaceVariant,
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: onDelete,
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
