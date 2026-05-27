import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:lastbite/features/user/providers/home_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class ProductSearchScreen extends ConsumerStatefulWidget {
  const ProductSearchScreen({super.key});

  @override
  ConsumerState<ProductSearchScreen> createState() => _ProductSearchScreenState();
}

class _ProductSearchScreenState extends ConsumerState<ProductSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _rupiah(double? val) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val ?? 0);

  String _timeLabel(ProductModel p) {
    if (p.pickupEnd == null) return 'Tersedia';
    final now = TimeOfDay.now();
    final diff = (p.pickupEnd!.hour * 60 + p.pickupEnd!.minute) - (now.hour * 60 + now.minute);
    if (diff <= 0) return 'Waktu habis';
    if (diff >= 60) return '${diff ~/ 60} jam lagi';
    return '$diff menit lagi';
  }

  String? _discountPct(ProductModel p) {
    if (p.price == null || p.originalPrice == null || p.originalPrice! <= 0) return null;
    final pct = ((p.originalPrice! - p.price!) / p.originalPrice! * 100).round();
    return pct > 0 ? '-$pct%' : null;
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(availableProductsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(SolarIconsOutline.altArrowLeft, size: 18, color: Colors.black87),
          onPressed: () {
            if (context.canPop()) context.pop();
            else context.go('/home');
          },
        ),
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F2F2),
            borderRadius: BorderRadius.circular(50),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Icon(SolarIconsOutline.magnifier, color: Colors.grey.shade500, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Cari produk, toko...',
                    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                  onChanged: (val) => setState(() => _query = val.trim().toLowerCase()),
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _controller.clear();
                    setState(() => _query = '');
                  },
                  child: Icon(SolarIconsOutline.closeSquare, color: Colors.grey.shade400, size: 18),
                ),
            ],
          ),
        ),
        titleSpacing: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Colors.grey.shade200),
        ),
      ),
      body: _query.isEmpty
          ? _buildEmptyState()
          : productsAsync.when(
              data: (allProducts) {
                final results = allProducts.where((p) {
                  final name = (p.name ?? '').toLowerCase();
                  final store = (p.merchant?.storeName ?? '').toLowerCase();
                  final desc = (p.description ?? '').toLowerCase();
                  return name.contains(_query) || store.contains(_query) || desc.contains(_query);
                }).toList();

                if (results.isEmpty) return _buildNoResults();

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (ctx, i) => _buildResultCard(ctx, results[i]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
              error: (err, _) => Center(child: Text('Gagal memuat: $err')),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(SolarIconsOutline.magnifier, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Cari makanan favoritmu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 6),
          Text(
            'Ketik nama produk atau nama toko',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(SolarIconsOutline.magnifier, size: 72, color: Colors.grey.shade200),
          const SizedBox(height: 16),
          Text(
            'Tidak ditemukan',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 6),
          Text(
            'Coba kata kunci lain',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(BuildContext context, ProductModel p) {
    final discount = _discountPct(p);
    final timeLabel = _timeLabel(p);
    final imageUrl = p.image != null && p.image!.isNotEmpty
        ? CloudinaryService.getOptimizedUrl(p.image!, width: 200, height: 200)
        : null;

    return GestureDetector(
      onTap: () => context.push('/product/${p.id}', extra: p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Row(
          children: [
            // Gambar
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),
            // Konten
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nama toko + badge diskon
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.merchant?.storeName ?? 'Toko',
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (discount != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF5252),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(discount, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Nama produk
                    Text(
                      p.name ?? 'Produk',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Harga
                    Row(
                      children: [
                        Text(
                          _rupiah(p.price),
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                        ),
                        if (p.originalPrice != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            _rupiah(p.originalPrice),
                            style: TextStyle(fontSize: 10, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Timer
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFE082).withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(SolarIconsOutline.clockCircle, size: 9, color: Color(0xFFF57F17)),
                          const SizedBox(width: 3),
                          Text(timeLabel, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 90, height: 90, color: const Color(0xFFF1F1F1),
      child: const Center(child: Icon(SolarIconsOutline.gallery, color: Colors.grey, size: 28)),
    );
  }
}
