import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../theme/ratnex_theme.dart';
import '../utils/haptics.dart';

/// Full-screen camera scanner. Returns the scanned value, or null if cancelled.
///
/// Used at the billing counter (scan a tag straight into the bill) and in the
/// stock list (scan to look an item up).
Future<String?> showBarcodeScanner(
  BuildContext context, {
  String title = 'Scan tag',
  String hint = 'Point the camera at the barcode on the tag',
}) {
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => _BarcodeScanPage(title: title, hint: hint),
    ),
  );
}

class _BarcodeScanPage extends StatefulWidget {
  final String title;
  final String hint;

  const _BarcodeScanPage({required this.title, required this.hint});

  @override
  State<_BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<_BarcodeScanPage> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
      BarcodeFormat.qrCode,
      BarcodeFormat.dataMatrix,
    ],
  );

  bool _handled = false;
  bool _torch = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.trim().isNotEmpty, orElse: () => null);
    if (code == null) return;
    _handled = true;
    Haptics.success();
    Navigator.of(context).pop(code.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          widget.title,
          style: RatnexTheme.label(
            size: 16,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            tooltip: _torch ? 'Torch off' : 'Torch on',
            onPressed: () async {
              await _controller.toggleTorch();
              if (mounted) setState(() => _torch = !_torch);
            },
            icon: Icon(
              _torch ? Icons.flashlight_on : Icons.flashlight_off,
              color: _torch ? RatnexColors.rateAccent : Colors.white,
            ),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch_outlined, color: Colors.white),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, _) {
              _error = error.errorDetails?.message ?? 'Camera unavailable';
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.no_photography_outlined,
                        color: Colors.white54,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Cannot open the camera',
                        style: RatnexTheme.label(
                          size: 15,
                          weight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_error\n\nAllow camera access for Ratnex in your phone settings, then try again.',
                        textAlign: TextAlign.center,
                        style: RatnexTheme.label(
                          size: 12.5,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          IgnorePointer(
            child: Center(
              child: Container(
                width: 250,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(color: RatnexColors.rateAccent, width: 2),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 44,
            child: Text(
              widget.hint,
              textAlign: TextAlign.center,
              style: RatnexTheme.label(size: 13, color: Colors.white70),
            ),
          ),
        ],
      ),
    );
  }
}
