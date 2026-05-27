import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/order_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lastbite/features/user/providers/user_orders_provider.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:qr_flutter/qr_flutter.dart';

class UserOrderDetailScreen extends ConsumerStatefulWidget {
  final OrderModel order;

  const UserOrderDetailScreen({super.key, required this.order});

  @override
  ConsumerState<UserOrderDetailScreen> createState() => _UserOrderDetailScreenState();
}

class _UserOrderDetailScreenState extends ConsumerState<UserOrderDetailScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final supabase = Supabase.instance.client;
  bool _isProcessingChat = false;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(userOrdersProvider);
    OrderModel currentOrder = widget.order;
    
    ordersAsync.whenData((orders) {
      try {
        currentOrder = orders.firstWhere((o) => o.id == widget.order.id);
      } catch (_) {}
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Detail Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 140),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusHeader(currentOrder),
            _buildTimeline(currentOrder),
            if (currentOrder.status == 'ready_for_pickup' && currentOrder.deliveryMethod != 'delivery' && currentOrder.pickupCode != null)
              _buildPickupCode(currentOrder),
            _buildMerchantInfo(currentOrder),
            _buildOrderItems(currentOrder),
            _buildPaymentSummary(currentOrder),
            _buildOrderInfo(currentOrder),
          ],
        ),
      ),
      bottomSheet: _buildBottomActions(currentOrder),
    );
  }

  Widget _buildStatusHeader(OrderModel order) {
    final status = order.status;
    final paymentStatus = order.paymentStatus;
    
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    String title = '';
    String subtitle = '';
    IconData icon = SolarIconsOutline.infoCircle;

    if (status == 'completed') {
      bgColor = const Color(0xFF0F943B);
      textColor = Colors.white;
      title = 'Pesanan Selesai';
      subtitle = 'Terima kasih telah menyelamatkan makanan hari ini!';
      icon = SolarIconsOutline.checkCircle;
    } else if (status == 'cancelled') {
      bgColor = const Color(0xFFFF5252);
      textColor = Colors.white;
      title = 'Pesanan Dibatalkan';
      subtitle = 'Pesanan ini telah dibatalkan.';
      icon = SolarIconsOutline.closeCircle;
    } else if (status == 'pending_payment') {
      bgColor = const Color(0xFFFFCA28);
      title = 'Menunggu Pembayaran';
      subtitle = 'Selesaikan pembayaran agar pesanan diproses.';
      icon = SolarIconsOutline.card;
    } else if (status == 'paid' && paymentStatus == 'waiting_verification') {
      bgColor = const Color(0xFF60A5FA);
      textColor = Colors.white;
      title = 'Menunggu Verifikasi';
      subtitle = 'Penjual sedang memverifikasi pembayaranmu.';
      icon = SolarIconsOutline.hourglass;
    } else if (status == 'paid') {
      bgColor = const Color(0xFF60A5FA);
      textColor = Colors.white;
      title = 'Sedang Diproses';
      subtitle = 'Penjual sedang menyiapkan pesananmu.';
      icon = SolarIconsOutline.box;
    } else if (status == 'ready_for_pickup') {
      bgColor = const Color(0xFFF59E0B);
      textColor = Colors.white;
      title = widget.order.deliveryMethod == 'delivery' ? 'Pesanan Sedang Diantar' : 'Siap Diambil';
      subtitle = widget.order.deliveryMethod == 'delivery' ? 'Tunggu kurir tiba di lokasimu.' : 'Segera ambil pesananmu di toko.';
      icon = widget.order.deliveryMethod == 'delivery' ? SolarIconsOutline.routing : SolarIconsOutline.shop;
    } else if (status == 'picked_up') {
      bgColor = const Color(0xFF10B981);
      textColor = Colors.white;
      title = 'Barang Diterima';
      subtitle = 'Jangan lupa selesaikan pesanan jika sudah sesuai.';
      icon = SolarIconsOutline.like;
    }

    return Container(
      width: double.infinity,
      color: bgColor,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Row(
        children: [
          Icon(icon, color: textColor, size: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: textColor, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle, style: TextStyle(color: textColor.withValues(alpha: 0.9), fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(OrderModel order) {
    // 0: Pesanan Dibuat, 1: Dibayar, 2: Diproses, 3: Selesai
    int currentStep = 0;
    final s = order.status;
    final p = order.paymentStatus;
    
    if (s == 'cancelled') return const SizedBox();

    if (s == 'pending_payment') {
      currentStep = 0;
    } else if (s == 'paid' && p == 'waiting_verification') {
      currentStep = 1;
    } else if (s == 'paid') {
      currentStep = 2;
    } else if (s == 'ready_for_pickup' || s == 'picked_up') {
      currentStep = 3;
    } else if (s == 'completed') {
      currentStep = 4;
    }

    Widget buildStep(String text, int stepIndex) {
      final isCompleted = currentStep >= stepIndex;
      final isCurrent = currentStep == stepIndex;
      final color = isCompleted ? const Color(0xFF0F943B) : Colors.grey.shade300;
      return Column(
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: isCompleted ? color : Colors.white,
              border: Border.all(color: color, width: 2),
              shape: BoxShape.circle,
            ),
            child: isCompleted 
                ? const Icon(SolarIconsOutline.checkCircle, size: 14, color: Colors.white) 
                : null,
          ),
          const SizedBox(height: 8),
          Text(text, style: TextStyle(
            fontSize: 10,
            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
            color: isCurrent ? Colors.black87 : Colors.grey.shade500
          )),
        ],
      );
    }

    Widget buildLine(int stepIndex) {
      final isCompleted = currentStep >= stepIndex;
      return Expanded(
        child: Container(
          height: 2,
          color: isCompleted ? const Color(0xFF0F943B) : Colors.grey.shade200,
          margin: const EdgeInsets.only(bottom: 24),
        ),
      );
    }

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Riwayat Pesanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 20),
          Row(
            children: [
              buildStep('Dibuat', 0),
              buildLine(1),
              buildStep('Dibayar', 1),
              buildLine(2),
              buildStep('Diproses', 2),
              buildLine(3),
              buildStep(widget.order.deliveryMethod == 'delivery' ? 'Diantar' : 'Siap', 3),
              buildLine(4),
              buildStep('Selesai', 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPickupCode(OrderModel order) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Kode Pengambilan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
          ),
          const SizedBox(height: 16),
          const Text('Tunjukkan QR Code ini kepada penjual', style: TextStyle(fontSize: 13, color: Color(0xFF374151))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                if (widget.order.pickupCode != null)
                  QrImageView(
                    data: widget.order.pickupCode!,
                    version: QrVersions.auto,
                    size: 200.0,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black87,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black87,
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  order.pickupCode ?? '-',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF16A34A), letterSpacing: 4.0),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantInfo(OrderModel order) {
    final firstItem = order.items?.first;
    final merchant = firstItem?.product?.merchant;
    if (merchant == null) return const SizedBox();

    return GestureDetector(
      onTap: () => context.push('/merchant/${merchant.id}'),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.only(bottom: 12),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: merchant.avatarUrl != null ? NetworkImage(merchant.avatarUrl!) : null,
                  child: merchant.avatarUrl == null ? const Icon(SolarIconsOutline.shop, color: Colors.grey) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(merchant.storeName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
                      const SizedBox(height: 2),
                      const Text('Kunjungi Toko', style: TextStyle(fontSize: 12, color: Color(0xFF0F943B), fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                const Icon(SolarIconsOutline.altArrowRight, color: Colors.grey),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openChat(context),
                icon: const Icon(SolarIconsOutline.chatRound, size: 18),
                label: const Text('Chat Toko'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F943B),
                  side: const BorderSide(color: Color(0xFF0F943B)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderItems(OrderModel order) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian Produk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 16),
          if (order.items != null)
            ...order.items!.map((item) {
              final product = item.product;
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: product?.image != null
                          ? Image.network(CloudinaryService.getOptimizedUrl(product!.image!, width: 150), width: 64, height: 64, fit: BoxFit.cover)
                          : Container(width: 64, height: 64, color: Colors.grey.shade200, child: const Icon(SolarIconsOutline.hamburgerMenu, color: Colors.grey)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(product?.name ?? 'Produk', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
                          const SizedBox(height: 4),
                          Text('${item.quantity}x Item', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(currencyFormat.format(item.price ?? 0), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87)),
                              const SizedBox(width: 8),
                              if (product?.originalPrice != null)
                                Text(
                                  currencyFormat.format(product!.originalPrice),
                                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPaymentSummary(OrderModel order) {
    // Hitung subtotal berdasarkan order items
    double subtotal = 0;
    if (order.items != null) {
      for (var item in order.items!) {
        subtotal += (item.price ?? 0) * (item.quantity ?? 1);
      }
    }
    
    double adminFee = 1000;
    double deliveryFee = (order.totalPrice ?? 0) - subtotal - adminFee;
    if (deliveryFee < 0) deliveryFee = 0;
    
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Metode Pembayaran', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Text(order.payment?.method?.toUpperCase() ?? 'TRANSFER', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Subtotal Produk', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Text(currencyFormat.format(subtotal), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Biaya Penanganan', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Text(currencyFormat.format(adminFee), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
          if (order.deliveryMethod == 'delivery') ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Biaya Pengiriman', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                Text(currencyFormat.format(deliveryFee), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
              ],
            ),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF3F4F6)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
              Text(currencyFormat.format(order.totalPrice ?? 0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F943B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo(OrderModel order) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Nomor Pesanan', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Row(
                children: [
                  Text(order.id.substring(0, 8).toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: order.id.substring(0, 8).toUpperCase()));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor pesanan disalin'), duration: Duration(seconds: 1)));
                    },
                    child: const Icon(SolarIconsOutline.copy, size: 14, color: Color(0xFF0F943B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Waktu Pemesanan', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
              Text(order.createdAt != null ? dateFormat.format(order.createdAt!) : '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(OrderModel order) {
    final status = order.status;
    final paymentStatus = order.paymentStatus;
    final canCancel = status == 'pending_payment' || (status == 'paid' && paymentStatus == 'waiting_verification');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                // WhatsApp CS Button
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: _contactCS,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: const Icon(SolarIconsOutline.headphonesRound, color: Colors.black87),
              ),
            ),
            const SizedBox(width: 12),
            
            // Main Action Button
            if (status == 'pending_payment')
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () => context.push('/payment/${widget.order.id}', extra: widget.order),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F943B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Bayar Sekarang', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              )
            else if (status == 'picked_up')
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () async {
                    try {
                      await Supabase.instance.client.from('orders').update({'status': 'completed'}).eq('id', widget.order.id);
                      ref.read(userOrdersProvider.notifier).refresh();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pesanan berhasil diselesaikan!')));
                        context.pop();
                      }
                    } catch (e) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyelesaikan: $e')));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F943B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Selesaikan Pesanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              )
            else if (status == 'completed' || status == 'cancelled')
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: () => context.go('/home'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F943B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Pesan Lagi', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              )
            else
              Expanded(
                flex: 3,
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Menunggu Penjual', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        if (canCancel) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _confirmCancelOrder(),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFFF5252),
                side: const BorderSide(color: Color(0xFFFF5252), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Batalkan Pesanan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ],
    ),
  ),
);
  }

  void _confirmCancelOrder() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Batalkan Pesanan', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Apakah Anda yakin ingin membatalkan pesanan ini? Aksi ini tidak dapat dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Tidak', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _cancelOrder();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5252),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Batalkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder() async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
      );

      await Supabase.instance.client.from('orders').update({'status': 'cancelled'}).eq('id', widget.order.id);
      
      ref.read(userOrdersProvider.notifier).refresh();
      
      if (mounted) {
        Navigator.pop(context); // close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan berhasil dibatalkan'), backgroundColor: Color(0xFF16A34A)),
        );
        context.pop(); // go back to previous screen
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membatalkan pesanan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _contactCS() async {
    final orderId = widget.order.id.substring(0, 8).toUpperCase();
    final message = "Halo CS LastBite, saya butuh bantuan terkait pesanan saya #$orderId.";
    final url = Uri.parse("https://wa.me/6287863306466?text=${Uri.encodeComponent(message)}");
    
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tidak dapat membuka WhatsApp')));
      }
    }
  }

  Future<void> _openChat(BuildContext context) async {
    if (_isProcessingChat) return;

    final myUid = supabase.auth.currentUser?.id;
    if (myUid == null) return;
    
    final merchant = widget.order.items?.first.product?.merchant;
    if (merchant == null) return;
    
    final productName = widget.order.items?.first.product?.name ?? '';
    final productPrice = widget.order.totalPrice != null ? currencyFormat.format(widget.order.totalPrice) : '';
    final productImage = widget.order.items?.first.product?.image;

    setState(() => _isProcessingChat = true);

    bool isDialogShowing = false;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFF0F943B))),
      );
      isDialogShowing = true;
      await Future.delayed(Duration.zero);

      final existingChat = await supabase
          .from('chats')
          .select('id')
          .eq('buyer_id', myUid)
          .eq('merchant_id', merchant.id)
          .maybeSingle();

      String chatId;
      if (existingChat != null) {
        chatId = existingChat['id'] as String;
      } else {
        final newChat = await supabase
            .from('chats')
            .insert({
              'buyer_id': myUid,
              'merchant_id': merchant.id,
              'last_message': '',
            })
            .select('id')
            .single();
        chatId = newChat['id'] as String;
      }

      if (isDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }

      if (context.mounted) {
        context.push('/chat-detail', extra: {
          'chatId': chatId,
          'peerName': merchant.storeName,
          'peerAvatar': merchant.avatarUrl ?? '',
          'isUserSide': true,
          'productName': 'Terkait pesanan #$productName',
          'productPrice': productPrice,
          'productImage': productImage,
        });
      }
    } catch (e) {
      if (isDialogShowing && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        isDialogShowing = false;
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka chat: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingChat = false);
    }
  }
}
