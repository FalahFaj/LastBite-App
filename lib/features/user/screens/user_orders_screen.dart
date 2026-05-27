import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/order_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:lastbite/features/user/providers/user_orders_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solar_icons/solar_icons.dart';

class OrderFilterNotifier extends Notifier<String> {
  @override
  String build() => 'Aktif';

  void setFilter(String filter) => state = filter;
}

final orderFilterProvider = NotifierProvider<OrderFilterNotifier, String>(() {
  return OrderFilterNotifier();
});

class UserOrdersScreen extends ConsumerStatefulWidget {
  const UserOrdersScreen({super.key});

  @override
  ConsumerState<UserOrdersScreen> createState() => _UserOrdersScreenState();
}

class _UserOrdersScreenState extends ConsumerState<UserOrdersScreen> {
  final List<String> _filters = ['Semua', 'Aktif', 'Selesai', 'Dibatalkan', 'Pengembalian'];
  bool _isProcessingChat = false;

  @override
  Widget build(BuildContext context) {
    final ordersAsync = ref.watch(userOrdersProvider);
    final selectedFilter = ref.watch(orderFilterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildFilterTabs(selectedFilter),
            Expanded(
              child: ordersAsync.when(
                data: (orders) {
                  final filteredOrders = _getFilteredOrders(orders, selectedFilter);
                  
                  if (filteredOrders.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () => ref.read(userOrdersProvider.notifier).refresh(),
                      color: const Color(0xFF0F943B),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: constraints.maxHeight,
                                child: _buildEmptyState(selectedFilter),
                              ),
                            ],
                          );
                        }
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () => ref.read(userOrdersProvider.notifier).refresh(),
                    color: const Color(0xFF0F943B),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: filteredOrders.length,
                      itemBuilder: (context, index) {
                        return _buildOrderCard(filteredOrders[index]);
                      },
                    ),
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0F943B)),
                ),
                error: (error, stackTrace) => Center(
                  child: Text('Terjadi kesalahan: $error'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<OrderModel> _getFilteredOrders(List<OrderModel> orders, String selectedFilter) {
    final validOrders = orders.where((o) => o.items != null && o.items!.isNotEmpty).toList();
    if (selectedFilter == 'Semua') return validOrders;
    
    return validOrders.where((order) {
      final status = order.status ?? 'pending_payment';
      if (selectedFilter == 'Aktif') {
        return status == 'pending_payment' || status == 'paid' || status == 'ready_for_pickup';
      } else if (selectedFilter == 'Selesai') {
        return status == 'completed' || status == 'picked_up';
      } else if (selectedFilter == 'Dibatalkan') {
        return status == 'cancelled';
      } else if (selectedFilter == 'Pengembalian') {
        return status == 'refunded';
      }
      return true;
    }).toList();
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Pesanan Saya',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Setiap penyelamatan selalu berdampak! Catat hematmu dan dampak yang kamu ciptakan.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs(String selectedFilter) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: _filters.map((filter) {
            final isSelected = selectedFilter == filter;
            return GestureDetector(
              onTap: () {
                ref.read(orderFilterProvider.notifier).setFilter(filter);
              },
              child: Container(
                margin: const EdgeInsets.only(right: 24),
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isSelected ? const Color(0xFF0F943B) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? const Color(0xFF0F943B) : Colors.grey.shade400,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    
    // Safety check for items
    if (order.items == null || order.items!.isEmpty) return const SizedBox.shrink();
    
    final firstItem = order.items!.first;
    final merchantName = firstItem.product?.merchant?.storeName ?? 'Toko';
    
    final imageUrl = firstItem.product?.image != null
        ? CloudinaryService.getOptimizedUrl(firstItem.product!.image!, width: 150, height: 150)
        : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=200';

    // Status UI logic
    final status = order.status ?? 'pending_payment';
    Color badgeColor;
    Color badgeTextColor;
    String badgeText;
    
    if (status == 'completed') {
      badgeColor = const Color(0xFF0F943B);
      badgeTextColor = Colors.white;
      badgeText = 'Selesai';
    } else if (status == 'cancelled') {
      badgeColor = const Color(0xFFFF5252);
      badgeTextColor = Colors.white;
      badgeText = 'Dibatalkan';
    } else {
      // Aktif
      badgeColor = const Color(0xFFFFCA28);
      badgeTextColor = Colors.black87;
      if (status == 'pending_payment') {
        badgeText = 'Menunggu Pembayaran';
      } else if (status == 'paid' && order.paymentStatus == 'waiting_verification') {
        badgeText = 'Menunggu Verifikasi';
      } else if (status == 'paid') {
        badgeText = 'Dalam Proses';
      } else if (status == 'ready_for_pickup') {
        badgeText = order.deliveryMethod == 'delivery' ? 'Pesanan Diantar' : 'Siap Diambil';
      } else if (status == 'picked_up') {
        badgeText = 'Pesanan Diterima';
      } else {
        badgeText = 'Menunggu';
      }
    }

    return GestureDetector(
      onTap: () => context.push('/order-detail/${order.id}', extra: order),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(SolarIconsOutline.shop, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    merchantName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: badgeColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: badgeTextColor),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${order.createdAt != null ? dateFormat.format(order.createdAt!) : 'Hari ini'} • Order #${order.id.substring(0, 8).toUpperCase()}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    imageUrl,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstItem.product?.name ?? 'Produk',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${firstItem.quantity}x Item',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            currencyFormat.format(firstItem.price ?? 0),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black87),
                          ),
                          const SizedBox(width: 8),
                          if (firstItem.product?.originalPrice != null)
                            Text(
                              currencyFormat.format(firstItem.product!.originalPrice),
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoBox(order, firstItem),
          // Dashed Divider
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: List.generate(
                30,
                (index) => Expanded(
                  child: Container(
                    height: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    color: Colors.grey.shade200,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Text(
                  status == 'cancelled' ? 'Dikembalikan' : 'Total Pesanan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500),
                ),
                const Spacer(),
                Text(
                  currencyFormat.format(order.totalPrice ?? 0),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87),
                ),
              ],
            ),
          ),
          _buildActionButtons(order),
        ],
      ),
      ),
    );
  }

  Widget _buildInfoBox(OrderModel order, dynamic firstItem) {
    final status = order.status ?? 'pending_payment';
    if (status == 'completed') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F8F1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(SolarIconsOutline.global, color: Color(0xFF0F943B), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                  children: [
                    TextSpan(text: 'Eco-Hero! ', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF0F943B))),
                    TextSpan(text: 'Kamu menghemat '),
                    TextSpan(text: 'Rp 35.000 ', style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: '& mengurangi limbah makanan sebesar '),
                    TextSpan(text: '0,5 kg.', style: TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    } else if (status == 'cancelled') {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const Icon(SolarIconsOutline.infoCircle, color: Color(0xFFFF5252), size: 16),
            const SizedBox(width: 8),
            Text(
              'Dibatalkan oleh Penjual',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    } else {
      // Aktif
      if (status == 'ready_for_pickup' && order.pickupCode != null && order.deliveryMethod != 'delivery') {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFBBF7D0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Kode Pengambilan:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
              Text(
                order.pickupCode!,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF16A34A), letterSpacing: 2.0),
              ),
            ],
          ),
        );
      }
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFDF5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(SolarIconsOutline.clockCircle, color: Color(0xFFFBC02D), size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: RichText(
                text: const TextSpan(
                  style: TextStyle(fontSize: 11, color: Colors.black87, height: 1.4),
                  children: [
                    TextSpan(text: 'Ambil sebelum pukul '),
                    TextSpan(text: '18.00 hari ini ', style: TextStyle(fontWeight: FontWeight.w800)),
                    TextSpan(text: 'untuk menyelamatkan pesanan ini!'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildActionButtons(OrderModel order) {
    final status = order.status ?? 'pending_payment';
    final paymentStatus = order.paymentStatus ?? 'unpaid';

    if (status == 'completed') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Bukti Pembayaran', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F943B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Beli Lagi', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
    } else if (status == 'cancelled') {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              backgroundColor: const Color(0xFFF9FBF9),
              side: BorderSide(color: Colors.grey.shade200),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Temukan Penawaran Serupa', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
          ),
        ),
      );
    } else {
      // Aktif
      final isUnpaid = status == 'pending_payment' || paymentStatus == 'unpaid';

      if (isUnpaid) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                context.push('/payment/${order.id}', extra: order);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F943B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Selesaikan Pembayaran', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        );
      }

      if (status == 'picked_up') {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                try {
                  await Supabase.instance.client.from('orders').update({'status': 'completed'}).eq('id', order.id);
                  ref.read(orderFilterProvider.notifier).setFilter('Selesai');
                  ref.read(userOrdersProvider.notifier).refresh();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal menyelesaikan: $e')));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F943B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: const Text('Selesaikan Pesanan', style: TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        );
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _openChat(context, order),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Chat Penjual', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  if (order.pickupCode != null) {
                    _showQRCodeDialog(context, order.pickupCode!);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kode pengambilan belum tersedia')),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F943B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Tunjukkan Kode QR', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildEmptyState(String filter) {
    String title = 'Belum ada pesanan';
    String subtitle = 'Kamu belum memiliki pesanan di kategori ini.';
    IconData icon = SolarIconsOutline.bill;

    if (filter == 'Selesai') {
      title = 'Belum ada barang yang terselesaikan';
      subtitle = 'Yuk, mulai selamatkan makanan dan selesaikan pesananmu!';
      icon = SolarIconsOutline.box;
    } else if (filter == 'Aktif') {
      title = 'Belum ada pesanan aktif';
      subtitle = 'Saat ini kamu tidak memiliki pesanan yang sedang diproses.';
      icon = SolarIconsOutline.clockCircle;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade500, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context, String pickupCode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.all(24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Kode Pengambilan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                'Tunjukkan QR ini ke penjual untuk mengambil makananmu.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=$pickupCode',
                  width: 200,
                  height: 200,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF0F943B)),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  pickupCode,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: Color(0xFF0F943B),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F943B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text('Tutup', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openChat(BuildContext context, OrderModel order) async {
    if (_isProcessingChat) return;
    if (order.items == null || order.items!.isEmpty) return;
    final merchant = order.items!.first.product?.merchant;
    if (merchant == null) return;

    final supabase = Supabase.instance.client;
    final myUid = supabase.auth.currentUser?.id;
    if (myUid == null) return;

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
