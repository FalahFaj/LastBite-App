import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:solar_icons/solar_icons.dart';

class ScanQrScreen extends StatefulWidget {
  final String expectedCode;

  const ScanQrScreen({super.key, required this.expectedCode});

  @override
  State<ScanQrScreen> createState() => _ScanQrScreenState();
}

class _ScanQrScreenState extends State<ScanQrScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final TextEditingController _manualInputController = TextEditingController();
  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null) {
        setState(() {
          _manualInputController.text = code;
        });
        _verifyCode(code);
      }
    }
  }

  void _verifyCode(String code) {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    _scannerController.stop();

    if (code == widget.expectedCode) {
      _showSuccessDialog();
    } else {
      _showErrorDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(SolarIconsBold.checkCircle, color: Color(0xFF16A34A), size: 48),
            SizedBox(height: 12),
            Text('Kode Cocok!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
          ],
        ),
        content: const Text('Kode pengambilan sesuai. Lanjutkan untuk menyelesaikan serah terima pesanan.', textAlign: TextAlign.center),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx); // Close dialog
                Navigator.pop(context, true); // Return success
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Column(
          children: [
            Icon(SolarIconsBold.closeCircle, color: Colors.red, size: 48),
            SizedBox(height: 12),
            Text('Kode Tidak Cocok', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18), textAlign: TextAlign.center),
          ],
        ),
        content: const Text('Kode yang Anda masukkan tidak sesuai dengan kode pesanan ini.', textAlign: TextAlign.center),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    Navigator.pop(context, false); // Cancel scan
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Colors.grey),
                  ),
                  child: const Text('Batal Scan', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx); // Close dialog
                    setState(() {
                      _isProcessing = false;
                      _manualInputController.clear();
                    });
                    _scannerController.start();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Scan Ulang', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Verifikasi QR Code', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                // Scanner Overlay (Kotak bidik)
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFF16A34A), width: 3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Atau masukkan kode secara manual:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _manualInputController,
                    decoration: InputDecoration(
                      hintText: 'Misal: LB-1234',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: IconButton(
                        icon: const Icon(SolarIconsOutline.altArrowRight, color: Color(0xFF16A34A)),
                        onPressed: () {
                          if (_manualInputController.text.isNotEmpty) {
                            _verifyCode(_manualInputController.text.trim());
                          }
                        },
                      ),
                    ),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _verifyCode(value.trim());
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
