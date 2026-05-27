import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/cart_item_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:lastbite/features/user/providers/cart_provider.dart';
import 'package:solar_icons/solar_icons.dart';

class CartScreen extends ConsumerStatefulWidget {
  const CartScreen({super.key});

  @override
  ConsumerState<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends ConsumerState<CartScreen> {
  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    final cartItems = ref.watch(cartProvider);
    final totalItems = ref.watch(cartTotalItemsProvider);
    final totalPrice = ref.watch(cartTotalPriceProvider);
    final totalSavings = ref.watch(cartTotalSavingsProvider);
    final selectedItems = ref.watch(cartSelectedItemsProvider);

    // Group items by merchant
    final Map<String, List<CartItemModel>> groupedItems = {};
    for (var item in cartItems) {
      final merchantName = item.product.merchant?.storeName ?? 'Toko';
      if (!groupedItems.containsKey(merchantName)) {
        groupedItems[merchantName] = [];
      }
      groupedItems[merchantName]!.add(item);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, totalItems),
            Expanded(
              child: cartItems.isEmpty
                  ? _buildEmptyState(context)
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      children: [
                        const SizedBox(height: 20),
                        _buildEcoBanner(selectedItems.length, totalSavings),
                        const SizedBox(height: 12),
                        _buildSelectAllBar(cartItems.length, selectedItems.length, cartItems.length),
                        const SizedBox(height: 12),
                        ...groupedItems.entries.map((entry) {
                          return _buildMerchantGroup(entry.key, entry.value);
                        }),
                        const SizedBox(height: 100),
                      ],
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: cartItems.isEmpty ? null : _buildBottomSummary(totalPrice, totalSavings, selectedItems.length, cartItems.length),
    );
  }

  Widget _buildHeader(BuildContext context, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      color: Colors.white,
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(SolarIconsOutline.altArrowLeft, size: 20),
            ),
          ),
          const SizedBox(width: 16),
          Text(
            'Keranjang Saya ($count)',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectAllBar(int total, int selectedCount, int totalCount) {
    final bool allSelected = selectedCount == totalCount;
    return Row(
      children: [
        _buildCheckbox(
          value: allSelected,
          onChanged: (val) => ref.read(cartProvider.notifier).toggleAll(val ?? false),
        ),
        const SizedBox(width: 10),
        const Text(
          'Semua',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            setState(() {
              _isEditing = !_isEditing;
            });
          },
          child: Text(
            _isEditing ? 'Selesai' : 'Ubah',
            style: TextStyle(
              fontSize: 13, 
              fontWeight: FontWeight.w700, 
              color: _isEditing ? Colors.red : Colors.grey.shade600
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => context.go('/chat'),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F8F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(SolarIconsOutline.chatRound, size: 18, color: Color(0xFF0F943B)),
          ),
        ),
      ],
    );
  }

  Widget _buildEcoBanner(int itemCount, double savings) {
    if (itemCount == 0) return const SizedBox.shrink();
    
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F943B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(SolarIconsOutline.global, color: Colors.white, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4),
                children: [
                  const TextSpan(text: 'Eco-Warrior! ', style: TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: 'Kamu berhasil menyelamatkan '),
                  TextSpan(text: '$itemCount item', style: TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: '\ndan menghemat '),
                  TextSpan(text: currencyFormat.format(savings), style: TextStyle(fontWeight: FontWeight.w800)),
                  const TextSpan(text: ' hari ini!'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchantGroup(String merchantName, List<CartItemModel> items) {
    final bool allMerchantSelected = items.every((item) => item.isSelected);
    final merchantLocation = items.first.product.merchant?.location ?? 'Sumbersari';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildCheckbox(
                  value: allMerchantSelected,
                  onChanged: (val) {
                    ref.read(cartProvider.notifier).toggleMerchantSelection(items.first.product.merchantId, val ?? false);
                  },
                ),
                const SizedBox(width: 12),
                const Icon(SolarIconsOutline.shop, color: Color(0xFF0F943B), size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        merchantName,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.black87),
                      ),
                      const SizedBox(width: 4),
                      const Icon(SolarIconsOutline.verifiedCheck, color: Color(0xFF4CAF50), size: 14),
                    ],
                  ),
                ),
                Icon(SolarIconsOutline.mapPoint, color: Colors.grey.shade400, size: 14),
                const SizedBox(width: 4),
                Text(
                  merchantLocation,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF1F1F1)),
          ...items.map((item) => _buildCartItem(item)),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItemModel item) {
    final product = item.product;
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final discount = product.originalPrice != null && product.originalPrice! > 0
        ? ((product.originalPrice! - (product.price ?? 0)) / product.originalPrice! * 100).round()
        : 0;

    final imageUrl = product.image != null
        ? CloudinaryService.getOptimizedUrl(product.image!, width: 150, height: 150)
        : 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?q=80&w=200';

    final isFood = product.category?.slug.toLowerCase() == 'makanan' || product.category?.name.toLowerCase() == 'makanan';
    
    bool isExpired = false;
    String expiryText = 'Penawaran tidak terbatas';
    Color expiryColor = Colors.grey.shade600;

    if (product.pickupEnd != null) {
      final now = DateTime.now();
      final endDateTime = DateTime(
        now.year, now.month, now.day, 
        product.pickupEnd!.hour, product.pickupEnd!.minute
      );
      
      final diff = endDateTime.difference(now);
      
      if (diff.isNegative) {
         isExpired = true;
         expiryText = 'Penawaran telah berakhir';
         expiryColor = Colors.red.shade600;
      } else {
         final hours = diff.inHours;
         final minutes = diff.inMinutes % 60;
         if (hours > 0) {
            expiryText = 'Berakhir dalam $hours jam $minutes mnt';
         } else {
            expiryText = 'Berakhir dalam $minutes mnt';
         }
         expiryColor = Colors.orange.shade600;
         if (hours < 1) expiryColor = Colors.red.shade600;
      }
    }

    if (isFood && product.createdAt != null) {
      final ageInDays = DateTime.now().difference(product.createdAt!).inDays;
      if (ageInDays >= 1) {
        isExpired = true;
        expiryText = 'Kadaluarsa';
        expiryColor = Colors.red.shade600;
      }
    } else if (!isFood) {
      isExpired = false;
      if (product.pickupEnd == null) {
        expiryText = 'Stok tersedia: ${product.stock ?? 1} barang';
        expiryColor = Colors.green.shade600;
      } else {
        // Jika kebetulan disetel batas pengambilan untuk non-makanan
        expiryText = 'Tersedia hingga ${product.pickupEnd!.format(context)}';
        expiryColor = Colors.green.shade600;
      }
    }

    final isSoldOut = product.status == 'sold' || (product.stock ?? 1) <= 0;
    final isUnavailable = isSoldOut || isExpired;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCheckbox(
                value: item.isSelected && !isUnavailable,
                onChanged: isUnavailable ? (_) {} : (val) {
                  ref.read(cartProvider.notifier).toggleSelection(item.product.id);
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.push('/product/${product.id}'),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Opacity(
                        opacity: isUnavailable ? 0.5 : 1.0,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            imageUrl,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name ?? 'Produk',
                              style: TextStyle(
                                fontSize: 15, 
                                fontWeight: FontWeight.w800, 
                                color: isUnavailable ? Colors.grey.shade500 : Colors.black87,
                                decoration: isUnavailable ? TextDecoration.lineThrough : null,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Icon(SolarIconsOutline.clockCircle, color: expiryColor, size: 14),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    expiryText,
                                    style: TextStyle(fontSize: 11, color: expiryColor, fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              ),
            ],
          ),
        ),
        // Dashed Divider
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: List.generate(
              30,
              (index) => Expanded(
                child: Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: Colors.grey.shade200,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (discount > 0 && !isUnavailable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF5252),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '-$discount%',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                      ),
                    ),
                  Text(
                    currencyFormat.format(product.price ?? 0),
                    style: TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.w900, 
                      color: isUnavailable ? Colors.grey.shade400 : Colors.black87
                    ),
                  ),
                  if (product.originalPrice != null && !isUnavailable)
                    Text(
                      currencyFormat.format(product.originalPrice),
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                ],
              ),
              const Spacer(),
              isUnavailable 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Tidak Tersedia', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey)),
                  )
                : _buildQuantitySelector(item),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuantitySelector(CartItemModel item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _quantityButton(
            icon: SolarIconsOutline.minusSquare,
            onTap: () => ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity - 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F943B)),
            ),
          ),
          _quantityButton(
            icon: SolarIconsOutline.addCircle,
            onTap: () {
              final currentStock = item.product.stock ?? 1;
              if (item.quantity < currentStock) {
                ref.read(cartProvider.notifier).updateQuantity(item.product.id, item.quantity + 1);
              } else {
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Jumlah pembelian mencapai batas stok.'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _quantityButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(icon, size: 16, color: Colors.grey.shade400),
      ),
    );
  }

  Widget _buildCheckbox({required bool value, required ValueChanged<bool?> onChanged}) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: value ? const Color(0xFF0F943B) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: value ? const Color(0xFF0F943B) : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: value ? const Icon(SolarIconsOutline.checkCircle, size: 16, color: Colors.white) : null,
      ),
    );
  }

  Widget _buildBottomSummary(double totalPrice, double totalSavings, int selectedCount, int totalCount) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEditing ? 'Hapus terpilih' : currencyFormat.format(totalPrice),
                  style: TextStyle(
                    fontSize: _isEditing ? 16 : 22, 
                    fontWeight: FontWeight.w900, 
                    color: _isEditing ? Colors.red : Colors.black87
                  ),
                ),
                if (!_isEditing)
                  Text(
                    'Hemat ${currencyFormat.format(totalSavings)}',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey.shade400),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: selectedCount == 0 ? null : () {
                if (_isEditing) {
                  ref.read(cartProvider.notifier).removeSelected();
                  setState(() {
                    _isEditing = false;
                  });
                } else {
                  context.push('/checkout');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _isEditing ? Colors.red : const Color(0xFF0F943B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                elevation: 0,
              ),
              child: Row(
                children: [
                  Icon(_isEditing ? SolarIconsOutline.trashBinTrash : SolarIconsOutline.leaf, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _isEditing ? 'Hapus ($selectedCount)' : 'Selamatkan ($selectedCount)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(SolarIconsOutline.cart, size: 80, color: Colors.grey.shade200),
          const SizedBox(height: 20),
          const Text(
            'Keranjangmu masih kosong',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87),
          ),
          const SizedBox(height: 8),
          Text(
            'Yuk, selamatkan makanan di sekitarmu!',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F943B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            ),
            child: const Text('Mulai Cari Makanan', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
