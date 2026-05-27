import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solar_icons/solar_icons.dart';

class UserChatScreen extends StatefulWidget {
  const UserChatScreen({super.key});

  @override
  State<UserChatScreen> createState() => _UserChatScreenState();
}

class _UserChatScreenState extends State<UserChatScreen> {
  final supabase = Supabase.instance.client;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadChats();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadChats() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final data = await supabase
          .from('chats')
          .select('*, merchants(id, store_name, avatar_url)')
          .eq('buyer_id', uid)
          .order('updated_at', ascending: false);
      if (mounted) setState(() { _chats = List<Map<String, dynamic>>.from(data as List); _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _subscribeRealtime() {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    _channel = supabase.channel('user-chats-$uid')
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: const Row(children: [
        Text('Pesan', style: TextStyle(fontFamily: 'DMSans', fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
      ]),
    );
  }

  Widget _buildSearch() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 20),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                    decoration: const InputDecoration(
                      hintText: 'Cari pesan...',
                      hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Color(0xFF16A34A),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(SolarIconsOutline.magnifier, color: Colors.white, size: 20),
                    onPressed: () {},
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Filter Chips
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Semua', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Belum dibaca', style: TextStyle(color: Color(0xFF374151), fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    final chats = _searchQuery.isEmpty
        ? _chats
        : _chats.where((c) {
            final merchant = c['merchants'] as Map? ?? {};
            final name = (merchant['store_name'] as String? ?? '').toLowerCase();
            final msg = (c['last_message'] as String? ?? '').toLowerCase();
            return name.contains(_searchQuery) || msg.contains(_searchQuery);
          }).toList();

    if (chats.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(SolarIconsOutline.chatRound, size: 64, color: Colors.grey.shade300),
        const SizedBox(height: 12),
        const Text('Belum ada percakapan', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF6B7280))),
        const SizedBox(height: 6),
        const Text('Mulai chat dari halaman produk', style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
      ]));
    }

    return RefreshIndicator(
      color: const Color(0xFF16A34A),
      onRefresh: _loadChats,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 120),
        itemCount: chats.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 84, color: Color(0xFFF3F4F6)),
        itemBuilder: (_, i) => _buildItem(chats[i]),
      ),
    );
  }

  Widget _buildItem(Map<String, dynamic> chat) {
    final merchant = chat['merchants'] as Map<String, dynamic>? ?? {};
    final storeName = merchant['store_name'] as String? ?? 'Toko';
    final avatarUrl = merchant['avatar_url'] as String?;
    final lastMsg = chat['last_message'] as String? ?? 'Mulai percakapan...';
    final unread = (chat['unread_buyer'] as int?) ?? 0;
    final updatedAt = chat['updated_at'] as String?;

    return InkWell(
      onTap: () => context.push('/chat-detail', extra: {
        'chatId': chat['id'] as String,
        'peerName': storeName,
        'peerAvatar': avatarUrl ?? '',
        'isUserSide': true,
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey.shade200,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? Text(storeName[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF374151)))
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(storeName, style: TextStyle(fontSize: 15, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600, color: const Color(0xFF111827))),
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
