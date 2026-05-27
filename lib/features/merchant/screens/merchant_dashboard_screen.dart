import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/core/models/banner_model.dart';
import 'package:lastbite/features/user/providers/banner_provider.dart';
import 'package:lastbite/core/widgets/banner_carousel.dart';

class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen>
    with WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _merchant;
  double _todayRevenue = 0;
  int _todayCompletedOrders = 0;
  int _totalSaved = 0;
  List<Map<String, dynamic>> _recentOrders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchData();
  }

  Future<void> _fetchData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    try {
      final merchantRes = await supabase
          .from('merchants')
          .select('id, store_name, owner_name, category, balance')
          .eq('user_id', user.id)
          .maybeSingle();
      if (merchantRes == null) return;
      final mId = merchantRes['id'] as String;

      // Fetch avatar_url separately — silently skip if column not yet added
      String? avatarUrl;
      try {
        final av = await supabase
            .from('merchants')
            .select('avatar_url')
            .eq('id', mId)
            .single();
        avatarUrl = av['avatar_url'] as String?;
      } catch (_) {}

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();
      final allOrders = await supabase
          .from('orders')
          .select('id, status, total_price, created_at, order_items(products(merchant_id))')
          .gte('created_at', todayStart)
          .lte('created_at', todayEnd);

      final merchantOrders = (allOrders as List).where((o) {
        final items = o['order_items'] as List? ?? [];
        return items.any((i) => (i['products'] as Map?)?['merchant_id'] == mId);
      }).toList();

      double revenue = 0;
      int completedToday = 0;
      for (final o in merchantOrders) {
        if (o['status'] == 'completed') {
          revenue += (o['total_price'] as num?)?.toDouble() ?? 0;
          completedToday++;
        }
      }

      final allCompleted = await supabase
          .from('orders')
          .select('id, order_items(quantity, products(merchant_id))')
          .eq('status', 'completed');
      int totalSaved = 0;
      for (final o in (allCompleted as List)) {
        final items = o['order_items'] as List? ?? [];
        for (final item in items) {
          if ((item['products'] as Map?)?['merchant_id'] == mId) {
            totalSaved += (item['quantity'] as int? ?? 1);
          }
        }
      }

      final recentRaw = await supabase
          .from('orders')
          .select('id, status, total_price, created_at, order_items(quantity, products(id, name, image, merchant_id)), users(name)')
          .inFilter('status', ['paid', 'ready_for_pickup', 'completed'])
          .order('created_at', ascending: false)
          .limit(10);

      final recent = (recentRaw as List).where((o) {
        final items = o['order_items'] as List? ?? [];
        return items.any((i) => (i['products'] as Map?)?['merchant_id'] == mId);
      }).take(3).toList();

      if (mounted) {
        setState(() {
          // Always include avatar_url key so header can read it (even if null)
          _merchant = {...merchantRes, 'avatar_url': avatarUrl};
          _todayRevenue = revenue;
          _todayCompletedOrders = completedToday;
          _totalSaved = totalSaved;
          _recentOrders = List<Map<String, dynamic>>.from(recent);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Dashboard error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatRp(double value) {
    final formatter = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);
    return formatter.format(value);
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'paid': return 'Diproses';
      case 'ready_for_pickup': return 'Menunggu Dijemput';
      case 'completed': return 'Selesai';
      default: return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid': return const Color(0xFFDBEAFE);
      case 'ready_for_pickup': return const Color(0xFFFCD34D);
      case 'completed': return const Color(0xFF0F943B);
      default: return Colors.grey.shade200;
    }
  }

  Color _statusTextColor(String status) {
    switch (status) {
      case 'paid': return const Color(0xFF1D4ED8);
      case 'ready_for_pickup': return Colors.black87;
      case 'completed': return Colors.white;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeName = _merchant?['store_name'] as String? ?? 'Seller';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      extendBody: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        toolbarHeight: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/home'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 8, offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(SolarIconsOutline.transferHorizontal, size: 16, color: Color(0xFF374151)),
                        SizedBox(width: 6),
                        Text('Mode Pembeli', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF059669)))
            : RefreshIndicator(
                color: const Color(0xFF059669),
                onRefresh: _fetchData,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(storeName),
                      const SizedBox(height: 24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildBalanceCard(context),
                            const SizedBox(height: 24),
                            _buildStatsRow(),
                            const SizedBox(height: 32),
                            _buildActionButtons(context),
                            const SizedBox(height: 32),
                            Consumer(
                              builder: (context, ref, child) {
                                return ref.watch(bannersProvider).when(
                                  data: (banners) {
                                    final dashboardBanners = banners.where((BannerModel b) => b.position == 'merchant_dashboard').toList();
                                    return BannerCarousel(
                                      banners: dashboardBanners,
                                      fallbackWidget: _buildGreenBannerFallback(),
                                    );
                                  },
                                  loading: () => _buildGreenBannerFallback(),
                                  error: (_, __) => _buildGreenBannerFallback(),
                                );
                              },
                            ),
                            const SizedBox(height: 32),
                            _buildSectionHeader(context),
                            const SizedBox(height: 16),
                            if (_recentOrders.isEmpty)
                              Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                                child: const Center(
                                  child: Text('Belum ada pesanan selesai', style: TextStyle(color: Color(0xFF6B7280))),
                                ),
                              )
                            else
                              ..._recentOrders.map((order) {
                                final items = order['order_items'] as List? ?? [];
                                final firstItem = items.isNotEmpty ? items.first : null;
                                final product = firstItem?['products'] as Map<String, dynamic>?;
                                final name = product?['name'] as String? ?? 'Produk';
                                final image = product?['image'] as String?;
                                final status = order['status'] as String? ?? '';
                                final price = (order['total_price'] as num?)?.toDouble() ?? 0;
                                final orderId = '#LB-${(order['id'] as String).substring(0, 4).toUpperCase()}';
                                final buyerName = order['users']?['name'] as String? ?? 'Pembeli';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _buildOrderItem(
                                    id: orderId,
                                    title: name,
                                    buyerName: buyerName,
                                    imageUrl: image ?? '',
                                    status: _statusLabel(status),
                                    statusColor: _statusColor(status),
                                    statusTextColor: _statusTextColor(status),
                                    price: _formatRp(price),
                                  ),
                                );
                              }),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildFallbackAvatar(String storeName) {
    final name = storeName.isNotEmpty ? Uri.encodeComponent(storeName) : 'Toko';
    return Image.network(
      'https://ui-avatars.com/api/?name=$name&background=16A34A&color=fff&size=150',
      width: 48,
      height: 48,
      fit: BoxFit.cover,
    );
  }

  Widget _buildHeader(String storeName) {
    // Use merchant store avatar (from merchants table), fallback to initials
    final merchantAvatarUrl = _merchant?['avatar_url'] as String?;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      child: Row(
        children: [
          ClipOval(
            child: merchantAvatarUrl != null && merchantAvatarUrl.isNotEmpty
                ? Image.network(
                    merchantAvatarUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildFallbackAvatar(storeName),
                  )
                : _buildFallbackAvatar(storeName),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Halo, $storeName!', style: TextStyle(fontFamily: 'DMSans', fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
                const SizedBox(height: 4),
                const Text('Siap ubah surplus jadi penghasilan?', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade200)),
                  child: const Icon(SolarIconsOutline.bell, size: 24, color: Color(0xFF374151)),
                ),
                Positioned(
                  right: 2, top: 2,
                  child: Container(
                    width: 10, height: 10,
                    decoration: BoxDecoration(color: const Color(0xFFEF4444), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(BuildContext context) {
    final balance = (_merchant?['balance'] as num?)?.toDouble() ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF16A34A), Color(0xFF147A36), Color(0xFF0F5A28)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF16A34A).withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Saldo Aktif',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              Text(
                _formatRp(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  fontFamily: 'DMSans',
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          ElevatedButton(
            onPressed: () {
              context.push('/merchant/balance');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF0F5A28),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: const Text(
              'Kelola Saldo',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard(icon: SolarIconsOutline.pieChart, iconColor: const Color(0xFFF59E0B), iconBgColor: const Color(0xFFFEF3C7), label: 'Pendapatan Hari Ini', value: _formatRp(_todayRevenue))),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard(icon: SolarIconsOutline.fire, iconColor: const Color(0xFFEF4444), iconBgColor: const Color(0xFFFEE2E2), label: 'Pesanan Selesai', value: '$_todayCompletedOrders Selesai')),
      ],
    );
  }

  Widget _buildStatCard({required IconData icon, required Color iconColor, required Color iconBgColor, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconBgColor, shape: BoxShape.circle), child: Icon(icon, color: iconColor, size: 24)),
          const SizedBox(height: 16),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontFamily: 'DMSans', fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildActionButton(Icons.add, const Color(0xFF0F943B), Colors.white, 'Tambahkan', () async {
          await context.push('/merchant/add-product');
          _fetchData();
        }),
        _buildActionButton(SolarIconsBold.box, const Color(0xFFE0E7FF), const Color(0xFF4338CA), 'Stok', () {
          context.push('/merchant/products');
        }),
        _buildActionButton(Icons.bar_chart_rounded, const Color(0xFFFDE68A), const Color(0xFFB45309), 'Pendapatan', () {
          context.push('/merchant/balance');
        }),
      ],
    );
  }

  Widget _buildActionButton(IconData icon, Color bgColor, Color iconColor, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(icon, color: iconColor, size: 30),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
        ],
      ),
    );
  }

  Widget _buildGreenBannerFallback() {
    final savedKg = (_totalSaved * 0.45).toStringAsFixed(0);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F943B), Color(0xFF65A30D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: const Color(0xFF0F943B).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Jejak Hijau Kamu 🌱', style: TextStyle(fontFamily: 'DMSans', color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(height: 1.4),
                    children: [
                      const TextSpan(text: 'Kamu telah menyelamatkan ', style: TextStyle(color: Colors.white, fontSize: 13)),
                      TextSpan(text: '$_totalSaved porsi\n', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                      TextSpan(text: 'makanan bulan ini! Itu berarti sekitar $savedKg\nkg makanan terselamatkan dari tempat\npembuangan sampah. ', style: const TextStyle(color: Colors.white, fontSize: 13)),
                      const TextSpan(text: 'Kerja Bagus!', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.asset(
              'assets/banner/Fresh impact veggies.png',
              width: 90, height: 90, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(width: 90, height: 90, color: Colors.green.shade700, child: const Icon(SolarIconsOutline.leaf, color: Colors.white, size: 36)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Penyelamatan Terbaru', style: TextStyle(fontFamily: 'DMSans', fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF111827))),
        GestureDetector(
          onTap: () => context.push('/merchant/orders'),
          child: const Text('Lihat Semua', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
        ),
      ],
    );
  }

  Widget _buildOrderItem({required String id, required String title, required String buyerName, required String imageUrl, required String status, required Color statusColor, required Color statusTextColor, required String price}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl.isNotEmpty
                ? Image.network(imageUrl, width: 70, height: 70, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _imagePlaceholder())
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(id, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF9CA3AF))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: statusColor, borderRadius: BorderRadius.circular(100)),
                      child: Text(status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: statusTextColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(title, style: TextStyle(fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(SolarIconsOutline.user, size: 14, color: Color(0xFF9CA3AF)),
                        const SizedBox(width: 4),
                        Text(buyerName, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                      ],
                    ),
                    Text(price, style: TextStyle(fontFamily: 'DMSans', fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF0F943B))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() => Container(width: 70, height: 70, color: Colors.grey[200], child: const Icon(SolarIconsOutline.hamburgerMenu, color: Colors.grey));
}