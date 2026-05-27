import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/merchant_model.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:solar_icons/solar_icons.dart';

class MerchantStoreScreen extends StatefulWidget {
  final String merchantId;

  const MerchantStoreScreen({super.key, required this.merchantId});

  @override
  State<MerchantStoreScreen> createState() => _MerchantStoreScreenState();
}

class _MerchantStoreScreenState extends State<MerchantStoreScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  MerchantModel? _merchant;
  List<ProductModel> _products = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      
      // Fetch merchant
      final merchantData = await supabase
          .from('merchants')
          .select()
          .eq('id', widget.merchantId)
          .maybeSingle();

      if (merchantData == null) {
        throw 'Toko tidak ditemukan.';
      }

      // Fetch products
      final productsData = await supabase
          .from('products')
          .select()
          .eq('merchant_id', widget.merchantId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _merchant = MerchantModel.fromJson(merchantData);
          _products = (productsData as List).map((p) => ProductModel.fromJson(p)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.white,
        body: Center(child: CircularProgressIndicator(color: Color(0xFF16A34A))),
      );
    }

    if (_errorMessage != null || _merchant == null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(backgroundColor: Colors.white, elevation: 0),
        body: Center(
          child: Text(
            _errorMessage ?? 'Toko tidak ditemukan.',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [
            _buildSliverAppBar(),
            SliverToBoxAdapter(
              child: _buildStoreInfo(),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF16A34A),
                  labelColor: const Color(0xFF16A34A),
                  unselectedLabelColor: Colors.grey.shade500,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  tabs: [
                    const Tab(text: 'Diskon Hari Ini'),
                    Tab(text: 'Ulasan (128)'), // Dummy
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildProductsGrid(),
            _buildReviewsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      expandedHeight: 200.0,
      pinned: true,
      elevation: 0,
      leading: IconButton(
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4),
            ],
          ),
          child: const Icon(SolarIconsOutline.altArrowLeft, color: Colors.black87, size: 20),
        ),
        onPressed: () => context.pop(),
      ),
      actions: [
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              shape: BoxShape.circle,
            ),
            child: const Icon(SolarIconsOutline.share, color: Colors.black87, size: 20),
          ),
          onPressed: () {},
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner Image
            Image.network(
              'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&q=80', // Dummy banner
              fit: BoxFit.cover,
            ),
            // Gradient Overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.4),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.2),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStoreInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar and store name
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(height: 50, color: Colors.transparent),
            Positioned(
              top: -40,
              left: 20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 8),
                  ],
                  image: DecorationImage(
                    image: _merchant!.avatarUrl != null && _merchant!.avatarUrl!.isNotEmpty
                        ? NetworkImage(_merchant!.avatarUrl!)
                        : const NetworkImage('https://images.unsplash.com/photo-1583394838336-acd977736f90?auto=format&fit=crop&q=80'), // Placeholder avatar
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _merchant!.storeName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(SolarIconsOutline.verifiedCheck, color: Color(0xFF16A34A), size: 20),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(SolarIconsOutline.mapPoint, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _merchant!.location ?? 'Lokasi tidak tersedia',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Spesialis masakan rumahan harian. Enak, higienis, dan ramah di kantong! Yuk, selamatkan makanan bersisa hari ini dan bantu jaga bumi kita. 🌍💚',
                style: TextStyle(fontSize: 13, color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      icon: const Icon(SolarIconsOutline.chatRound, size: 18),
                      label: const Text('Chat Penjual', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black87,
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(SolarIconsOutline.userPlus, size: 18),
                      label: const Text('Ikuti Toko', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildAlertBox(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildStatItem(SolarIconsOutline.leaf, '20 kg', 'CO2 Dicegah'),
        _buildStatItem(SolarIconsOutline.star, '4.9 / 5.0', '128 Ulasan'),
        _buildStatItem(SolarIconsOutline.bag, '450+', 'Porsi Selamat'),
      ],
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF16A34A), size: 24),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
      ],
    );
  }

  Widget _buildAlertBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDFBF2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFF16A34A),
              shape: BoxShape.circle,
            ),
            child: const Icon(SolarIconsOutline.global, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Toko Pahlawan Lingkungan!',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF92400E), fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  'Membeli dari ${_merchant!.storeName} berkontribusi besar dalam mengurangi limbah makanan harian di daerahmu.',
                  style: const TextStyle(color: Color(0xFF92400E), fontSize: 12, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid() {
    if (_products.isEmpty) {
      return const Center(child: Text('Toko ini belum memiliki produk.', style: TextStyle(color: Colors.grey)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(20),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
        final originalPrice = product.originalPrice ?? 0;
        final price = product.price ?? 0;
        final discount = originalPrice > 0 ? ((originalPrice - price) / originalPrice * 100).round() : 0;

        return GestureDetector(
          onTap: () => context.push('/product/${product.id}', extra: product),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: Image.network(
                          product.image ?? '',
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey.shade200, child: const Icon(SolarIconsOutline.galleryRemove)),
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '-$discount%',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Sisa ${product.stock} Porsi!',
                          style: TextStyle(color: Colors.red.shade600, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        product.name ?? 'Produk',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        currencyFormat.format(product.originalPrice ?? 0),
                        style: const TextStyle(fontSize: 11, color: Colors.grey, decoration: TextDecoration.lineThrough),
                      ),
                      Text(
                        currencyFormat.format(product.price ?? 0),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF16A34A)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildReviewsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(SolarIconsOutline.star, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Belum ada ulasan yang ditampilkan.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
