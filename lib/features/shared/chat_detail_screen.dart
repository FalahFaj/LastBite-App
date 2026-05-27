import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'dart:io' show Platform;
import 'package:solar_icons/solar_icons.dart';

class ChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String peerName;
  final String? peerAvatar;
  final bool isUserSide;
  final String? productName;
  final String? productPrice;
  final String? productImage;

  const ChatDetailScreen({
    super.key,
    required this.chatId,
    required this.peerName,
    this.peerAvatar,
    required this.isUserSide,
    this.productName,
    this.productPrice,
    this.productImage,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final supabase = Supabase.instance.client;
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isSending = false;
  bool _isTyping = false;
  bool _showEmoji = false;
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus && _showEmoji) {
        setState(() => _showEmoji = false);
      }
    });
    _msgCtrl.addListener(() =>
        setState(() => _isTyping = _msgCtrl.text.trim().isNotEmpty));
    _markAsRead();
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      final field = widget.isUserSide ? 'unread_buyer' : 'unread_merchant';
      await supabase.from('chats').update({field: 0}).eq('id', widget.chatId);
    } catch (_) {}
  }

  String _formatTime(String iso) {
    final dt = DateTime.parse(iso).toLocal();
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  bool _isSameDay(DateTime d1, DateTime d2) {
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Hari ini';
    } else if (messageDate == yesterday) {
      return 'Kemarin';
    } else {
      final months = [
        'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
        'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  void _scrollToBottom() {
    if (_scrollCtrl.hasClients) {
      _scrollCtrl.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() { _isSending = true; _isTyping = false; });
    _msgCtrl.clear();
    try {
      final uid = supabase.auth.currentUser!.id;
      
      // Ambil jumlah unread saat ini sebelum update
      final chatRes = await supabase.from('chats').select('unread_buyer, unread_merchant').eq('id', widget.chatId).single();
      final currentUnreadBuyer = (chatRes['unread_buyer'] as int?) ?? 0;
      final currentUnreadMerchant = (chatRes['unread_merchant'] as int?) ?? 0;

      await supabase.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': uid,
        'content': text,
      });

      await supabase.from('chats').update({
        'last_message': text,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
        if (widget.isUserSide) 'unread_merchant': currentUnreadMerchant + 1,
        if (!widget.isUserSide) 'unread_buyer': currentUnreadBuyer + 1,
      }).eq('id', widget.chatId);
      
      HapticFeedback.lightImpact();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal kirim: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showEmoji,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_showEmoji) {
          setState(() => _showEmoji = false);
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F2F0),
        appBar: _buildAppBar(),
        body: Column(children: [
          if (widget.productName != null) _buildProductCard(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: supabase
                  .from('messages')
                  .stream(primaryKey: ['id'])
                  .eq('chat_id', widget.chatId)
                  .order('created_at', ascending: false),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)));
                }
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(SolarIconsOutline.chatRound, size: 64, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    const Text('Belum ada pesan', style: TextStyle(color: Color(0xFF9CA3AF), fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    const Text('Mulai percakapan sekarang!', style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 13)),
                  ]));
                }
                
              final myUid = supabase.auth.currentUser?.id;
              final List<Widget> listItems = [];
              
              for (int i = 0; i < msgs.length; i++) {
                final msg = msgs[i];
                final currentMsgTime = DateTime.parse(msg['created_at'] as String).toLocal();
                
                listItems.add(_buildBubble(
                  text: msg['content'] as String? ?? '',
                  isMine: msg['sender_id'] == myUid,
                  time: _formatTime(msg['created_at'] as String),
                ));

                if (i == msgs.length - 1) {
                  listItems.add(_buildDateHeader(_formatDateHeader(currentMsgTime)));
                } else {
                  final nextMsgTime = DateTime.parse(msgs[i + 1]['created_at'] as String).toLocal();
                  if (!_isSameDay(currentMsgTime, nextMsgTime)) {
                    listItems.add(_buildDateHeader(_formatDateHeader(currentMsgTime)));
                  }
                }
              }

              return ListView.builder(
                reverse: true,
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                itemCount: listItems.length,
                itemBuilder: (context, i) {
                  return listItems[i];
                },
              );
              },
            ),
          ),
          _buildInputBar(),
          if (_showEmoji) _buildEmojiPicker(),
        ]),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0.5,
      leading: GestureDetector(
        onTap: () => context.pop(),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(SolarIconsOutline.altArrowLeft, size: 20, color: Color(0xFF374151)),
        ),
      ),
      title: Row(children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: widget.peerAvatar != null && widget.peerAvatar!.isNotEmpty
              ? NetworkImage(widget.peerAvatar!) : null,
          child: widget.peerAvatar == null || widget.peerAvatar!.isEmpty
              ? Text(widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
                  style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF374151)))
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(widget.peerName,
              style: const TextStyle(fontFamily: 'DMSans', fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
              overflow: TextOverflow.ellipsis),
        ),
      ]),
      actions: [
        IconButton(icon: const Icon(SolarIconsOutline.phone, color: Color(0xFF374151), size: 22), onPressed: () {}),
        IconButton(icon: const Icon(SolarIconsOutline.menuDots, color: Color(0xFF374151), size: 22), onPressed: () {}),
      ],
    );
  }

  Widget _buildProductCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9E7), // matches screenshot
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: widget.productImage != null
              ? Image.network(widget.productImage!, width: 48, height: 48, fit: BoxFit.cover,
                  errorBuilder: (a, b, c) => _imgPlaceholder())
              : _imgPlaceholder(),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.productName!,
              style: const TextStyle(fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(widget.productPrice ?? '',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF16A34A))),
        ])),
        // Lihat Produk Button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: const Column(
            children: [
              Text('Lihat', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
              Text('Produk', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _imgPlaceholder() => Container(
    width: 48, height: 48,
    decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
    child: const Icon(SolarIconsOutline.hamburgerMenu, color: Colors.grey),
  );

  Widget _buildDateHeader(String label) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), fontWeight: FontWeight.w500)),
      ),
    );
  }

  Widget _buildBubble({required String text, required bool isMine, required String time}) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFF16A34A) : const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isMine ? Colors.white : const Color(0xFF2D4A2D),
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 4),
              child: Text(
                time,
                style: TextStyle(
                  fontSize: 10,
                  color: isMine ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF2D4A2D).withValues(alpha: 0.6),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 16, top: 10, bottom: MediaQuery.of(context).padding.bottom + 10),
      decoration: const BoxDecoration(
        color: Color(0xFFF0F2F0),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        // Input Field
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFFEF9E7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    setState(() => _showEmoji = !_showEmoji);
                  },
                  child: Icon(
                    _showEmoji ? SolarIconsOutline.keyboard : SolarIconsOutline.smileCircle, 
                    color: const Color(0xFF16A34A), 
                    size: 24
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    focusNode: _focusNode,
                    maxLines: 4, minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(fontSize: 14, color: Color(0xFF111827)),
                    decoration: const InputDecoration(
                      hintText: 'Ketik pesan..',
                      hintStyle: TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                      border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Send Button
        GestureDetector(
          onTap: _isSending ? null : () {
            if (_isTyping) {
              _sendMessage();
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Fitur voice note akan segera hadir'),
                  behavior: SnackBarBehavior.floating,
                ));
              }
            }
          },
          child: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF16A34A),
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: const Color(0xFF16A34A).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))],
            ),
            child: _isSending
                ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Icon(_isTyping ? SolarIconsOutline.plain : SolarIconsOutline.microphone, color: Colors.white, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmojiPicker() {
    return SizedBox(
      height: 250,
      child: EmojiPicker(
        onEmojiSelected: (category, emoji) {
          // Handled by controller usually, but we can add manual logic if needed
        },
        onBackspacePressed: () {
          // Handled by controller usually
        },
        textEditingController: _msgCtrl,
        config: Config(
          height: 256,
          checkPlatformCompatibility: true,
          viewOrderConfig: const ViewOrderConfig(),
          emojiViewConfig: EmojiViewConfig(
            emojiSizeMax: 28 * (Platform.isIOS ? 1.2 : 1.0),
          ),
          skinToneConfig: const SkinToneConfig(),
          categoryViewConfig: const CategoryViewConfig(),
          bottomActionBarConfig: const BottomActionBarConfig(
            buttonColor: Colors.transparent,
            buttonIconColor: Colors.grey,
            backgroundColor: Colors.transparent,
          ),
          searchViewConfig: const SearchViewConfig(),
        ),
      ),
    );
  }
}
