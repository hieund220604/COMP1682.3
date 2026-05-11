import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

import 'package:splitpal/core/theme/app_tokens.dart';
import 'package:splitpal/features/groups/group_provider.dart';
import 'join_by_code/scanner_view.dart';

class JoinGroupPage extends StatefulWidget {
  final String? initialCode;
  
  const JoinGroupPage({Key? key, this.initialCode}) : super(key: key);

  @override
  State<JoinGroupPage> createState() => _JoinGroupPageState();
}

class _JoinGroupPageState extends State<JoinGroupPage> {
  final _pinController = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialCode != null) {
      _pinController.text = widget.initialCode!;
      // Auto submit if 6 chars length
      if (widget.initialCode!.length == 6) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _submitCode(widget.initialCode!);
        });
      }
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submitCode(String code) async {
    if (code.length != 6) return;
    if (_isLoading) return; // Prevent double submission when both Pinput and manual trigger fire

    setState(() => _isLoading = true);

    // Show loading dialog with barrier
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Padding(
            padding: EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 24),
                Text(
                  'Joining group...',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        );
      },
    );

    try {
      final provider = context.read<GroupProvider>();
      await provider.joinGroupByCode(code);
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully joined group')),
        );
        Navigator.pop(context, true); // Return true to refresh list
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
        _pinController.clear();
        _focusNode.requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openScanner() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerView()),
    );
    if (result != null && result.isNotEmpty) {
      _pinController.text = result;
      if (result.length == 6) {
        _submitCode(result);
      }
    }
  }

  void _pasteFromClipboard() async {
    final clipboardData = await Clipboard.getData('text/plain');
    if (clipboardData != null && clipboardData.text != null) {
      String text = clipboardData.text!;
      // Try to extract code from URL
      if (text.contains('join?code=')) {
        final uri = Uri.tryParse(text);
        if (uri != null && uri.queryParameters.containsKey('code')) {
          text = uri.queryParameters['code']!;
        }
      }
      
      // Clean up whitespace and get first 6 chars
      text = text.trim().replaceAll(' ', '').toUpperCase();
      if (text.length >= 6) {
        text = text.substring(0, 6);
      }
      
      _pinController.text = text;
      
      if (text.length == 6) {
        _submitCode(text);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final defaultPinTheme = PinTheme(
      width: 56,
      height: 64,
      textStyle: const TextStyle(
        fontSize: 24,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLowest,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: colorScheme.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Group'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xxl),
              Icon(
                Icons.group_add_rounded,
                size: 64,
                color: colorScheme.primary,
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Enter Group Code',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Ask the group owner for the 6-character code',
                style: textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              Center(
                child: Pinput(
                  length: 6,
                  controller: _pinController,
                  focusNode: _focusNode,
                  defaultPinTheme: defaultPinTheme,
                  focusedPinTheme: focusedPinTheme,
                  textCapitalization: TextCapitalization.characters,
                  pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
                  showCursor: true,
                  onCompleted: _submitCode,
                  readOnly: _isLoading,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _openScanner,
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text('Scan QR Code'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
