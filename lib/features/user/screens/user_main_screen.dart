import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UserMainScreen extends StatefulWidget {
  final StatefulNavigationShell navigationShell;

  const UserMainScreen({super.key, required this.navigationShell});

  @override
  State<UserMainScreen> createState() => _UserMainScreenState();
}

class _UserMainScreenState extends State<UserMainScreen> {
  final _supabase = Supabase.instance.client;
  int _unreadCount = 0;
  int _pendingOrderCount = 0;
  RealtimeChannel? _chatChannel;
  RealtimeChannel? _orderChannel;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _fetchCounts();
    _subscribeToData();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchCounts());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chatChannel?.unsubscribe();
    _orderChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _fetchCounts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    try {
      final resChats = await _supabase
          .from('chats')
          .select('unread_buyer')
          .eq('buyer_id', user.id);
      
      int chatCount = 0;
      for (final row in (resChats as List)) {
        chatCount += (row['unread_buyer'] as int? ?? 0);
      }

      final resOrders = await _supabase
          .from('orders')
          .select('id')
          .eq('buyer_id', user.id)
          .eq('status', 'pending_payment');
      
      int orderCount = (resOrders as List).length;

      if (mounted) {
        setState(() {
          _unreadCount = chatCount;
          _pendingOrderCount = orderCount;
        });
      }
    } catch (_) {}
  }

  void _subscribeToData() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _chatChannel = _supabase
        .channel('user-main-chats')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'buyer_id',
            value: user.id,
          ),
          callback: (payload) {
            _fetchCounts();
          },
        )
        .subscribe();

    _orderChannel = _supabase
        .channel('user-main-orders')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'orders',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'buyer_id',
            value: user.id,
          ),
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
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: SolarIconsOutline.home2,
                activeIcon: SolarIconsBold.home2,
                label: 'Beranda',
                index: 0,
                context: context,
              ),
              _buildNavItem(
                icon: SolarIconsOutline.box,
                activeIcon: SolarIconsBold.box,
                label: 'Pesanan',
                index: 1,
                context: context,
                badgeCount: widget.navigationShell.currentIndex == 1 ? 0 : _pendingOrderCount,
              ),
              _buildNavItem(
                icon: SolarIconsOutline.chatRound,
                activeIcon: SolarIconsBold.chatRound,
                label: 'Chat',
                index: 2,
                context: context,
                badgeCount: widget.navigationShell.currentIndex == 2 ? 0 : _unreadCount,
              ),
              _buildNavItem(
                icon: SolarIconsOutline.user,
                activeIcon: SolarIconsBold.user,
                label: 'Profil',
                index: 3,
                context: context,
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
    required int index,
    required BuildContext context,
    int badgeCount = 0,
  }) {
    final bool isActive = widget.navigationShell.currentIndex == index;
    final Color color = isActive ? const Color(0xFF2E7D32) : Colors.grey.shade400;

    return GestureDetector(
      onTap: () => _onTap(context, index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  isActive ? activeIcon : icon,
                  color: color,
                  size: 26,
                ),
                if (badgeCount > 0)
                  Positioned(
                    right: -6,
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
            const SizedBox(height: 4),
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
