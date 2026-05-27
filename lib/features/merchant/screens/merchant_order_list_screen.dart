import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:solar_icons/solar_icons.dart';
import 'package:lastbite/core/models/order_model.dart';
import 'scan_qr_screen.dart';

class MerchantOrderListScreen extends StatefulWidget {
  const MerchantOrderListScreen({super.key});

  @override
  State<MerchantOrderListScreen> createState() => _MerchantOrderListScreenState();
}

class _MerchantOrderListScreenState extends State<MerchantOrderListScreen> {
  int _selectedTabIndex = 0;
  final supabase = Supabase.instance.client;
  String? _merchantId;
  bool _showBanner = true;

  List<Map<String, dynamic>> _allOrders = [];
  bool _isLoading = true;
  bool _isProcessingChat = false;
  RealtimeChannel? _subscription;

  @override
  void initState() {
    super.initState();
    _fetchMerchantId();
  }

  Future<void> _fetchMerchantId() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final res = await supabase
          .from('merchants')
          .select('id')
          .eq('user_id', user.id)
          .single();
      if (mounted) {
        setState(() => _merchantId = res['id']);
        _fetchOrders();
        _setupSubscription();
      }
    } catch (_) {}
  }

  void _setupSubscription() {
    _subscription = supabase.channel('public:orders:merchant_${_merchantId}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        callback: (payload) {
          if (mounted) {
            _fetchOrders();
          }
        },
      )
      .subscribe();
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchOrders() async {
    if (_merchantId == null) return;
    try {
      final data = await supabase
          .from('orders')
          .select('''
            id, status, payment_status, total_price, pickup_code, delivery_method, picked_up_at, created_at, buyer_id,
            users(*),
            order_items!inner(
              id, quantity, price,
              products!inner(id, name, image, merchant_id)
            ),
            payments(id, method, payment_proof, status)
          ''')
          .eq('order_items.products.merchant_id', _merchantId!)
          .order('created_at', ascending: false);

      final now = DateTime.now();
      final List<Map<String, dynamic>> processedOrders = [];

      for (var orderRaw in data as List) {
        final order = Map<String, dynamic>.from(orderRaw);
        
        // Auto-cancel logic if payment is expired (> 60 minutes)
        if (order['status'] == 'pending_payment' && order['created_at'] != null) {
          try {
            final createdAt = DateTime.parse(
              order['created_at'].endsWith('Z') || order['created_at'].contains('+')
                  ? order['created_at']
                  : '${order['created_at']}Z'
            ).toLocal();
            
            final expiryTime = createdAt.add(const Duration(minutes: 60));
            if (now.isAfter(expiryTime)) {
              order['status'] = 'cancelled';
              supabase.from('orders')
                  .update({'status': 'cancelled'})
                  .eq('id', order['id'])
                  .eq('status', 'pending_payment')
                  .then((_) => null);
            }
          } catch (_) {}
        }
        
        // Auto-complete logic if picked_up is > 2 hours
        if (order['status'] == 'picked_up' && order['picked_up_at'] != null) {
          try {
            final pickedUpAt = DateTime.parse(
              order['picked_up_at'].endsWith('Z') || order['picked_up_at'].contains('+')
                  ? order['picked_up_at']
                  : '${order['picked_up_at']}Z'
            ).toLocal();
            
            final completeTime = pickedUpAt.add(const Duration(hours: 2));
            if (now.isAfter(completeTime)) {
              order['status'] = 'completed';
              supabase.from('orders')
                  .update({'status': 'completed'})
                  .eq('id', order['id'])
                  .eq('status', 'picked_up')
                  .then((_) => null);
            }
          } catch (_) {}
        }

        processedOrders.add(order);
      }

      if (mounted) {
        setState(() {
          _allOrders = List<Map<String, dynamic>>.from(processedOrders);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching orders: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 10)),
        );
      }
    }
  }

  bool _isBelumKonfirmasi(Map<String, dynamic> o) {
    final s = o['status'];
    final p = o['payment_status'];
    return s == 'pending_payment' || (s == 'paid' && p == 'waiting_verification');
  }

  bool _isDiproses(Map<String, dynamic> o) {
    final s = o['status'];
    final p = o['payment_status'];
    return (s == 'paid' && p != 'waiting_verification') || s == 'ready_for_pickup';
  }

  bool _isSelesai(Map<String, dynamic> o) {
    final s = o['status'];
    return s == 'completed' || s == 'cancelled' || s == 'picked_up';
  }

  List<Map<String, dynamic>> get _currentTabOrders {
    if (_selectedTabIndex == 0) return _allOrders.where(_isBelumKonfirmasi).toList();
    if (_selectedTabIndex == 1) return _allOrders.where(_isDiproses).toList();
    return _allOrders.where(_isSelesai).toList();
  }

  int get _newOrdersCount => _allOrders.where(_isBelumKonfirmasi).length;

  Future<void> _updateOrderStatus(String orderId, String newStatus) async {
    try {
      await supabase.from('orders').update({'status': newStatus}).eq('id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_statusLabel(newStatus)),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _verifyPayment(String orderId) async {
    try {
      await supabase.from('orders').update({
        'status': 'paid',
        'payment_status': 'verified',
      }).eq('id', orderId);
      await supabase.from('payments').update({'status': 'verified'}).eq('order_id', orderId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pembayaran berhasil diverifikasi!'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchOrders();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal verifikasi: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'Sedang dalam proses';
      case 'ready_for_pickup': return 'Pesanan siap diambil!';
      case 'picked_up': return 'Barang diserahkan';
      case 'completed': return 'Pesanan selesai!';
      case 'cancelled': return 'Pesanan ditolak.';
      default: return 'Status diperbarui';
    }
  }

  Future<void> _startQRScan(String orderId, String expectedCode) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScanQrScreen(expectedCode: expectedCode),
      ),
    );

    if (result == true && mounted) {
      try {
        await supabase.rpc('verify_pickup_code', params: {
          'p_order_id': orderId,
          'p_pickup_code': expectedCode,
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pesanan berhasil diserahkan!'), backgroundColor: Color(0xFF16A34A)),
          );
          _fetchOrders();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  void _showPaymentProof(String? proofUrl) {
    if (proofUrl == null || proofUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bukti pembayaran tidak ditemukan')),
      );
      return;
    }

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

  Future<void> _openChat(BuildContext context, Map<String, dynamic> order) async {
    if (_isProcessingChat || _merchantId == null) return;
    
    final buyerId = order['buyer_id'] as String?;
    if (buyerId == null) return;
    
    final buyer = order['users'];
    if (buyer == null) return;

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
          .eq('buyer_id', buyerId)
          .eq('merchant_id', _merchantId!)
          .maybeSingle();

      String chatId;
      if (existingChat != null) {
        chatId = existingChat['id'] as String;
      } else {
        final newChat = await supabase
            .from('chats')
            .insert({
              'buyer_id': buyerId,
              'merchant_id': _merchantId!,
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
          'peerName': buyer['name'] ?? 'Pembeli',
          'peerAvatar': buyer['avatar_url'] ?? '',
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

  void _confirmAction(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Ya, Lanjutkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? createdAt) {
    if (createdAt == null) return '-';
    try {
      final dt = DateTime.parse(createdAt).toLocal();
      final now = DateTime.now();
      final diff = now.difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} menit';
      if (diff.inHours < 24) return '${diff.inHours} jam';
      if (diff.inDays == 1) return 'kemarin';
      return DateFormat('d MMM', 'id').format(dt);
    } catch (_) {
      return '-';
    }
  }

  String _formatRp(dynamic value) {
    if (value == null) return 'Rp 0';
    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format((value as num).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      extendBody: true,

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            // GestureDetector(
            //   onTap: () => context.pop(),
            //   child: Container(
            //     padding: const EdgeInsets.all(8),
            //     decoration: BoxDecoration(
            //       border: Border.all(color: Colors.grey.shade200),
            //       borderRadius: BorderRadius.circular(12),
            //     ),
            //     child: const Icon(SolarIconsOutline.altArrowLeft, color: Colors.black, size: 20),
            //   ),
            // ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Manajemen Pesanan',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 18)),
                Text('Ayo selamatkan bumi lagi hari ini! 🌱',
                    style: TextStyle(color: Color(0xFF6B7280), fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
          : RefreshIndicator(
              color: const Color(0xFF16A34A),
              onRefresh: _fetchOrders,
              child: CustomScrollView(
                slivers: [
                  if (_showBanner && _newOrdersCount > 0)
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.only(left: 16, right: 16, top: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A34A),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(SolarIconsOutline.bellBing, color: Colors.white, size: 22),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Yeayy!! Kamu punya $_newOrdersCount pesanan baru, ayo konfirmasi secepatnya.',
                                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                            ),
                            GestureDetector(
                              onTap: () => setState(() => _showBanner = false),
                              child: const Icon(SolarIconsOutline.closeSquare, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: Container(
                      margin: EdgeInsets.only(top: (_showBanner && _newOrdersCount > 0) ? 16 : 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      color: Colors.white,
                      child: Row(
                        children: [
                          _buildTab('Belum Konfirmasi', 0, badgeCount: _newOrdersCount),
                          _buildTab('Diproses', 1),
                          _buildTab('Selesai', 2),
                        ],
                      ),
                    ),
                  ),
                  _currentTabOrders.isEmpty
                      ? SliverFillRemaining(child: _buildEmptyState())
                      : SliverPadding(
                          padding: const EdgeInsets.all(16),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                if (index == _currentTabOrders.length) {
                                  return const _FooterWidget();
                                }
                                return _buildOrderCard(_currentTabOrders[index]);
                              },
                              childCount: _currentTabOrders.length + 1,
                            ),
                          ),
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildTab(String label, int index, {int badgeCount = 0}) {
    final isActive = _selectedTabIndex == index;
    final displayLabel = label.length > 12 ? '${label.substring(0, 12)}...' : label;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTabIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    displayLabel,
                    style: TextStyle(
                      color: isActive ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
                      fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  if (badgeCount > 0) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B4B),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ]
                ],
              ),
            ),
            Container(height: 3, color: isActive ? const Color(0xFF16A34A) : Colors.transparent),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(color: Color(0xFFF0FDF4), shape: BoxShape.circle),
            child: const Icon(SolarIconsOutline.bill, size: 48, color: Color(0xFF16A34A)),
          ),
          const SizedBox(height: 16),
          const Text('Belum ada pesanan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF374151))),
          const SizedBox(height: 8),
          const Text('Pesanan baru akan muncul di sini', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderId = '#${(order['id'] as String).substring(0, 8).toUpperCase()}';
    final status = order['status'] as String? ?? '';
    final paymentStatus = order['payment_status'] as String? ?? '';
    final totalPrice = order['total_price'];
    final createdAt = order['created_at'] as String?;
    final pickupCode = order['pickup_code'] as String?;
    
    // Parse relations safely
    final rawUsers = order['users'];
    final buyer = (rawUsers is List && rawUsers.isNotEmpty) ? rawUsers.first : (rawUsers is Map ? rawUsers : null);
    
    final rawItems = order['order_items'];
    final items = (rawItems is List) ? rawItems : (rawItems is Map ? [rawItems] : []);
    
    final rawPayments = order['payments'];
    final payments = (rawPayments is List) ? rawPayments : (rawPayments is Map ? [rawPayments] : []);
    final payment = payments.isNotEmpty ? payments.first as Map<String, dynamic> : null;

    final buyerName = buyer?['name'] as String? ?? 'Pelanggan';
    final buyerAvatar = buyer?['user_picture_url'] as String?;
    final buyerLocation = '2.4 km • Jember'; // Dummy location

    // Get first item
    final firstItem = items.isNotEmpty ? items.first as Map<String, dynamic> : null;
    final product = firstItem?['products'] as Map<String, dynamic>?;
    final productName = product?['name'] as String? ?? 'Produk';
    final productImage = product?['image'] as String?;
    final itemQty = firstItem?['quantity'] as int? ?? 1;
    final itemPrice = firstItem?['price'];

    final extraItems = items.length > 1 ? '+${items.length - 1} lainnya' : null;

    // Determine status display
    _StatusConfig cfg = _getStatusConfig(status, paymentStatus);

    return GestureDetector(
      onTap: () async {
        try {
          final parsedOrder = OrderModel.fromJson(order);
          await context.push('/merchant/order-detail/${parsedOrder.id}', extra: parsedOrder);
          _fetchOrders();
        } catch (e) {
          debugPrint('Error parsing order for detail screen: $e');
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
          ],
        ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: cfg.bgColor, borderRadius: BorderRadius.circular(20)),
                  child: Text(cfg.label, style: TextStyle(color: cfg.textColor, fontSize: 10, fontWeight: FontWeight.w800)),
                ),
                Row(
                  children: [
                    Text(orderId, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF111827))),
                    const SizedBox(width: 12),
                    Text(_formatTime(createdAt), style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _DashedDivider(),
            const SizedBox(height: 16),
            
            // Notice
            if (cfg.noticeText != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(cfg.noticeIcon, color: cfg.noticeColor, size: 16),
                    const SizedBox(width: 8),
                    Text(cfg.noticeText!, style: TextStyle(color: cfg.noticeColor, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              
            // Buyer Info
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: buyerAvatar != null && buyerAvatar.isNotEmpty ? NetworkImage(buyerAvatar) : null,
                  child: buyerAvatar == null || buyerAvatar.isEmpty
                      ? Text(buyerName.isNotEmpty ? buyerName[0].toUpperCase() : 'U',
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151)))
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(buyerName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF111827))),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          payment?['method'] != null ? SolarIconsOutline.wallet : SolarIconsOutline.mapPoint, 
                          size: 12, color: const Color(0xFF9CA3AF)
                        ),
                        const SizedBox(width: 4),
                        Text(
                          payment?['method'] != null ? 'Bank Transfer (${payment!['method']})' : buyerLocation,
                          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Product Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFEFCE8), borderRadius: BorderRadius.circular(12)),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: productImage != null && productImage.isNotEmpty
                        ? Image.network(productImage, width: 48, height: 48, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imagePlaceholder())
                        : _imagePlaceholder(),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(productName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF111827))),
                        const SizedBox(height: 4),
                        Text(
                          '${itemQty}x • ${_formatRp(itemPrice)}${extraItems != null ? ' · $extraItems' : ''}',
                          style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            if (pickupCode != null && pickupCode.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFBBF7D0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Kode Pengambilan:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                    ),
                    Text(
                      pickupCode,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF16A34A),
                        letterSpacing: 2.0,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Total Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  paymentStatus == 'waiting_verification' || paymentStatus == 'verified' 
                    ? 'Total Pembayaran' : 'Total Pendapatan', 
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12, fontWeight: FontWeight.w500)
                ),
                Text(_formatRp(totalPrice), style: const TextStyle(color: Color(0xFF16A34A), fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            _buildActionButtons(order, status, paymentStatus, payment),
          ],
        ),
      ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(
    width: 48, height: 48, color: Colors.grey[300],
    child: const Icon(SolarIconsOutline.hamburgerMenu, color: Colors.grey, size: 24),
  );

  Widget _buildActionButtons(Map<String, dynamic> order, String status, String paymentStatus, Map<String, dynamic>? payment) {
    final orderId = order['id'] as String;
    String leftLabel, rightLabel;
    Color rightColor, rightTextColor;
    VoidCallback leftAction, rightAction;
    IconData? rightIcon;

    if (status == 'pending_payment') {
      leftLabel = 'Tolak Pesanan';
      rightLabel = 'Konfirmasi';
      rightColor = const Color(0xFF16A34A);
      rightTextColor = Colors.white;
      rightIcon = SolarIconsOutline.checkCircle;
      leftAction = () => _confirmAction(
        'Tolak Pesanan', 'Apakah kamu yakin ingin menolak pesanan ini?',
        () => _updateOrderStatus(orderId, 'cancelled'),
      );
      rightAction = () => _confirmAction(
        'Konfirmasi Pesanan', 'Konfirmasi pesanan ini sekarang?',
        () => _updateOrderStatus(orderId, 'paid'),
      );
    } else if (status == 'paid' && paymentStatus == 'waiting_verification') {
      leftLabel = 'Lihat Bukti';
      rightLabel = 'Verifikasi';
      rightColor = const Color(0xFFFBBF24);
      rightTextColor = Colors.black87;
      rightIcon = SolarIconsOutline.checkCircle;
      leftAction = () => _showPaymentProof(payment?['payment_proof'] as String?);
      rightAction = () => _confirmAction(
        'Verifikasi Pembayaran', 'Verifikasi pembayaran dan lanjutkan pesanan?',
        () => _verifyPayment(orderId),
      );
    } else if (status == 'paid') {
      leftLabel = 'Chat Pembeli';
      rightLabel = order['delivery_method'] == 'delivery' ? 'Siap Diantar' : 'Siap Diambil';
      rightColor = const Color(0xFFF59E0B);
      rightTextColor = Colors.white;
      rightIcon = SolarIconsOutline.routing;
      leftAction = () => _openChat(context, order);
      rightAction = () => _confirmAction(
        'Pesanan Siap', 'Tandai pesanan ini siap untuk ${order['delivery_method'] == 'delivery' ? 'diantar' : 'diambil'}?',
        () => _updateOrderStatus(orderId, 'ready_for_pickup'),
      );
    } else if (status == 'ready_for_pickup') {
      leftLabel = 'Chat Pembeli';
      rightLabel = 'Verifikasi Kode';
      rightColor = const Color(0xFF16A34A);
      rightTextColor = Colors.white;
      rightIcon = SolarIconsOutline.scanner;
      leftAction = () => _openChat(context, order);
      rightAction = () {
        if (order['pickup_code'] != null) {
          _startQRScan(orderId, order['pickup_code']);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Kode pengambilan tidak tersedia')),
          );
        }
      };
    } else if (status == 'picked_up') {
      leftLabel = 'Lihat Detail';
      rightLabel = 'Barang Diterima';
      rightColor = const Color(0xFFF3F4F6);
      rightTextColor = const Color(0xFF374151);
      leftAction = () {};
      rightAction = () {};
    } else {
      leftLabel = 'Lihat Detail';
      rightLabel = status == 'completed' ? 'Selesai ✓' : 'Ditolak';
      rightColor = const Color(0xFFF3F4F6);
      rightTextColor = const Color(0xFF374151);
      leftAction = () {};
      rightAction = () {};
    }

    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: leftAction,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Center(
                child: Text(leftLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF374151))),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: rightAction,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: rightColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: rightColor == Colors.white ? Colors.grey.shade200 : rightColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (rightIcon != null) ...[
                    Icon(rightIcon, color: rightTextColor, size: 16),
                    const SizedBox(width: 6),
                  ],
                  Text(rightLabel, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: rightTextColor)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusConfig {
  final String label;
  final Color bgColor;
  final Color textColor;
  final IconData? noticeIcon;
  final String? noticeText;
  final Color? noticeColor;

  _StatusConfig(this.label, this.bgColor, this.textColor, {this.noticeIcon, this.noticeText, this.noticeColor});
}

_StatusConfig _getStatusConfig(String status, String paymentStatus) {
  if (status == 'pending_payment') {
    return _StatusConfig(
      'PESANAN BARU', const Color(0xFFFF6B6B), Colors.white,
      noticeIcon: SolarIconsOutline.leaf, noticeText: 'Pelanggan siap menyelamatkan produkmu!', noticeColor: const Color(0xFF16A34A)
    );
  }
  if (status == 'paid' && paymentStatus == 'waiting_verification') {
    return _StatusConfig(
      'VERIFIKASI PEMBAYARAN', const Color(0xFFFBBF24), Colors.black87,
      noticeIcon: SolarIconsOutline.bill, noticeText: 'Pembeli mengirim bukti pembayaran', noticeColor: const Color(0xFF374151)
    );
  }
  if (status == 'ready_for_pickup') {
    return _StatusConfig(
      'SIAP DIAMBIL', const Color(0xFFFCD34D), Colors.black87,
      noticeIcon: SolarIconsOutline.box, noticeText: 'Menunggu pembeli mengambil pesanan', noticeColor: const Color(0xFF374151)
    );
  }
  if (status == 'paid') {
    return _StatusConfig(
      'DIPROSES', const Color(0xFF60A5FA), Colors.white,
      noticeIcon: SolarIconsOutline.hourglass, noticeText: 'Siapkan pesanan untuk pembeli', noticeColor: const Color(0xFF2563EB)
    );
  }
  if (status == 'completed') {
    return _StatusConfig('SELESAI', const Color(0xFF10B981), Colors.white);
  }
  return _StatusConfig('DIBATALKAN', const Color(0xFF9CA3AF), Colors.white);
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider();
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 5.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          direction: Axis.horizontal,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashWidth, height: dashHeight,
              child: const DecoratedBox(decoration: BoxDecoration(color: Color(0xFFE5E7EB))),
            );
          }),
        );
      },
    );
  }
}

class _FooterWidget extends StatelessWidget {
  const _FooterWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 120),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFCF2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Column(
        children: [
          Text('Kamu membangun perubahan! 🌱',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF374151))),
          SizedBox(height: 6),
          Text('Terima kasih sudah memberi produkmu kesempatan kedua! Setiap pesanan yang kamu proses selalu berarti.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12, height: 1.5)),
        ],
      ),
    );
  }
}