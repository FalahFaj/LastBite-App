import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/order_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:lastbite/features/merchant/screens/scan_qr_screen.dart';

class MerchantOrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const MerchantOrderDetailScreen({super.key, required this.order});

  @override
  State<MerchantOrderDetailScreen> createState() => _MerchantOrderDetailScreenState();
}

class _MerchantOrderDetailScreenState extends State<MerchantOrderDetailScreen> {
  final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
  final supabase = Supabase.instance.client;
  bool _isProcessingChat = false;
  bool _isLoading = false;
  late OrderModel _currentOrder;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _currentOrder = widget.order;
    _setupSubscription();
  }

  void _setupSubscription() {
    _subscription = supabase.channel('public:orders:merchant_detail_${_currentOrder.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'id',
          value: _currentOrder.id,
        ),
        callback: (payload) {
          if (mounted) {
            _fetchOrder();
          }
        },
      )
      .subscribe();
  }

  Future<void> _fetchOrder() async {
    try {
      final data = await supabase
          .from('orders')
          .select('''
            id, status, payment_status, total_price, pickup_code, delivery_method, picked_up_at, created_at, buyer_id,
            users(*),
            order_items(
              id, quantity, price,
              products(id, name, image, merchant_id, merchants(*))
            ),
            payments(id, method, payment_proof, status)
          ''')
          .eq('id', _currentOrder.id)
          .single();
      if (mounted) {
        setState(() {
          _currentOrder = OrderModel.fromJson(data);
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color(0xFFF9FAFB),
          appBar: AppBar(
            title: const Text('Detail Pesanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 0,
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatusHeader(),
                _buildTimeline(),
                _buildBuyerInfo(),
                _buildOrderItems(),
                _buildPaymentSummary(),
                _buildOrderInfo(),
              ],
            ),
          ),
          bottomSheet: _buildBottomActions(),
        ),
        if (_isLoading)
          Container(
            color: Colors.black45,
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF16A34A)),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusHeader() {
    final status = _currentOrder.status;
    final paymentStatus = _currentOrder.paymentStatus;
    
    Color bgColor = Colors.white;
    Color textColor = Colors.black87;
    String title = '';
    String subtitle = '';
    IconData icon = SolarIconsOutline.infoCircle;

    if (status == 'completed') {
      bgColor = const Color(0xFF0F943B);
      textColor = Colors.white;
      title = 'Pesanan Selesai';
      subtitle = 'Pesanan ini telah berhasil diselesaikan.';
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
      subtitle = 'Menunggu pembeli melakukan pembayaran.';
      icon = SolarIconsOutline.card;
    } else if (status == 'paid' && paymentStatus == 'waiting_verification') {
      bgColor = const Color(0xFF60A5FA);
      textColor = Colors.white;
      title = 'Menunggu Verifikasi';
      subtitle = 'Segera verifikasi bukti pembayaran pembeli.';
      icon = SolarIconsOutline.hourglass;
    } else if (status == 'paid') {
      bgColor = const Color(0xFF60A5FA);
      textColor = Colors.white;
      title = 'Sedang Diproses';
      subtitle = 'Siapkan pesanan untuk pembeli.';
      icon = SolarIconsOutline.box;
    } else if (status == 'ready_for_pickup') {
      bgColor = const Color(0xFFF59E0B);
      textColor = Colors.white;
      title = _currentOrder.deliveryMethod == 'delivery' ? 'Pesanan Sedang Diantar' : 'Siap Diambil';
      subtitle = _currentOrder.deliveryMethod == 'delivery' ? 'Kirimkan pesanan ke pembeli.' : 'Tunggu pembeli mengambil pesanan.';
      icon = _currentOrder.deliveryMethod == 'delivery' ? SolarIconsOutline.routing : SolarIconsOutline.shop;
    } else if (status == 'picked_up') {
      bgColor = const Color(0xFF10B981);
      textColor = Colors.white;
      title = 'Barang Diterima';
      subtitle = 'Pembeli sudah menerima pesanan ini.';
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

  Widget _buildTimeline() {
    int currentStep = 0;
    final s = _currentOrder.status;
    final p = _currentOrder.paymentStatus;
    
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
              buildStep(_currentOrder.deliveryMethod == 'delivery' ? 'Diantar' : 'Siap', 3),
              buildLine(4),
              buildStep('Selesai', 4),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerInfo() {
    final buyer = _currentOrder.buyer;
    if (buyer == null) return const SizedBox();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Informasi Pembeli', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: buyer.userPictureUrl != null ? NetworkImage(buyer.userPictureUrl!) : null,
                child: buyer.userPictureUrl == null ? const Icon(SolarIconsOutline.user, color: Colors.grey) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(buyer.name ?? 'Pembeli', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87)),
                    if (buyer.phone != null) ...[
                      const SizedBox(height: 2),
                      Text(buyer.phone!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    ]
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openChat(context),
              icon: const Icon(SolarIconsOutline.chatRound, size: 18),
              label: const Text('Chat Pembeli'),
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
    );
  }

  Widget _buildOrderItems() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Rincian Produk', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87)),
          const SizedBox(height: 16),
          if (_currentOrder.items != null)
            ..._currentOrder.items!.map((item) {
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

  Widget _buildPaymentSummary() {
    double subtotal = 0;
    if (_currentOrder.items != null) {
      for (var item in _currentOrder.items!) {
        subtotal += (item.price ?? 0) * (item.quantity ?? 1);
      }
    }
    double deliveryFee = _currentOrder.deliveryMethod == 'delivery' ? 10000 : 0;
    
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
              Text(_currentOrder.payment?.method?.toUpperCase() ?? 'TRANSFER', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
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
          if (_currentOrder.deliveryMethod == 'delivery') ...[
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
              Text(currencyFormat.format(_currentOrder.totalPrice ?? 0), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F943B))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
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
                  Text(_currentOrder.id.substring(0, 8).toUpperCase(), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _currentOrder.id.substring(0, 8).toUpperCase()));
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
              Text(_currentOrder.createdAt != null ? dateFormat.format(_currentOrder.createdAt!) : '-', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    final status = _currentOrder.status;
    final paymentStatus = _currentOrder.paymentStatus;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            if (status == 'pending_payment')
              Expanded(
                child: ElevatedButton(
                  onPressed: null,
                  style: ElevatedButton.styleFrom(
                    disabledBackgroundColor: Colors.grey.shade200,
                    disabledForegroundColor: Colors.grey.shade500,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Menunggu Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              )
            else if (status == 'paid' && paymentStatus == 'waiting_verification')
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _verifyPaymentDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF60A5FA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Verifikasi Pembayaran', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              )
            else if (status == 'paid' && paymentStatus == 'verified')
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _updateOrderStatus('ready_for_pickup'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F943B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Pesanan Siap Diambil', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              )
            else if (status == 'ready_for_pickup')
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _verifyPickupCodeDialog(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Verifikasi Kode Pengambilan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              )
            else
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: Colors.grey.shade800,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Kembali', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // --- ACTIONS LOGIC ---
  
  Future<void> _updateOrderStatus(String newStatus) async {
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);

      await supabase.from('orders').update({'status': newStatus}).eq('id', _currentOrder.id);
      
      if (mounted) {
        setState(() {
          _currentOrder = _currentOrder.copyWith(status: newStatus);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Status pesanan berhasil diperbarui'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _verifyPaymentDialog() {
    final payment = _currentOrder.payment;
    final proofUrl = payment?.paymentProof;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verifikasi Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pembeli telah melakukan pembayaran. Silakan cek bukti transfer di bawah ini:'),
            const SizedBox(height: 16),
            if (proofUrl != null && proofUrl.isNotEmpty)
              GestureDetector(
                onTap: () => _showPaymentProof(proofUrl),
                child: Container(
                  width: double.infinity,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(proofUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(SolarIconsOutline.gallery, color: Colors.grey)),
                  ),
                ),
              )
            else
              const Text('Bukti transfer tidak tersedia', style: TextStyle(color: Colors.red, fontStyle: FontStyle.italic)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _verifyPaymentProcess();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Verifikasi', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  Future<void> _verifyPaymentProcess() async {
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);

      await supabase.from('orders').update({
        'payment_status': 'verified',
      }).eq('id', _currentOrder.id);
      
      if (mounted) {
        setState(() {
          _currentOrder = _currentOrder.copyWith(paymentStatus: 'verified');
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pembayaran berhasil diverifikasi'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal verifikasi pembayaran: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showPaymentProof(String? proofUrl) {
    if (proofUrl == null || proofUrl.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(SolarIconsOutline.closeSquare, color: Colors.white, size: 28),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                proofUrl,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 300,
                    color: Colors.white10,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _verifyPickupCodeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Verifikasi Kode', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('Pilih metode verifikasi kode pengambilan dari pembeli:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _startQRScan();
            },
            icon: const Icon(SolarIconsOutline.scanner, size: 18),
            label: const Text('Scan QR Code'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _startQRScan() async {
    final expectedCode = _currentOrder.pickupCode;
    if (expectedCode == null) return;
    
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => ScanQrScreen(expectedCode: expectedCode),
      ),
    );

    if (result == true) {
      _completeOrderProcess();
    } else if (result != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal scan barcode'), backgroundColor: Colors.red),
      );
    }
  }
  
  Future<void> _completeOrderProcess() async {
    if (_isLoading) return;
    try {
      setState(() => _isLoading = true);

      await supabase.from('orders').update({
        'status': 'completed',
        'picked_up_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _currentOrder.id);
      
      if (mounted) {
        setState(() {
          _currentOrder = _currentOrder.copyWith(status: 'completed');
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pesanan selesai!'), backgroundColor: Color(0xFF16A34A)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyelesaikan pesanan: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _openChat(BuildContext context) async {
    if (_isProcessingChat) return;

    final myUid = supabase.auth.currentUser?.id;
    if (myUid == null) return;
    
    final buyer = _currentOrder.buyer;
    if (buyer == null) return;
    
    final merchantRes = await supabase.from('merchants').select('id').eq('user_id', myUid).maybeSingle();
    if (merchantRes == null) return;
    final merchantId = merchantRes['id'] as String;

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
          .eq('buyer_id', buyer.id)
          .eq('merchant_id', merchantId)
          .maybeSingle();

      String chatId;
      if (existingChat != null) {
        chatId = existingChat['id'] as String;
      } else {
        final newChat = await supabase
            .from('chats')
            .insert({
              'buyer_id': buyer.id,
              'merchant_id': merchantId,
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
          'peerName': buyer.name ?? 'Pembeli',
          'peerAvatar': buyer.userPictureUrl ?? '',
          'isUserSide': false,
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
