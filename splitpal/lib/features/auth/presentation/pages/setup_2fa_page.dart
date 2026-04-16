import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:splitpal/features/auth/auth_provider.dart';

class Setup2FAPage extends StatefulWidget {
  const Setup2FAPage({super.key});

  @override
  State<Setup2FAPage> createState() => _Setup2FAPageState();
}

class _Setup2FAPageState extends State<Setup2FAPage> {
  int _step = 0; // 0 = loading, 1 = QR code, 2 = verify, 3 = backup codes
  String? _qrCodeUrl;
  String? _manualKey;
  List<String> _backupCodes = [];
  String? _errorMessage;
  bool _isLoading = false;
  final _codeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initSetup();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _initSetup() async {
    setState(() => _step = 0);
    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.setup2FA();

    if (!mounted) return;

    if (result != null) {
      setState(() {
        _qrCodeUrl = result['qrCodeUrl'] as String?;
        _manualKey = result['manualKey'] as String?;
        _step = 1;
      });
    } else {
      setState(() {
        _errorMessage = 'Failed to initialize 2FA setup';
        _step = 1;
      });
    }
  }

  Future<void> _handleVerify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter a 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authProvider = context.read<AuthProvider>();
    final result = await authProvider.verifySetup2FA(token: code);

    if (!mounted) return;

    if (result != null && result['backupCodes'] != null) {
      final codes = (result['backupCodes'] as List).cast<String>();
      setState(() {
        _backupCodes = codes;
        _step = 3;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = result?['error'] as String? ?? 'Invalid code. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Set Up 2FA',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    switch (_step) {
      case 0:
        return const Center(
          child: CircularProgressIndicator(color: Color(0xFF6C5CE7)),
        );
      case 1:
        return _buildQRCodeStep();
      case 2:
        return _buildVerifyStep();
      case 3:
        return _buildBackupCodesStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildQRCodeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_2,
              size: 36,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Scan QR Code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Scan this QR code with your authenticator app\n(Google Authenticator, Authy, etc.)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          // QR Code Image
          if (_qrCodeUrl != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: _buildQRImage(),
            ),
          if (_errorMessage != null && _qrCodeUrl == null)
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13),
            ),
          const SizedBox(height: 20),
          // Manual key
          if (_manualKey != null) ...[
            Text(
              'Or enter this key manually:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: _manualKey!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Key copied to clipboard')),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.15)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        _manualKey!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          fontFamily: 'monospace',
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy, size: 18, color: Colors.white.withOpacity(0.5)),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => setState(() {
                _step = 2;
                _errorMessage = null;
              }),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildQRImage() {
    if (_qrCodeUrl == null) return const SizedBox.shrink();

    // QR code URL is a data URI (data:image/png;base64,...)
    if (_qrCodeUrl!.startsWith('data:image')) {
      final base64Str = _qrCodeUrl!.split(',').last;
      return Image.memory(
        base64Decode(base64Str),
        width: 220,
        height: 220,
        fit: BoxFit.contain,
      );
    }

    return Image.network(
      _qrCodeUrl!,
      width: 220,
      height: 220,
      fit: BoxFit.contain,
    );
  }

  Widget _buildVerifyStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.pin,
              size: 36,
              color: Color(0xFF6C5CE7),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Enter Verification Code',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the 6-digit code shown in\nyour authenticator app',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: _codeController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 8,
            ),
            decoration: InputDecoration(
              counterText: '',
              hintText: '000000',
              hintStyle: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.2),
                letterSpacing: 8,
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.08),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFF6C5CE7), width: 2),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            ),
            onSubmitted: (_) => _handleVerify(),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFFE74C3C), fontSize: 13),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleVerify,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                disabledBackgroundColor: const Color(0xFF6C5CE7).withOpacity(0.5),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'Verify & Enable',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() {
              _step = 1;
              _errorMessage = null;
              _codeController.clear();
            }),
            child: Text(
              'Back to QR Code',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCodesStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: const Color(0xFF27AE60).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 36,
              color: Color(0xFF27AE60),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '2FA Enabled!',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Save these backup codes in a safe place.\nEach code can only be used once.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE74C3C).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 18, color: Colors.amber.withOpacity(0.8)),
                    const SizedBox(width: 6),
                    Text(
                      'Backup Codes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.withOpacity(0.9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: _backupCodes.map((code) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 1.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Copy all button
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _backupCodes.join('\n')));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Backup codes copied to clipboard')),
              );
            },
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('Copy All Codes'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: Colors.white.withOpacity(0.3)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6C5CE7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Done',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
