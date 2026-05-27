import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/order_model.dart';
import 'package:lastbite/features/user/providers/payment_provider.dart';
import 'package:lastbite/features/user/screens/user_orders_screen.dart';
import 'package:solar_icons/solar_icons.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const PaymentDetailScreen({super.key, required this.order});

  @override
  ConsumerState<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  final ImagePicker _picker = ImagePicker();
  Timer? _countdownTimer;
  Duration _remainingTime = const Duration(minutes: 60);
  bool _isExpired = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    final createdAt = widget.order.createdAt ?? DateTime.now();
    final expiryTime = createdAt.add(const Duration(minutes: 60));
    
    _updateRemainingTime(expiryTime);

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateRemainingTime(expiryTime);
    });
  }

  void _updateRemainingTime(DateTime expiryTime) {
    final now = DateTime.now();
    final difference = expiryTime.difference(now);

    if (difference.isNegative) {
      if (!_isExpired) {
        setState(() {
          _remainingTime = Duration.zero;
          _isExpired = true;
        });
        _countdownTimer?.cancel();
        _cancelOrderAutomatically();
      }
    } else {
      setState(() {
        _remainingTime = difference;
        _isExpired = false;
      });
    }
  }

  Future<void> _cancelOrderAutomatically() async {
    // Update status di Supabase jika sudah expire saat user membuka halaman ini
    try {
      await ref.read(paymentProvider.notifier).cancelOrder(widget.order.id);
      
      // Tunggu sebentar agar user sempat membaca pesan pembatalan
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        // Pindah ke tab Dibatalkan di Pesanan Saya
        ref.read(orderFilterProvider.notifier).setFilter('Dibatalkan');
        context.go('/orders');
      }
    } catch (e) {
      debugPrint('Error auto-cancelling order: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  Future<void> _pickImage() async {
    try {
      final ImageSource? source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              const Text(
                'Pilih Sumber Bukti Pembayaran',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(SolarIconsOutline.camera, color: Color(0xFF0F943B)),
                title: const Text('Kamera', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(SolarIconsOutline.gallery, color: Color(0xFF0F943B)),
                title: const Text('Galeri', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (source != null) {
        final XFile? pickedFile = await _picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1200,
          maxHeight: 1200,
        );
        if (pickedFile != null) {
          ref.read(paymentProvider.notifier).setImage(File(pickedFile.path));
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final paymentState = ref.watch(paymentProvider);
    final isTransfer = widget.order.payment?.method == 'transfer' || widget.order.payment?.method == null;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Detail Pembayaran',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w800, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timer Card
            if (!_isExpired)
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(SolarIconsOutline.clockCircle, color: Colors.orange.shade800, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Selesaikan pembayaran dalam',
                            style: TextStyle(fontSize: 12, color: Colors.orange.shade900, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            _formatDuration(_remainingTime),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFFE65100)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(SolarIconsOutline.dangerCircle, color: Colors.red.shade800, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Waktu pembayaran telah habis. Pesanan ini otomatis dibatalkan.',
                        style: TextStyle(fontSize: 13, color: Colors.red.shade900, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),

            // Total Pembayaran
            Center(
              child: Column(
                children: [
                  Text(
                    'Total Pembayaran',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currencyFormat.format(widget.order.totalPrice ?? 0),
                    style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900, color: Color(0xFF0F943B)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Instruksi Pembayaran
            const Text(
              'Instruksi Pembayaran',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            isTransfer ? _buildTransferInstruction() : _buildQrisInstruction(),

            const SizedBox(height: 32),

            // Upload Bukti
            const Text(
              'Upload Bukti Transfer',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            _buildUploadSection(paymentState),

            const SizedBox(height: 40),

            // Tombol Kirim
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isExpired || paymentState.selectedImage == null || paymentState.isLoading
                    ? null
                    : () async {
                        try {
                          final success = await ref.read(paymentProvider.notifier).uploadPaymentProof(widget.order.id);
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Bukti pembayaran berhasil diupload!'),
                                backgroundColor: Color(0xFF0F943B),
                              ),
                            );
                            context.pop(); // Kembali ke halaman pesanan
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gagal mengupload: ${e.toString()}'),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
                              ),
                            );
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F943B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  elevation: 0,
                ),
                child: paymentState.isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'Kirim Bukti Pembayaran',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferInstruction() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Bank BNI',
                  style: TextStyle(color: Colors.blue.shade700, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Nomor Rekening',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Text(
                '2047942137',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: 1),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(const ClipboardData(text: '2047942137'));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nomor rekening disalin'), duration: Duration(seconds: 1)),
                  );
                },
                child: const Text(
                  'Salin',
                  style: TextStyle(color: Color(0xFF0F943B), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Atas Nama',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 4),
          const Text(
            'MUHAMMAD RIZQI RAMADHANI',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildQrisInstruction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Image.asset(
            'assets/images/qris_lastbite.jpeg',
            width: 600,
            height: 600,
          ),
          const SizedBox(height: 20),
          const Text(
            'Scan QR code di atas menggunakan aplikasi mobile banking atau e-wallet Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.black54, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadSection(PaymentState state) {
    if (state.selectedImage != null) {
      return Container(
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(
                state.selectedImage!,
                fit: BoxFit.cover,
                cacheWidth: 600, // Mengurangi beban memori decoder
              ),
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => ref.read(paymentProvider.notifier).removeImage(),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(SolarIconsOutline.closeSquare, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _isExpired ? null : _pickImage,
      child: Opacity(
        opacity: _isExpired ? 0.5 : 1.0,
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0F943B).withValues(alpha: 0.3), style: BorderStyle.solid, width: 2),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F943B).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(SolarIconsOutline.cloudUpload, color: Color(0xFF0F943B), size: 32),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih Foto Bukti Transfer',
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF0F943B)),
              ),
              const SizedBox(height: 4),
              Text(
                'Format .JPG atau .PNG',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
