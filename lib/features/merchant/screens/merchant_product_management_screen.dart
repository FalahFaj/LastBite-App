import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

import 'package:solar_icons/solar_icons.dart';

class MerchantProductManagementScreen extends StatefulWidget {
  const MerchantProductManagementScreen({super.key});

  @override
  State<MerchantProductManagementScreen> createState() => _MerchantProductManagementScreenState();
}

class _MerchantProductManagementScreenState extends State<MerchantProductManagementScreen> {
  final supabase = Supabase.instance.client;
  String? merchantId;
  String _searchQuery = '';
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _products = [];
  bool _loadingProducts = false;

  @override
  void initState() {
    super.initState();
    _fetchMerchantId();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchMerchantId() async {
    final user = supabase.auth.currentUser;
    if (user != null) {
      try {
        final res = await supabase.from('merchants').select('id').eq('user_id', user.id).single();
        if (mounted) {
          setState(() => merchantId = res['id']);
          await _loadProducts();
        }
      } catch (_) {}
    }
  }

  Future<void> _loadProducts() async {
    if (merchantId == null) return;
    setState(() => _loadingProducts = true);
    try {
      final data = await supabase
          .from('products')
          .select()
          .eq('merchant_id', merchantId!)
          .order('created_at', ascending: false);
      if (mounted) setState(() => _products = List<Map<String, dynamic>>.from(data as List));
    } catch (_) {} finally {
      if (mounted) setState(() => _loadingProducts = false);
    }
  }

  String _formatRp(dynamic value) {
    if (value == null) return 'Rp 0';
    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format((value as num).toDouble());
  }

  Future<void> _deleteProduct(String productId) async {
    try {
      await supabase.from('products').delete().eq('id', productId);
      if (mounted) {
        await _loadProducts();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Produk berhasil dihapus'),
            backgroundColor: Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menghapus: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _toggleVisibility(String productId, String currentStatus) async {
    final newStatus = currentStatus == 'hidden' ? 'available' : 'hidden';
    // Optimistic local update first
    setState(() {
      final idx = _products.indexWhere((p) => p['id'] == productId);
      if (idx != -1) _products[idx] = {..._products[idx], 'status': newStatus};
    });
    try {
      await supabase.from('products').update({'status': newStatus}).eq('id', productId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'hidden' ? '🙈 Produk disembunyikan' : '👁️ Produk ditampilkan kembali'),
            backgroundColor: const Color(0xFF16A34A),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final idx = _products.indexWhere((p) => p['id'] == productId);
        if (idx != -1) _products[idx] = {..._products[idx], 'status': currentStatus};
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _confirmDelete(String productId, String productName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Produk', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Hapus "$productName" secara permanen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(color: Color(0xFF6B7280))),
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _deleteProduct(productId); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Hapus', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditProduct(Map<String, dynamic> product) async {
    await context.push('/merchant/edit-product', extra: product);
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF8),
      extendBody: true,

      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.white,
                          ),
                          child: const Icon(SolarIconsOutline.altArrowLeft, color: Colors.black, size: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text('Manajemen Produk', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF2D312E))),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Kelola semua produk surplus milikmu', style: TextStyle(fontSize: 13.5, color: Color(0xFF8A938C))),
                  const SizedBox(height: 20),
                  // Stats row (from Supabase)
                  if (merchantId != null)
                    FutureBuilder(
                      future: Future.wait([
                        supabase.from('products').select('id').eq('merchant_id', merchantId!).neq('status', 'hidden'),
                        supabase.from('order_items').select('quantity, price, orders!inner(status), products!inner(merchant_id)').eq('products.merchant_id', merchantId!).eq('orders.status', 'completed'),
                      ]),
                      builder: (context, snapshot) {
                        final activeCount = snapshot.hasData ? (snapshot.data![0] as List).length : 0;
                        double totalRevenue = 0.0;
                        if (snapshot.hasData) {
                          final items = snapshot.data![1] as List;
                          for (var item in items) {
                            final q = (item['quantity'] as num?)?.toInt() ?? 0;
                            final p = (item['price'] as num?)?.toDouble() ?? 0.0;
                            totalRevenue += (q * p);
                          }
                        }
                        return Row(
                          children: [
                            Expanded(child: _buildStatCard(icon: SolarIconsBold.box, iconBgColor: const Color(0xFFFFF4E5), iconColor: const Color(0xFFFFB74D), value: '$activeCount', label: 'Promo Aktif')),
                            const SizedBox(width: 12),
                            Expanded(child: _buildStatCard(icon: SolarIconsOutline.wallet, iconBgColor: const Color(0xFFE8F5E9), iconColor: const Color(0xFF4CAF50), value: _formatRp(totalRevenue), label: 'Total Pemasukan')),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 20),
                  // Search
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(color: const Color(0xFFD1DDD1)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                            decoration: const InputDecoration(
                              hintText: 'Cari Produk...',
                              hintStyle: TextStyle(color: Color(0xFFA0A9A0), fontSize: 14),
                              prefixIcon: Icon(SolarIconsOutline.magnifier, color: Color(0xFFA0A9A0), size: 22),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFD1DDD1))),
                        child: IconButton(
                          icon: const Icon(SolarIconsOutline.filter, color: Color(0xFF8A938C), size: 22),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Stok Saat Ini', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF2D312E))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loadingProducts
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF0F9D58)))
                  : Builder(builder: (context) {
                      final products = _searchQuery.isEmpty
                          ? _products
                          : _products.where((p) => (p['name'] as String? ?? '').toLowerCase().contains(_searchQuery)).toList();

                      if (products.isEmpty) {
                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(SolarIconsOutline.box, size: 48, color: Color(0xFFD1DDD1)),
                              const SizedBox(height: 16),
                              const Text('Belum ada produk', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF8A938C))),
                              const SizedBox(height: 8),
                              const Text('Tambahkan produk surplus pertamamu!', style: TextStyle(color: Color(0xFFA0A9A0), fontSize: 13)),
                            ],
                          ),
                        );
                      }

                      return RefreshIndicator(
                        color: const Color(0xFF0F9D58),
                        onRefresh: _loadProducts,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                          itemCount: products.length,
                          itemBuilder: (context, index) {
                            final product = products[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _buildProductCard(product),
                            );
                          },
                        ),
                      );
                    }),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard({required IconData icon, required Color iconBgColor, required Color iconColor, required String value, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE8F0E8))),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF2D312E))),
                ),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF6B726C), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Map<String, dynamic> product) {
    final id = product['id'] as String;
    final name = product['name'] as String? ?? 'Tanpa Nama';
    final image = product['image'] as String?;
    final price = product['price'];
    final originalPrice = product['original_price'];
    final stock = product['stock'] as int? ?? 0;
    final pickupEnd = product['pickup_end'] as String? ?? '-';
    final status = product['status'] as String? ?? 'available';
    final isHidden = status == 'hidden';

    return Opacity(
      opacity: isHidden ? 0.6 : 1.0,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isHidden ? Colors.grey.shade300 : const Color(0xFFE8F0E8)),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: image != null && image.isNotEmpty
                      ? Image.network(image, width: 72, height: 72, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          loadingBuilder: (_, child, progress) => progress == null ? child : _imageLoading())
                      : _imagePlaceholder(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: Color(0xFF2D312E)))),
                          if (isHidden)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(8)),
                              child: const Text('Disembunyikan', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(children: [
                        const Icon(SolarIconsOutline.clockCircle, size: 13, color: Color(0xFFFF5252)),
                        const SizedBox(width: 4),
                        Text('Batas: $pickupEnd', style: const TextStyle(fontSize: 11.5, color: Color(0xFFFF5252), fontWeight: FontWeight.w500)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(SolarIconsOutline.box, size: 13, color: Color(0xFF8A938C)),
                        const SizedBox(width: 4),
                        Text('$stock Item tersisa', style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A938C), fontWeight: FontWeight.w500)),
                      ]),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: const Color(0xFFFF5722), borderRadius: BorderRadius.circular(12)),
                            child: const Text('Promo', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Text(_formatRp(price), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2D312E))),
                          const SizedBox(width: 6),
                          Text(_formatRp(originalPrice), style: const TextStyle(fontSize: 12.5, color: Color(0xFF8A938C), decoration: TextDecoration.lineThrough)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Divider
            LayoutBuilder(builder: (_, c) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate((c.constrainWidth() / 8).floor(), (_) => const SizedBox(width: 4, height: 1, child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFFE8F0E8))))),
            )),
            const SizedBox(height: 16),
            // Action buttons
            Row(
              children: [
                Expanded(child: _buildActionBtn(icon: SolarIconsOutline.pen, label: 'Ubah', color: const Color(0xFF2D312E), onTap: () => _openEditProduct(product))),
                const SizedBox(width: 8),
                Expanded(child: _buildActionBtn(
                  icon: isHidden ? SolarIconsOutline.eye : SolarIconsOutline.eyeClosed,
                  label: isHidden ? 'Tampilkan' : 'Sembunyikan',
                  color: const Color(0xFF0F9D58),
                  onTap: () => _toggleVisibility(id, status),
                )),
                const SizedBox(width: 8),
                Expanded(child: _buildActionBtn(icon: SolarIconsOutline.trashBinTrash, label: 'Hapus', color: const Color(0xFFFF5252), onTap: () => _confirmDelete(id, name))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() => Container(width: 72, height: 72, color: Colors.grey.shade200, child: const Icon(SolarIconsOutline.galleryRemove, color: Colors.grey));
  Widget _imageLoading() => Container(width: 72, height: 72, color: Colors.grey.shade100, child: const Center(child: CircularProgressIndicator(strokeWidth: 2)));

  Widget _buildActionBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8F0E8))),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}