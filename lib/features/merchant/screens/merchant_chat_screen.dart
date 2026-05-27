import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:solar_icons/solar_icons.dart';

class MerchantChatScreen extends StatefulWidget {
  const MerchantChatScreen({super.key});

  @override
  State<MerchantChatScreen> createState() => _MerchantChatScreenState();
}

class _MerchantChatScreenState extends State<MerchantChatScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  String? _merchantId;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _init() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final res = await supabase.from('merchants').select('id').eq('user_id', uid).single();
      _merchantId = res['id'] as String;
      await _loadChats();
      _subscribeRealtime();
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadChats() async {
    if (_merchantId == null) return;
    try {
      final data = await supabase
          .from('chats')
          .select('*, users(name, user_picture_url)')
          .eq('merchant_id', _merchantId!)
          .order('updated_at', ascending: false);
      if (mounted) setState(() { _chats = List<Map<String, dynamic>>.from(data as List); _isLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    if (_merchantId == null) return;
    _channel = supabase.channel('merchant-chats-$_merchantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chats',
          callback: (_) => _loadChats(),
        )
        .subscribe();
  }

  String _formatTime(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.parse(iso).toLocal();
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}/${dt.month}';
  }

  String _buyerLabel(Map<String, dynamic> chat) {
    final users = chat['users'] as Map?;
    final name = users?['name'] as String?;
    if (name != null && name.isNotEmpty) return name;
    final id = chat['buyer_id'] as String? ?? '';
    return 'Pembeli ${id.length > 6 ? id.substring(0, 6) : id}';
  }

  String? _buyerAvatar(Map<String, dynamic> chat) {
    final users = chat['users'] as Map?;
    return users?['user_picture_url'] as String?;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      extendBody: true,

      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          _buildSearch(),
          Expanded(child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
              : _buildList()),
        ]),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 16, 20, 16),
      child: Row(children: [
        // GestureDetector(
        //   onTap: () => context.go('/merchant/dashboard'),
        //   child: Container(
        //     width: 40, height: 40,
        //     decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(12)),
        //     child: const Icon(SolarIconsOutline.altArrowLeft, size: 18, color: Color(0xFF374151)),
        //   ),
        // ),
        const SizedBox(width: 16),
        const Text('Pesan Masuk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      ]),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Container(
        height: 44,
        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(22)),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
          decoration: const InputDecoration(
            hintText: 'Cari percakapan...',
            hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
            prefixIcon: Icon(SolarIconsOutline.magnifier, color: Color(0xFF9CA3AF), size: 20),
            border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final chats = _searchQuery.isEmpty
        ? _chats
        : _chats.where((c) {
            final name = _buyerLabel(c).toLowerCase();
            final msg = (c['last_message'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery) || msg.contains(_searchQuery);
          }).toList();

    if (chats.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(SolarIconsOutline.chatRound, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Belum ada pesan masuk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        const Text('Pembeli akan menghubungi kamu di sini', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      ]));
    }

    return RefreshIndicator(
      color: const Color(0xFF16A34A),
      onRefresh: _loadChats,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
        itemCount: chats.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 84, color: Color(0xFFF3F4F6)),
        itemBuilder: (_, i) => _buildItem(chats[i]),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> chat) {
    final buyerName = _buyerLabel(chat);
    final avatarUrl = _buyerAvatar(chat);
    final lastMsg = chat['last_message'] as String? ?? 'Mulai percakapan...';
    final unread = (chat['unread_merchant'] as int?) ?? 0;
    final updatedAt = chat['updated_at'] as String?;
    final buyerId = chat['buyer_id'] as String? ?? '';
    // Generate color from buyer_id for avatar placeholder
    final colors = [const Color(0xFF6366F1), const Color(0xFFEC4899), const Color(0xFFF59E0B), const Color(0xFF10B981), const Color(0xFF3B82F6)];
    final color = colors[buyerId.hashCode.abs() % colors.length];

    return InkWell(
      onTap: () => context.push('/chat-detail', extra: {
        'chatId': chat['id'] as String,
        'peerName': buyerName,
        'peerAvatar': avatarUrl ?? '',
        'isUserSide': false,
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withValues(alpha: 0.15),
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(buyerName[0].toUpperCase(), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(buyerName, style: TextStyle(fontSize: 15, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFF111827))),
                  const SizedBox(height: 4),
                  Text(lastMsg, style: TextStyle(fontSize: 13, color: unread > 0 ? const Color(0xFF374151) : const Color(0xFF9CA3AF), fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(_formatTime(updatedAt), style: TextStyle(fontSize: 11, color: unread > 0 ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF), fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400)),
                if (unread > 0) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFF16A34A), borderRadius: BorderRadius.circular(10)),
                    child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
