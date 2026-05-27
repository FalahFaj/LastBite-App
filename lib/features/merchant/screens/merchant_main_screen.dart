import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MerchantMainScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const MerchantMainScreen({super.key, required this.navigationShell});

  @override
  State<MerchantMainScreen> createState() => _MerchantMainScreenState();
}

class _MerchantMainScreenState extends State<MerchantMainScreen> {
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  int _pendingOrderCount = 0;
  RealtimeChannel? _chatChannel;
  Timer? _timer;
  String? _merchantId;

  @override
  void initState() {
    super.initState();
    _initMerchantAndChats();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchCounts());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chatChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _initMerchantAndChats() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final merchantRes = await _supabase
          .from('merchants')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();
      if (merchantRes != null) {
        _merchantId = merchantRes['id'] as String;
        await _fetchCounts();
        _subscribeToData();
      }
    } catch (_) {}
  }

  Future<void> _fetchCounts() async {
    if (_merchantId == null) return;
    try {
      // Fetch unread chats
      final resChats = await _supabase
          .from('chats')
          .select('unread_merchant')
          .eq('merchant_id', _merchantId!);
      
      int chatCount = 0;
      for (final row in (resChats as List)) {
        chatCount += (row['unread_merchant'] as int? ?? 0);
      }

      // Fetch pending orders
      final resOrders = await _supabase
          .from('orders')
          .select('id, status, payment_status, order_items!inner(products!inner(merchant_id))')
          .eq('order_items.products.merchant_id', _merchantId!)
          .inFilter('status', ['pending_payment', 'paid']);
          
      int orderCount = 0;
      for (final row in (resOrders as List)) {
         final s = row['status'];
         final p = row['payment_status'];
         if (s == 'pending_payment' || (s == 'paid' && p == 'waiting_verification')) {
            orderCount++;
         }
      }

      if (mounted) {
        setState(() {
          _unreadCount = chatCount;
          _pendingOrderCount = orderCount;
        });
      }
    } catch (_) {}
  }

  void _subscribeToData() {
    if (_merchantId == null) return;

    _chatChannel = _supabase
        .channel('merchant-main-data')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'merchant_id',
            value: _merchantId!,
          ),
          callback: (payload) {
            _fetchCounts();
          },
        )
        // Also listen to orders changes for realtime order badge updates
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          callback: (payload) {
            _fetchCounts();
          },
        )
        .subscribe();
  }

  void _onTap(BuildContext context, int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
    _fetchCounts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: _buildFloatingBottomNavigationBar(context),
      extendBody: true,
    );
  }

  Widget _buildFloatingBottomNavigationBar(BuildContext context) {
    const Color activeColor = Color(0xFF16A34A);
    final Color inactiveColor = Colors.grey.shade400;

    return Container(
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: SolarIconsOutline.home2,
                activeIcon: SolarIconsBold.home2,
                label: 'Home',
                branchIndex: 0,
                context: context,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
              _buildNavItem(
                icon: SolarIconsOutline.bill,
                activeIcon: SolarIconsOutline.bill,
                label: 'Pesanan',
                branchIndex: 1,
                context: context,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                badgeCount: widget.navigationShell.currentIndex == 1 ? 0 : _pendingOrderCount,
              ),
              GestureDetector(
                onTap: () {
                  context.push('/merchant/add-product');
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeColor.withValues(alpha: 0.4),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(SolarIconsOutline.addCircle, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Jual Produk',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: activeColor,
                      ),
                    ),
                  ],
                ),
              ),
              _buildNavItem(
                icon: SolarIconsOutline.chatRound,
                activeIcon: SolarIconsBold.chatRound,
                label: 'Chats',
                branchIndex: 2,
                context: context,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
                badgeCount: widget.navigationShell.currentIndex == 2 ? 0 : _unreadCount,
              ),
              _buildNavItem(
                icon: SolarIconsOutline.shop,
                activeIcon: SolarIconsBold.shop,
                label: 'Toko',
                branchIndex: 3,
                context: context,
                activeColor: activeColor,
                inactiveColor: inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required int branchIndex,
    required BuildContext context,
    required Color activeColor,
    required Color inactiveColor,
    int badgeCount = 0,
  }) {
    final bool isActive = widget.navigationShell.currentIndex == branchIndex;
    final Color color = isActive ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: () => _onTap(context, branchIndex),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 54,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: color,
                  size: 24,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4B4B),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          badgeCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
