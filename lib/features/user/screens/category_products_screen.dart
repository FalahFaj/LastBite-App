import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:lastbite/features/user/providers/home_provider.dart';
import 'package:lastbite/features/user/providers/banner_provider.dart';
import 'package:lastbite/core/widgets/banner_carousel.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:solar_icons/solar_icons.dart';

// Filter chip enum
enum ProductFilter { semua, berakhirHariIni, dibawah25k, siapSekarang }

// Sort option enum
enum SortOption { newest, priceAsc, priceDesc, timeAsc }

class _FilterNotifier extends Notifier<ProductFilter> {
  @override
  ProductFilter build() => ProductFilter.semua;
  void set(ProductFilter value) => state = value;
}

final _filterProvider = NotifierProvider<_FilterNotifier, ProductFilter>(_FilterNotifier.new);

class CategoryProductsScreen extends ConsumerStatefulWidget {
  final String categorySlug;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categorySlug,
    required this.categoryName,
  });

  @override
  ConsumerState<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends ConsumerState<CategoryProductsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  SortOption _sortOption = SortOption.newest;
  double? _maxPrice;
  final PageController _promoPageController = PageController(initialPage: 3000);

  @override
  void dispose() {
    _searchController.dispose();
    _promoPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(availableProductsProvider);
    final selectedFilter = ref.watch(_filterProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: RefreshIndicator(
        color: const Color(0xFF2E7D32),
        onRefresh: () async => ref.read(availableProductsProvider.notifier).refresh(),
        child: CustomScrollView(
          slivers: [
            // ── SliverAppBar ─────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              pinned: true,
              leading: IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(SolarIconsOutline.altArrowLeft, size: 16, color: Colors.black87),
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home');
                  }
                },
              ),
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.categoryName,
                    style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87,
                    ),
                  ),
                  Text(
                    'Temukan berdasarkan kategori',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(112),
                child: Column(
                  children: [
                    // Search Bar
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F2F2),
                          borderRadius: BorderRadius.circular(50),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(SolarIconsOutline.magnifier, color: Colors.grey.shade400, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Cari di ${widget.categoryName}...',
                                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: const TextStyle(fontSize: 14, color: Colors.black87),
                                onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                              ),
                            ),
                            if (_searchQuery.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                },
                                child: Icon(SolarIconsOutline.closeSquare, color: Colors.grey.shade400, size: 18),
                              )
                            else
                              GestureDetector(
                                onTap: () => _showFilterSheet(context),
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Icon(SolarIconsOutline.filter, color: _hasActiveFilter ? const Color(0xFF2E7D32) : Colors.grey.shade500, size: 20),
                                    if (_hasActiveFilter)
                                      Positioned(
                                        right: -3,
                                        top: -3,
                                        child: Container(
                                          width: 8, height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF2E7D32),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    // Filter chips
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
                        children: [
                          _filterChip(ref, 'Semua', ProductFilter.semua, selectedFilter),
                          const SizedBox(width: 8),
                          _filterChip(ref, 'Berakhir hari ini', ProductFilter.berakhirHariIni, selectedFilter),
                          const SizedBox(width: 8),
                          _filterChip(ref, '< Rp 25k', ProductFilter.dibawah25k, selectedFilter),
                          const SizedBox(width: 8),
                          _filterChip(ref, 'Siap saat ini', ProductFilter.siapSekarang, selectedFilter),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Body Content ─────────────────────────────────────────────
            productsAsync.when(
              data: (allProducts) {
                // Filter berdasarkan kategori
                var products = allProducts.where((p) => p.category?.slug == widget.categorySlug).toList();

                // Apply search query
                if (_searchQuery.isNotEmpty) {
                  products = products.where((p) {
                    final name = (p.name ?? '').toLowerCase();
                    final store = (p.merchant?.storeName ?? '').toLowerCase();
                    final desc = (p.description ?? '').toLowerCase();
                    return name.contains(_searchQuery) || store.contains(_searchQuery) || desc.contains(_searchQuery);
                  }).toList();
                }

                // Apply filter chip
                final now = TimeOfDay.now();
                final nowMinutes = now.hour * 60 + now.minute;

                if (selectedFilter == ProductFilter.berakhirHariIni) {
                  products = products.where((p) => p.pickupEnd != null).toList();
                } else if (selectedFilter == ProductFilter.dibawah25k) {
                  products = products.where((p) => (p.price ?? 0) < 25000).toList();
                } else if (selectedFilter == ProductFilter.siapSekarang) {
                  products = products.where((p) {
                    if (p.pickupStart == null) return true;
                    final startMin = p.pickupStart!.hour * 60 + p.pickupStart!.minute;
                    return nowMinutes >= startMin;
                  }).toList();
                }

                // Apply max price filter
                if (_maxPrice != null) {
                  products = products.where((p) => (p.price ?? 0) <= _maxPrice!).toList();
                }

                // Apply sort
                products.sort((a, b) {
                  switch (_sortOption) {
                    case SortOption.priceAsc:
                      return (a.price ?? 0).compareTo(b.price ?? 0);
                    case SortOption.priceDesc:
                      return (b.price ?? 0).compareTo(a.price ?? 0);
                    case SortOption.timeAsc:
                      final aMin = a.pickupEnd != null ? a.pickupEnd!.hour * 60 + a.pickupEnd!.minute : 9999;
                      final bMin = b.pickupEnd != null ? b.pickupEnd!.hour * 60 + b.pickupEnd!.minute : 9999;
                      return aMin.compareTo(bMin);
                    case SortOption.newest:
                    return 0;
                  }
                });

                if (products.isEmpty) {
                  return SliverFillRemaining(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(SolarIconsOutline.magnifier, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text(
                            'Belum ada produk tersedia.',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Coba periksa lagi nanti atau\nubah filter pencarian.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Partition: urgent (< 3 jam) vs normal
                final urgentProducts = products.where((p) {
                  if (p.pickupEnd == null) return false;
                  final endMin = p.pickupEnd!.hour * 60 + p.pickupEnd!.minute;
                  return (endMin - nowMinutes) < 180 && (endMin - nowMinutes) > 0;
                }).toList();

                final normalProducts = products.where((p) {
                  if (p.pickupEnd == null) return true;
                  final endMin = p.pickupEnd!.hour * 60 + p.pickupEnd!.minute;
                  return (endMin - nowMinutes) >= 180;
                }).toList();

                return SliverList(
                  delegate: SliverChildListDelegate([
                    // ── Promo Banner ─────────────────────────────────────
                    Consumer(
                      builder: (context, ref, child) {
                        return ref.watch(bannersProvider).when(
                          data: (banners) {
                            final categoryBanners = banners.where((b) => b.position == 'category_${widget.categorySlug}').toList();
                            
                            if (categoryBanners.isEmpty) {
                              if (widget.categorySlug == 'makanan') {
                                return Column(
                                  children: [
                                    _buildPromoBanner(context),
                                    const SizedBox(height: 22),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            }
                            
                            return Column(
                              children: [
                                const SizedBox(height: 16),
                                BannerCarousel(
                                  banners: categoryBanners,
                                  fallbackWidget: const SizedBox.shrink(),
                                ),
                                const SizedBox(height: 22),
                              ],
                            );
                          },
                          loading: () => widget.categorySlug == 'makanan' 
                              ? Column(children: [_buildPromoBanner(context), const SizedBox(height: 22)]) 
                              : const SizedBox.shrink(),
                          error: (_, __) => widget.categorySlug == 'makanan' 
                              ? Column(children: [_buildPromoBanner(context), const SizedBox(height: 22)]) 
                              : const SizedBox.shrink(),
                        );
                      },
                    ),

                    // ── Segera Berakhir ───────────────────────────────────
                    if (urgentProducts.isNotEmpty) ...[
                      _buildSectionHeader('Segera Berakhir', '', context),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 240,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(left: 16, right: 16),
                          itemCount: urgentProducts.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (ctx, i) => _buildUrgentCard(ctx, urgentProducts[i]),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // ── More Deals ────────────────────────────────────────
                    if (normalProducts.isNotEmpty) ...[
                      _buildSectionHeader(
                        'More food deals',
                        'Waktu berakhir terdekat',
                        context,
                        subtitle: true,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisExtent: 230,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: normalProducts.length,
                          itemBuilder: (ctx, i) => _buildGridCard(ctx, normalProducts[i]),
                        ),
                      ),
                      const SizedBox(height: 28),
                    ],

                    // Jika semua produk urgent, tampilkan semua dalam grid
                    if (urgentProducts.isNotEmpty && normalProducts.isEmpty) ...[
                      _buildSectionHeader('Semua Penawaran', '', context),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.75,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                          itemCount: urgentProducts.length,
                          itemBuilder: (ctx, i) => _buildGridCard(ctx, urgentProducts[i]),
                        ),
                      ),
                    ],

                    // ── Seller CTA (hanya untuk non-merchant) ────────────
                    Builder(builder: (ctx) {
                      final isMerchantAsync = ref.watch(isMerchantProvider);
                      final isMerchant = isMerchantAsync.value ?? false;
                      if (isMerchant) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                        child: _buildSellerCTA(context),
                      );
                    }),
                  ]),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF2E7D32))),
              ),
              error: (err, _) => SliverFillRemaining(
                child: Center(child: Text('Gagal memuat: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Getter: ada filter aktif? ─────────────────────────────────────────────
  bool get _hasActiveFilter => _sortOption != SortOption.newest || _maxPrice != null;

  // ── Method: Filter Bottom Sheet ───────────────────────────────────────────
  void _showFilterSheet(BuildContext context) {
    SortOption tempSort = _sortOption;
    double? tempMaxPrice = _maxPrice;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: EdgeInsets.only(
                left: 20, right: 20, top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + MediaQuery.of(ctx).padding.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Handle bar
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Filter & Urutkan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
                      GestureDetector(
                        onTap: () {
                          setSheetState(() {
                            tempSort = SortOption.newest;
                            tempMaxPrice = null;
                          });
                        },
                        child: Text('Reset', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Urutkan ────────────────────────────────────────────────
                  const Text('Urutkan', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(height: 10),
                  ...[
                    (SortOption.newest,    'Terbaru'),
                    (SortOption.priceAsc,  'Harga: Termurah'),
                    (SortOption.priceDesc, 'Harga: Termahal'),
                    (SortOption.timeAsc,   'Berakhir Paling Cepat'),
                  ].map((item) {
                    final (opt, label) = item;
                    final isSelected = tempSort == opt;
                    return GestureDetector(
                      onTap: () => setSheetState(() => tempSort = opt),
                      child: Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF2E7D32) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isSelected ? const Color(0xFF2E7D32) : Colors.black87))),
                            if (isSelected) const Icon(SolarIconsOutline.checkCircle, color: Color(0xFF2E7D32), size: 18),
                          ],
                        ),
                      ),
                    );
                  }),

                  // ── Batas Harga ────────────────────────────────────────────
                  const SizedBox(height: 16),
                  const Text('Batas Harga Maksimum', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      (null,    'Semua'),
                      (15000.0, '≤ Rp 15k'),
                      (25000.0, '≤ Rp 25k'),
                      (50000.0, '≤ Rp 50k'),
                    ].map((item) {
                      final (price, label) = item;
                      final isSelected = tempMaxPrice == price;
                      return GestureDetector(
                        onTap: () => setSheetState(() => tempMaxPrice = price),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
                            borderRadius: BorderRadius.circular(50),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300,
                            ),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isSelected ? Colors.white : Colors.black87),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 20),
                  // ── Tombol Terapkan ────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _sortOption = tempSort;
                          _maxPrice = tempMaxPrice;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('Terapkan Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  String _rupiah(double? val) =>
      NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(val ?? 0);

  // ── Helper: Time label ────────────────────────────────────────────────────
  String _timeLabel(ProductModel p) {
    if (p.pickupEnd == null) return 'Tersedia';
    final now = TimeOfDay.now();
    final diff = (p.pickupEnd!.hour * 60 + p.pickupEnd!.minute) - (now.hour * 60 + now.minute);
    if (diff <= 0) return 'Waktu habis';
    if (diff >= 60) return '${diff ~/ 60} jam lagi';
    return '$diff menit lagi';
  }

  // ── Helper: Discount % ────────────────────────────────────────────────────
  String? _discountPct(ProductModel p) {
    if (p.price == null || p.originalPrice == null || p.originalPrice! <= 0) return null;
    final pct = ((p.originalPrice! - p.price!) / p.originalPrice! * 100).round();
    return pct > 0 ? '-$pct%' : null;
  }

  // ── Widget: Filter Chip ───────────────────────────────────────────────────
  Widget _filterChip(WidgetRef ref, String label, ProductFilter value, ProductFilter selected) {
    final isSelected = selected == value;
    return GestureDetector(
      onTap: () => ref.read(_filterProvider.notifier).set(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(
            color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade200,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ── Widget: Promo Banner ──────────────────────────────────────────────────
  Widget _buildPromoBanner(BuildContext context) {
    final banners = [
      _buildBannerCard(
        title: 'Jangan biarkan\nmakanan baik terbuang!',
        subtitle: 'Temukan makanan diskon di dekatmu, dan beli setiap checkout lebih hemat dan ramah lingkungan.',
        tag1: 'Diskon hingga 70%',
        tag2: 'Kontribusi kepada Bumi',
        topTag: '🌱 Selamatkan makanan. Selamatkan uang.',
        colors: [const Color(0xFF1B5E20), const Color(0xFF2E7D32)],
        icon: SolarIconsOutline.leaf,
      ),
      _buildBannerCard(
        title: 'Beli Makanan Sisa\nJadi Lebih Mudah!',
        subtitle: 'Nikmati makanan enak dengan harga miring sambil bantu kurangi limbah. Geser untuk cek promo!',
        tag1: 'Hemat Uang',
        tag2: 'Mudah & Cepat',
        topTag: '🛍️ Belanja pintar.',
        colors: [const Color(0xFFE65100), const Color(0xFFF57C00)],
        icon: SolarIconsOutline.bag2,
      ),
      _buildBannerCard(
        title: 'Bergabung dengan\nGerakan Zero Waste',
        subtitle: 'Jadilah pahlawan lingkungan. Bersama-sama kita kurangi sampah makanan di kota kita.',
        tag1: 'Zero Waste',
        tag2: 'Go Green',
        topTag: '🌍 Sayangi Bumi.',
        colors: [const Color(0xFF01579B), const Color(0xFF0288D1)],
        icon: SolarIconsOutline.global,
      ),
    ];

    return Container(
      height: 215,
      margin: const EdgeInsets.only(top: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _promoPageController,
            itemBuilder: (context, index) {
              return banners[index % banners.length];
            },
          ),
          Positioned(
            left: -4,
            child: _buildNavButton(
              icon: SolarIconsOutline.altArrowLeft,
              onTap: () {
                if (_promoPageController.hasClients) {
                  _promoPageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
            ),
          ),
          Positioned(
            right: -4,
            child: _buildNavButton(
              icon: SolarIconsOutline.altArrowRight,
              onTap: () {
                if (_promoPageController.hasClients) {
                  _promoPageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(icon, size: 20, color: Colors.black87),
      ),
    );
  }

  Widget _buildBannerCard({
    required String title,
    required String subtitle,
    required String tag1,
    required String tag2,
    required String topTag,
    required List<Color> colors,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF9A825),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            topTag,
                            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.black87),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          subtitle,
                          style: TextStyle(fontSize: 10.5, color: Colors.white.withValues(alpha: 0.8), height: 1.5),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(50),
                              ),
                              child: Text(
                                tag1,
                                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: colors[1]),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(50),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                              ),
                              child: Text(
                                tag2,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(icon, color: Colors.white, size: 36),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget: Section Header ────────────────────────────────────────────────
  Widget _buildSectionHeader(String title, String action, BuildContext context, {bool subtitle = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          if (action.isNotEmpty)
            Text(
              action,
              style: TextStyle(
                fontSize: subtitle ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: subtitle ? Colors.grey.shade500 : const Color(0xFF2E7D32),
              ),
            ),
        ],
      ),
    );
  }

  // ── Widget: Urgent (Horizontal) Card ─────────────────────────────────────
  Widget _buildUrgentCard(BuildContext context, ProductModel p) {
    final discount = _discountPct(p);
    final label = _timeLabel(p);

    return GestureDetector(
      onTap: () => context.push('/product/${p.id}', extra: p),
      child: Container(
        width: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: p.image != null && p.image!.isNotEmpty
                      ? Image.network(
                          CloudinaryService.getOptimizedUrl(p.image!, width: 400, height: 240),
                          height: 120, width: 200, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(120, 200))
                      : _placeholder(120, 200),
                ),
                if (discount != null)
                  Positioned(
                    top: 8, left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(6)),
                      child: Text(discount, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ),
                Positioned(
                  bottom: 8, left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(SolarIconsBold.clockCircle, size: 10, color: Colors.orangeAccent),
                        const SizedBox(width: 4),
                        Text('Berakhir: $label', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.merchant?.storeName ?? 'Toko',
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    p.name ?? 'Produk',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _rupiah(p.price),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                          ),
                          if (p.originalPrice != null)
                            Text(
                              _rupiah(p.originalPrice),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
                            ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () => context.push('/product/${p.id}', extra: p),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2E7D32),
                            borderRadius: BorderRadius.circular(50),
                          ),
                          child: const Text('Selamatkan', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget: Normal (Grid) Card ────────────────────────────────────────────
  Widget _buildGridCard(BuildContext context, ProductModel p) {
    final discount = _discountPct(p);
    final label = _timeLabel(p);

    return GestureDetector(
      onTap: () => context.push('/product/${p.id}', extra: p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 3)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  child: p.image != null && p.image!.isNotEmpty
                      ? Image.network(
                          CloudinaryService.getOptimizedUrl(p.image!, width: 400, height: 300),
                          height: 110, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholder(110, double.infinity))
                      : _placeholder(110, double.infinity),
                ),
                if (discount != null)
                  Positioned(
                    top: 7, left: 7,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFFFF5252), borderRadius: BorderRadius.circular(5)),
                      child: Text(discount, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Time badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE082).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(SolarIconsOutline.clockCircle, size: 9, color: Color(0xFFF57F17)),
                        const SizedBox(width: 3),
                        Text(label, style: const TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: Color(0xFFE65100))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    p.merchant?.storeName ?? 'Toko',
                    style: TextStyle(fontSize: 9.5, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.name!.length > 23 ? '${p.name!.substring(0, 23)}...' : p.name ?? 'Produk',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Colors.black87),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _rupiah(p.price),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF2E7D32)),
                  ),
                  if (p.originalPrice != null)
                    Text(
                      _rupiah(p.originalPrice),
                      style: TextStyle(fontSize: 9.5, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget: Seller CTA ────────────────────────────────────────────────────
  Widget _buildSellerCTA(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F),
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFFFE082), shape: BoxShape.circle),
            child: const Icon(SolarIconsOutline.shop, color: Colors.black87, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Punya stok berlebih hari ini?',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.black87),
                ),
                const SizedBox(height: 3),
                Text(
                  'Jual stok berlebih jadi pemasukan, kurangi produk terbuang, dan bantu pembeli terdekat menemukan diskon terbaikmu!',
                  style: TextStyle(fontSize: 10, color: Colors.black87.withValues(alpha: 0.75), height: 1.4),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () => context.push('/register-merchant'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF3E2723), borderRadius: BorderRadius.circular(50)),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Mulai Berjualan', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                        SizedBox(width: 4),
                        Icon(SolarIconsOutline.altArrowRight, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(double height, double width) {
    return Container(
      height: height,
      width: width.isInfinite ? double.infinity : width,
      color: const Color(0xFFF1F1F1),
      child: const Center(child: Icon(SolarIconsOutline.gallery, color: Colors.grey, size: 32)),
    );
  }
}
