import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerView extends StatefulWidget {
  const ScannerView({super.key});

  @override
  State<ScannerView> createState() => _ScannerViewState();
}

class _ScannerViewState extends State<ScannerView> {
  late MobileScannerController controller;
  bool isScanCompleted = false;
  bool _torchOn = false;

  @override
  void initState() {
    super.initState();
    controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (isScanCompleted) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        String code = barcode.rawValue!;
        
        // If it's a URL, try to extract the join code
        if (code.contains('join?code=')) {
          final uri = Uri.tryParse(code);
          if (uri != null && uri.queryParameters.containsKey('code')) {
            code = uri.queryParameters['code']!;
          }
        }

        setState(() {
          isScanCompleted = true;
        });

        // Close scanner and return the code
        Navigator.of(context).pop(code.toUpperCase());
        break;
      }
    }
  }

  void _toggleTorch() {
    controller.toggleTorch();
    setState(() {
      _torchOn = !_torchOn;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              color: _torchOn ? Colors.yellow : Colors.grey,
            ),
            onPressed: _toggleTorch,
          ),
          IconButton(
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            onPressed: () => controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),
          // A scanning overlay frame
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withAlpha(128), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
            width: 250,
            height: 250,
          ),
          Positioned(
            bottom: 40,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(153),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Align QR code within the frame',
                style: TextStyle(color: Colors.white),
              ),
            ),
          )
        ],
      ),
    );
  }
}
