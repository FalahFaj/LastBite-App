import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/features/user/providers/home_provider.dart';
import 'package:lastbite/features/user/providers/banner_provider.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:lastbite/core/widgets/banner_carousel.dart';
import 'package:lastbite/core/models/category_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:lastbite/features/user/providers/cart_provider.dart';
import 'package:solar_icons/solar_icons.dart';

// Sort option (digunakan juga di home)
enum HomeSortOption { newest, priceAsc, priceDesc, timeAsc }

class UserHomeScreen extends ConsumerStatefulWidget {
  const UserHomeScreen({super.key});

  @override
  ConsumerState<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends ConsumerState<UserHomeScreen> {
  HomeSortOption _sortOption = HomeSortOption.newest;
  double? _maxPrice;

  bool get _hasActiveFilter => _sortOption != HomeSortOption.newest || _maxPrice != null;

  @override
  Widget build(BuildContext context) {
    final isMerchantAsync = ref.watch(isMerchantProvider);
    final isMerchant = isMerchantAsync.value ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF2E7D32),
          onRefresh: () async {
            ref.invalidate(categoriesProvider);
            ref.invalidate(availableProductsProvider);
            ref.invalidate(userProfileProvider);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildSearchBar(context),
              const SizedBox(height: 24),
              ref.watch(bannersProvider).when(
                data: (banners) {
                  final homeBanners = banners.where((b) => b.position == 'home_main').toList();
                  return BannerCarousel(
                    banners: homeBanners,
                    fallbackWidget: _buildMainBannerFallback(),
                  );
                },
                loading: () => _buildMainBannerFallback(),
                error: (_, __) => _buildMainBannerFallback(),
              ),
              const SizedBox(height: 28),
              _buildCategories(ref, context),
              const SizedBox(height: 32),
              _buildSectionTitle('Selamatkan Sebelum Terlambat!', 'Semua', onTap: () => context.push('/category/makanan?name=Makanan')),
              const SizedBox(height: 16),
              _buildProductList(context, ref, 'makanan'),
              if (!isMerchant) ...[
                const SizedBox(height: 32),
                ref.watch(bannersProvider).when(
                  data: (banners) {
                    final sellerBanners = banners.where((b) => b.position == 'home_seller').toList();
                    return BannerCarousel(
                      banners: sellerBanners,
                      fallbackWidget: _buildSellerBannerFallback(context),
                    );
                  },
                  loading: () => _buildSellerBannerFallback(context),
                  error: (_, __) => _buildSellerBannerFallback(context),
                ),
              ],
              const SizedBox(height: 32),
              _buildSectionTitle('Pre-Loved Terbaik!', 'Semua', onTap: () => context.push('/category/preloved?name=Pre-Loved')),
              const SizedBox(height: 16),
              _buildProductList(context, ref, 'preloved'),
              const SizedBox(height: 32),
              _buildSectionTitle('Elektonik!', 'Semua', onTap: () => context.push('/category/elektronik?name=Elektronik')),
              const SizedBox(height: 16),
              _buildProductList(context, ref, 'elektronik'),
              const SizedBox(height: 32),
              _buildSectionTitle('Perabotan bagus!', 'Semua', onTap: () => context.push('/category/perabotan?name=Perabotan')),
              const SizedBox(height: 16),
              _buildProductList(context, ref, 'perabotan'),
              const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Icon(SolarIconsOutline.mapPoint, color: Colors.grey.shade700, size: 22),
        const SizedBox(width: 6),
        Text(
          'LastBite',
          style: TextStyle(fontFamily: 'DMSans', 
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
        const SizedBox(width: 2),
        // Icon(SolarIconsOutline.altArrowDown, color: Colors.grey.shade700, size: 22),
        const Spacer(),
        // Basket Icon
        GestureDetector(
          onTap: () => context.push('/cart'),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDF6E3), // Pale yellow
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade200, width: 1),
                ),
                child: const Icon(SolarIconsOutline.cart, size: 20, color: Color(0xFF6A5731)),
              ),
              Consumer(
                builder: (context, ref, child) {
                  final count = ref.watch(cartTotalItemsProvider);
                  if (count == 0) return const SizedBox.shrink();
                  return Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE53935),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Avatar
        GestureDetector(
          onTap: () => context.go('/profile'),
          child: ref.watch(userProfileProvider).when(
            data: (user) {
              final String? pictureUrl = user?.userPictureUrl;
              final name = user?.name ?? 'User';
              return Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade200,
                  image: DecorationImage(
                    image: (pictureUrl != null && pictureUrl.isNotEmpty)
                        ? NetworkImage(pictureUrl)
                        : NetworkImage('https://ui-avatars.com/api/?name=$name&background=16A34A&color=fff&size=150'),
                    fit: BoxFit.cover,
                  ),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              );
            },
            loading: () => Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFF1F8F1)),
              child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2E7D32)))),
            ),
            error: (_, __) => Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey.shade300,
                image: const DecorationImage(
                  image: NetworkImage('https://ui-avatars.com/api/?name=User&background=16A34A&color=fff&size=150'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => context.push('/search'),
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(50),
                border: Border.all(color: Colors.grey.shade300),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Icon(SolarIconsOutline.magnifier, color: Colors.grey.shade400, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Cari Produk...',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 15),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () => _showFilterSheet(context),
          child: Container(
            height: 52,
            width: 52,
            decoration: BoxDecoration(
              color: _hasActiveFilter ? const Color(0xFFE8F5E9) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hasActiveFilter ? const Color(0xFF2E7D32) : Colors.grey.shade300,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(SolarIconsOutline.filter,
                  color: _hasActiveFilter ? const Color(0xFF2E7D32) : Colors.grey, size: 24),
                if (_hasActiveFilter)
                  Positioned(
                    top: 10, right: 10,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showFilterSheet(BuildContext context) {
    HomeSortOption tempSort = _sortOption;
    double? tempMaxPrice = _maxPrice;

    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
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
                  Text('Filter & Urutkan',
                    style: TextStyle(fontFamily: 'DMSans', fontSize: 17, fontWeight: FontWeight.w800, color: Colors.black87)),
                  GestureDetector(
                    onTap: () => setSheetState(() {
                      tempSort = HomeSortOption.newest;
                      tempMaxPrice = null;
                    }),
                    child: Text('Reset',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade500)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Urutkan',
                style: TextStyle(fontFamily: 'DMSans', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
              const SizedBox(height: 10),
              ...[
                (HomeSortOption.newest,    'Terbaru'),
                (HomeSortOption.priceAsc,  'Harga: Termurah'),
                (HomeSortOption.priceDesc, 'Harga: Termahal'),
                (HomeSortOption.timeAsc,   'Berakhir Paling Cepat'),
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
                        Expanded(child: Text(label,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                            color: isSelected ? const Color(0xFF2E7D32) : Colors.black87))),
                        if (isSelected)
                          const Icon(SolarIconsOutline.checkCircle, color: Color(0xFF2E7D32), size: 18),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 16),
              const Text('Batas Harga Maksimum',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87)),
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
                          color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300),
                      ),
                      child: Text(label,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : Colors.black87)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
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
                  child: const Text('Terapkan Filter',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainBannerFallback() {
    return Container(
      width: double.infinity,
      height: 230, // Increased height to prevent bottom overflow
      decoration: BoxDecoration(
        color: const Color(0xFF388E3C), // Base green matching the screenshot
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF388E3C).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            // ── Image Background (Right Side) ────────────────────────────────
            Positioned(
              right: -20,
              top: 0,
              bottom: 0,
              width: MediaQuery.of(context).size.width * 0.6,
              child: Image.asset(
                'assets/banner/Fresh Food.png',
                fit: BoxFit.cover,
              ),
            ),

            // ── Fade Gradient Overlay ───────────────────────────────────────
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF388E3C),
                      const Color(0xFF388E3C).withValues(alpha: 0.9),
                      const Color(0xFF388E3C).withValues(alpha: 0.0),
                    ],
                    stops: const [0.35, 0.5, 0.7],
                  ),
                ),
              ),
            ),

            // ── Content ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDB750), // Golden orange badge
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'SAVE PLANET & WALLET',
                      style: TextStyle(
                        fontFamily: 'DMSans',
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF3E2723), // Dark brown text for contrast
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  
                  // Title
                  const Text(
                    'Rescue Meals.\nPocket Deals.',
                    style: TextStyle(
                      fontFamily: 'DMSans',
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.1,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 10),
                  
                  // Subtitle
                  Text(
                    'Produk terbaik dengan diskon\nhingga 70%',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.9),
                      height: 1.3,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  
                  // Button
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Text(
                      'Temukan Diskon Terbaik',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2E7D32),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategories(WidgetRef ref, BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return categoriesAsync.when(
      data: (categories) {
        if (categories.isEmpty) return const SizedBox.shrink();
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: categories.take(4).map((cat) {
            Color bgColor = const Color(0xFFFEF3EC);
            Color iconColor = const Color(0xFFE65C4F);
            IconData icon = SolarIconsOutline.widget;
            
            if (cat.colorHex != null && cat.colorHex!.length == 7) {
               bgColor = Color(int.parse(cat.colorHex!.substring(1), radix: 16) + 0xFF000000);
            }
            if (cat.slug == 'makanan') { iconColor = const Color(0xFFE65C4F); icon = SolarIconsOutline.bag; }
            else if (cat.slug == 'elektronik') { iconColor = const Color(0xFF38A169); icon = SolarIconsOutline.smartphone; }
            else if (cat.slug == 'perabotan') { iconColor = const Color(0xFFED8936); icon = SolarIconsOutline.armchair; }
            else if (cat.slug == 'preloved') { iconColor = const Color(0xFFD69E2E); icon = SolarIconsOutline.stars; }
            
            return GestureDetector(
              onTap: () => context.push(
                '/category/${cat.slug}?name=${Uri.encodeComponent(cat.name)}',
              ),
              child: _buildCategoryItem(cat.name, icon, bgColor, iconColor),
            );
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => const Text('Gagal memuat kategori'),
    );
  }

  Widget _buildCategoryItem(String title, IconData icon, Color bgColor, Color iconColor) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(icon, color: iconColor, size: 28),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String action, {VoidCallback? onTap}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(fontFamily: 'DMSans', 
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductList(BuildContext context, WidgetRef ref, String categorySlug) {
    final productsAsync = ref.watch(availableProductsProvider);
    
    return productsAsync.when(
      data: (products) {
        var filteredProducts = products.where((p) => p.category?.slug == categorySlug).toList();

        // Apply max price filter
        if (_maxPrice != null) {
          filteredProducts = filteredProducts.where((p) => (p.price ?? 0) <= _maxPrice!).toList();
        }

        // Apply sort
        filteredProducts.sort((a, b) {
          bool aSoldOut = (a.stock != null && a.stock! <= 0) || a.status == 'sold';
          bool bSoldOut = (b.stock != null && b.stock! <= 0) || b.status == 'sold';
          
          if (aSoldOut != bSoldOut) {
            return aSoldOut ? 1 : -1; // Sold out always goes to the bottom/end
          }

          switch (_sortOption) {
            case HomeSortOption.priceAsc:
              return (a.price ?? 0).compareTo(b.price ?? 0);
            case HomeSortOption.priceDesc:
              return (b.price ?? 0).compareTo(a.price ?? 0);
            case HomeSortOption.timeAsc:
              final aMin = a.pickupEnd != null ? a.pickupEnd!.hour * 60 + a.pickupEnd!.minute : 9999;
              final bMin = b.pickupEnd != null ? b.pickupEnd!.hour * 60 + b.pickupEnd!.minute : 9999;
              return aMin.compareTo(bMin);
            case HomeSortOption.newest:
              return (b.createdAt?.millisecondsSinceEpoch ?? 0).compareTo(a.createdAt?.millisecondsSinceEpoch ?? 0);
          }
        });
        
        if (filteredProducts.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'Belum ada produk di kategori ini.',
                style: TextStyle(color: Colors.grey.shade500),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: filteredProducts.map((p) {
              bool isSoldOut = (p.stock != null && p.stock! <= 0) || p.status == 'sold';
              
              // Menghitung status Waktu (Pickup End)
              String timeStatus = 'Tersedia';
              if (p.pickupEnd != null) {
                final now = TimeOfDay.now();
                int currentMinutes = now.hour * 60 + now.minute;
                int endMinutes = p.pickupEnd!.hour * 60 + p.pickupEnd!.minute;
                if (endMinutes > currentMinutes) {
                  int diff = endMinutes - currentMinutes;
                  if (diff >= 60) {
                    timeStatus = '${diff ~/ 60} jam tersisa';
                  } else {
                    timeStatus = '$diff menit tersisa';
                  }
                } else {
                  timeStatus = 'Waktu habis';
                  isSoldOut = true; // Jika waktu habis, anggap sold out
                }
              }

              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _buildProductCard(
                  context: context,
                  product: p,
                  shopName: p.merchant?.storeName ?? 'Toko Tidak Diketahui',
                  productName: p.name ?? 'Barang Tanpa Nama',
                  discountPrice: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(p.price ?? 0),
                  originalPrice: p.originalPrice != null ? NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(p.originalPrice!) : '',
                  tagLabel: isSoldOut ? 'Habis' : timeStatus,
                  tagIcon: isSoldOut ? SolarIconsOutline.closeCircle : SolarIconsOutline.clockCircle,
                  imageUrl: p.image,
                  priceValue: p.price,
                  originalPriceValue: p.originalPrice,
                  isSoldOut: isSoldOut,
                ),
              );
            }).toList(),
          ),
        );
      },
      loading: () => const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())),
      error: (err, stack) => Center(child: Text('Gagal memuat produk: $err')),
    );
  }

  Widget _buildProductCard({
    BuildContext? context,
    ProductModel? product,
    String? shopName,
    required String productName,
    required String discountPrice,
    required String originalPrice,
    required String tagLabel,
    IconData? tagIcon,
    String? imageUrl,
    double? priceValue,
    double? originalPriceValue,
    bool isSoldOut = false,
  }) {
    // Hitung persentase diskon otomatis
    String? discountBadge;
    if (priceValue != null && originalPriceValue != null && originalPriceValue > 0) {
      final discountPct = ((originalPriceValue - priceValue) / originalPriceValue * 100).round();
      if (discountPct > 0) discountBadge = '-$discountPct%';
    }

    return GestureDetector(
      onTap: () {
        if (context != null && product != null) {
          context.push('/product/${product.id}', extra: product);
        }
      },
      child: Opacity(
        opacity: isSoldOut ? 0.6 : 1.0,
        child: Container(
          width: 160,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade100,
                offset: const Offset(0, 4),
                blurRadius: 8,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image Area
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? Image.network(
                            CloudinaryService.getOptimizedUrl(imageUrl, width: 320, height: 240),
                            height: 120,
                            width: 160,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _imagePlaceholder(),
                          )
                        : _imagePlaceholder(),
                  ),
                  if (isSoldOut)
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black45,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            'HABIS',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    )
                  else if (discountBadge != null)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        discountBadge,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Content Area
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (shopName != null) ...[
                    Text(
                      shopName,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade500,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                  ] else ...[
                    const SizedBox(height: 2),
                  ],
                  Text(
                    productName,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Flexible(
                        child: Text(
                          discountPrice,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2E7D32),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (originalPrice.isNotEmpty)
                        Flexible(
                          child: Text(
                            originalPrice,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade400,
                              decoration: TextDecoration.lineThrough,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE082).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (tagIcon != null) ...[
                          Icon(tagIcon, color: const Color(0xFFF57F17), size: 10),
                          const SizedBox(width: 4),
                        ],
                        Flexible(
                          child: Text(
                            tagLabel,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFE65100),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      height: 120,
      width: 160,
      color: const Color(0xFFF1F1F1),
      child: const Center(
        child: Icon(SolarIconsOutline.gallery, color: Colors.grey, size: 36),
      ),
    );
  }


  Widget _buildSellerBannerFallback(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFFFD54F),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFFFE082),
              shape: BoxShape.circle,
            ),
            child: const Icon(SolarIconsOutline.shop, color: Colors.black87, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Punya barang/stok tak terjual?',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ubah barang bekasmu jadi pemasukan,\nSaatnya barangmu dapat kesempatan kedua!',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.black87.withValues(alpha: 0.8),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Material(
                  color: const Color(0xFF3E2723),
                  borderRadius: BorderRadius.circular(50),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(50),
                    onTap: () {
                      context.push('/register-merchant');
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Mulai Berjualan ',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          Icon(SolarIconsOutline.altArrowRight, color: Colors.white, size: 14),
                        ],
                      ),
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
}
