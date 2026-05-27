import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/cart_item_model.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:lastbite/core/services/supabase_service.dart';
import 'package:lastbite/features/user/providers/cart_provider.dart';
import 'package:solar_icons/solar_icons.dart';

// Provider untuk fetch satu produk berdasarkan ID dari Supabase
final productDetailProvider = FutureProvider.family<ProductModel, String>((ref, id) async {
  final response = await SupabaseService().client
      .from('products')
      .select('*, merchants(*), categories(*)')
      .eq('id', id)
      .single();
  return ProductModel.fromJson(response);
});

class ProductDetailScreen extends ConsumerWidget {
  final String productId;
  final ProductModel? product; // Data cepat dari navigasi (opsional)

  const ProductDetailScreen({
    super.key,
    required this.productId,
    this.product,
  });

  String _rupiah(double? val) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val ?? 0);

  String? _discountPct(ProductModel p) {
    if (p.price == null || p.originalPrice == null || p.originalPrice! <= 0) return null;
    final pct = ((p.originalPrice! - p.price!) / p.originalPrice! * 100).round();
    return pct > 0 ? '-$pct%' : null;
  }

  double _savings(ProductModel p) => (p.originalPrice ?? 0) - (p.price ?? 0);

  String _pickupRange(ProductModel p) {
    if (p.pickupStart == null && p.pickupEnd == null) return 'Fleksibel';
    String fmt(TimeOfDay t) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    if (p.pickupStart != null && p.pickupEnd != null) {
      return '${fmt(p.pickupStart!)} – ${fmt(p.pickupEnd!)}';
    }
    if (p.pickupEnd != null) return 'Sebelum ${fmt(p.pickupEnd!)}';
    return 'Mulai ${fmt(p.pickupStart!)}';
  }

  String _timeRemaining(ProductModel p) {
    if (p.pickupEnd == null) return 'Tersedia';
    final now = TimeOfDay.now();
    final diff = (p.pickupEnd!.hour * 60 + p.pickupEnd!.minute) - (now.hour * 60 + now.minute);
    if (diff <= 0) return 'Waktu habis';
    if (diff >= 60) return '${diff ~/ 60} jam ${diff % 60} menit lagi';
    return '$diff menit lagi';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Jika data produk sudah tersedia dari navigasi, gunakan langsung
    // Jika tidak, fetch dari Supabase
    if (product != null) {
      return _buildContent(context, ref, product!);
    }

    final productAsync = ref.watch(productDetailProvider(productId));
    return productAsync.when(
      data: (p) => _buildContent(context, ref, p),
      loading: () => Scaffold(
        backgroundColor: Colors.white,
        body: const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(SolarIconsOutline.dangerCircle, color: Colors.red.shade300, size: 64),
              const SizedBox(height: 16),
              const Text('Gagal memuat produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.invalidate(productDetailProvider(productId)),
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, ProductModel p) {
    final discount = _discountPct(p);
    final savings = _savings(p);
    final imageUrl = p.image != null && p.image!.isNotEmpty
        ? CloudinaryService.getOptimizedUrl(p.image!, width: 800, height: 600)
        : null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // ── 1. Image Background ──────────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            height: MediaQuery.of(context).size.height * 0.45,
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),

          // ── 2. Scrollable Content ────────────────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.35),
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(32),
                        topRight: Radius.circular(32),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMerchantRow(context, p),
                        const SizedBox(height: 20),

                        // Nama Produk
                        Text(
                          p.name ?? 'Produk',
                          style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800,
                            color: Colors.black87, letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Tags
                        _buildTags(p),
                        const SizedBox(height: 20),

                        // Harga
                        _buildPriceRow(p, discount),
                        const SizedBox(height: 24),

                        // Hemat Banner (hanya jika ada diskon)
                        if (savings > 0) ...[
                          _buildSavingBanner(p, savings),
                          const SizedBox(height: 12),
                        ],

                        // Timer Banner
                        _buildTimerBanner(p),
                        const SizedBox(height: 28),

                        // Deskripsi
                        const Text(
                          'Tentang Produk',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          p.description?.isNotEmpty == true
                              ? p.description!
                              : 'Tidak ada deskripsi untuk produk ini.',
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.5),
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 3. Back Button ───────────────────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: GestureDetector(
              onTap: () {
                if (context.canPop()) context.pop();
                else context.go('/home');
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                child: const Icon(SolarIconsOutline.altArrowLeft, color: Colors.black87, size: 22),
              ),
            ),
          ),

          // ── 4. Share/Bookmark (opsional) ─────────────────────────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(SolarIconsOutline.share, color: Colors.black87, size: 22),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomActionBar(context, ref, p),
    );
  }

  Widget _buildMerchantRow(BuildContext context, ProductModel p) {
    final storeName = p.merchant?.storeName ?? 'Toko Tidak Diketahui';
    final location = p.merchant?.location ?? '-';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      color: Colors.transparent,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (p.merchantId.isNotEmpty) {
                  context.push('/merchant/${p.merchantId}');
                }
              },
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(child: Icon(SolarIconsOutline.leaf, color: Colors.white, size: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(storeName,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(SolarIconsOutline.verifiedCheck, color: Color(0xFF4CAF50), size: 14),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(SolarIconsBold.mapPoint, color: Color(0xFFE53935), size: 12),
                            const SizedBox(width: 2),
                            Flexible(
                              child: Text(location,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(SolarIconsOutline.altArrowRight, color: Colors.grey, size: 18),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _startChat(context, p),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(SolarIconsOutline.chatRound, color: Color(0xFF2E7D32), size: 18),
                ),
                const SizedBox(height: 4),
                const Text('Tanyakan', style: TextStyle(fontSize: 10, color: Colors.black54, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _startChat(BuildContext context, ProductModel product) async {
    final merchant = product.merchant;
    if (merchant == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data toko tidak tersedia')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      ),
    );

    try {
      final supabase = SupabaseService().client;
      final myUid = supabase.auth.currentUser?.id;
      
      if (myUid == null) {
        Navigator.of(context, rootNavigator: true).pop();
        context.push('/login');
        return;
      }

      if (myUid == merchant.userId) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Anda tidak bisa chat dengan toko Anda sendiri')),
        );
        return;
      }

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

      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading
        context.push('/chat-detail', extra: {
          'chatId': chatId,
          'peerName': merchant.storeName,
          'peerAvatar': merchant.avatarUrl ?? '',
          'isUserSide': true,
          'productName': product.name,
          'productPrice': _rupiah(product.price),
          'productImage': product.image != null && product.image!.isNotEmpty
              ? CloudinaryService.getOptimizedUrl(product.image!, width: 200, height: 200)
              : null,
        });
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Tutup dialog loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal membuka chat: $e')),
        );
      }
    }
  }

  Widget _buildTags(ProductModel p) {
    Widget tag(String text, {IconData? icon}) {
      return Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 11, color: const Color(0xFF2E7D32)), const SizedBox(width: 3)],
            Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF2E7D32))),
          ],
        ),
      );
    }

    return Wrap(
      children: [
        if (p.category?.name != null) tag(p.category!.name, icon: SolarIconsOutline.widget),
        tag(_pickupRange(p), icon: SolarIconsOutline.clockCircle),
        if (p.status != null) tag(p.status == 'available' ? 'Sisa Stok: ${p.stock ?? 0}' : p.status!),
      ],
    );
  }

  Widget _buildPriceRow(ProductModel p, String? discount) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (discount != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(20)),
            child: Text(discount,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          const SizedBox(width: 10),
        ],
        Text(
          _rupiah(p.price),
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32), letterSpacing: -0.5),
        ),
        if (p.originalPrice != null) ...[
          const SizedBox(width: 8),
          Text(
            _rupiah(p.originalPrice),
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
          ),
        ],
      ],
    );
  }

  Widget _buildSavingBanner(ProductModel p, double savings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(SolarIconsOutline.checkCircle, color: Color(0xFF2E7D32), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
                children: [
                  const TextSpan(text: 'Kamu menghemat '),
                  TextSpan(text: _rupiah(savings),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: ' & menyelamatkan makanan dari terbuang! 🌱'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimerBanner(ProductModel p) {
    final timeStr = _timeRemaining(p);
    final pickupRange = _pickupRange(p);
    final isExpired = timeStr == 'Waktu habis';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isExpired ? const Color(0xFFFFEBEE) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(SolarIconsOutline.alarm,
                color: isExpired ? Colors.red.shade400 : const Color(0xFFF57F17), size: 18),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Waktu pengambilan',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                  Text(pickupRange,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.black87)),
                ],
              ),
            ],
          ),
          Text(timeStr,
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w800,
              color: isExpired ? Colors.red.shade400 : const Color(0xFFE65100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(BuildContext context, WidgetRef ref, ProductModel p) {
    final isExpired = _timeRemaining(p) == 'Waktu habis';
    final isAvailable = p.status == 'available';
    final isOutOfStock = (p.stock ?? 0) <= 0;
    final isDisabled = !isAvailable || isExpired || isOutOfStock;

    return Container(
      padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: isDisabled ? null : () {
              ref.read(cartProvider.notifier).addToCart(p);
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"${p.name}" ditambahkan ke keranjang'),
                  backgroundColor: const Color(0xFF2E7D32),
                  duration: const Duration(seconds: 1),
                  behavior: SnackBarBehavior.floating,
                  margin: EdgeInsets.only(
                    bottom: MediaQuery.of(context).size.height * 0.01,
                    left: 20,
                    right: 20,
                  ),
                ),
              );
            },
            child: Container(
              height: 52, width: 52,
              decoration: BoxDecoration(
                color: isDisabled ? Colors.grey.shade100 : const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDisabled ? Colors.grey.shade300 : const Color(0xFFC8E6C9), 
                  width: 1.5
                ),
              ),
              child: Center(
                child: Icon(
                  SolarIconsOutline.cart, 
                  color: isDisabled ? Colors.grey : const Color(0xFF2E7D32)
                )
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: isDisabled ? null : () {
                  // Langsung ke checkout dengan membawa 1 item ini
                  final item = CartItemModel(product: p, quantity: 1, isSelected: true);
                  context.push('/checkout', extra: [item]);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F943B),
                  disabledBackgroundColor: Colors.grey.shade300,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: Text(
                  isExpired
                      ? '⏰ Waktu Habis'
                      : isOutOfStock
                          ? 'Stok Habis'
                          : !isAvailable
                              ? 'Tidak Tersedia'
                              : '🌱 Selamatkan – ${_rupiah(p.price)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      color: const Color(0xFFF1F1F1),
      child: const Center(child: Icon(SolarIconsOutline.gallery, size: 64, color: Colors.grey)),
    );
  }
}
