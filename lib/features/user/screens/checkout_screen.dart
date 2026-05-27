import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lastbite/core/models/cart_item_model.dart';
import 'package:lastbite/core/services/cloudinary_service.dart';
import 'package:lastbite/features/user/providers/cart_provider.dart';
import 'package:lastbite/features/user/providers/order_provider.dart';
import 'package:lastbite/features/user/providers/user_orders_provider.dart';
import 'package:lastbite/core/providers/config_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:solar_icons/solar_icons.dart';
import 'package:geolocator/geolocator.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final List<CartItemModel>? directItems;
  const CheckoutScreen({super.key, this.directItems});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  String _paymentMethod = 'transfer'; // 'transfer' or 'qris'
  String _shippingMethod = 'pickup'; // 'delivery' or 'pickup'
  String? _userName;
  String? _userAddress;
  double? _userLatitude;
  double? _userLongitude;
  bool _isLoadingAddress = true;

  @override
  void initState() {
    super.initState();
    _fetchUserAddress();
  }

  Future<void> _fetchUserAddress() async {
    setState(() => _isLoadingAddress = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user != null) {
        final data = await supabase
            .from('users')
            .select('name, address, latitude, longitude')
            .eq('id', user.id)
            .maybeSingle();
        if (data != null) {
          if (mounted) {
            setState(() {
              _userName = data['name'];
              _userAddress = data['address'];
              if (data['latitude'] != null) _userLatitude = (data['latitude'] as num).toDouble();
              if (data['longitude'] != null) _userLongitude = (data['longitude'] as num).toDouble();
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching address: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingAddress = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDeliveryEnabled = ref.watch(deliveryConfigProvider).value ?? true;
    final List<CartItemModel> selectedItems = widget.directItems ?? ref.watch(cartSelectedItemsProvider);
    final totalPrice = widget.directItems != null
        ? widget.directItems!.fold(0.0, (sum, item) => sum + item.totalPrice)
        : ref.watch(cartTotalPriceProvider);
    final totalSavings = widget.directItems != null
        ? widget.directItems!.fold(0.0, (sum, item) => sum + item.totalSavings)
        : ref.watch(cartTotalSavingsProvider);
    
    // Calculate dynamic delivery fee
    double deliveryFee = 0;
    bool isTooFar = false;
    if (_shippingMethod == 'delivery') {
      if (_userLatitude != null && _userLongitude != null && selectedItems.isNotEmpty) {
        final merchantLat = selectedItems.first.product.merchant?.latitude;
        final merchantLng = selectedItems.first.product.merchant?.longitude;
        if (merchantLat != null && merchantLng != null) {
          double distanceInMeters = Geolocator.distanceBetween(_userLatitude!, _userLongitude!, merchantLat, merchantLng);
          double distanceInKm = distanceInMeters / 1000;
          
          if (distanceInKm > 20) {
            isTooFar = true;
          }

          int kmCeil = distanceInKm.ceil();
          if (kmCeil < 1) kmCeil = 1;
          deliveryFee = kmCeil * 2500.0;
        } else {
          deliveryFee = 5000.0; // Fallback jika lokasi merchant tidak diketahui
        }
      } else {
        deliveryFee = 5000.0; // Fallback jika lokasi pembeli tidak diketahui
      }
    }
    
    const double adminFee = 1000.0;
    final double finalTotal = totalPrice + adminFee + (_shippingMethod == 'delivery' ? deliveryFee : 0);
    final isSaving = ref.watch(orderProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FBF9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  const SizedBox(height: 20),
                  _buildProductSection(selectedItems),
                  const SizedBox(height: 24),
                  _buildPaymentSection(),
                  const SizedBox(height: 24),
                  _buildShippingSection(selectedItems, isDeliveryEnabled),
                  const SizedBox(height: 24),
                  if (_shippingMethod == 'delivery') ...[
                    _buildAddressSection(),
                    const SizedBox(height: 24),
                  ],
                  _buildSummarySection(totalPrice, deliveryFee, adminFee, totalSavings, finalTotal, selectedItems.length),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomAction(finalTotal, selectedItems, isSaving, isTooFar),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
          const Text(
            'Konfirmasi Pesanan',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(SolarIconsBold.mapPoint, color: Colors.red.shade400, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Alamat Pengiriman',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: _isLoadingAddress
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF16A34A)))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userName ?? 'Nama tidak tersedia',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      (_userAddress == null || _userAddress!.isEmpty)
                          ? 'Alamat belum diatur. Silakan tambah alamat terlebih dahulu.'
                          : _userAddress!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: GestureDetector(
                        onTap: () async {
                          await context.push('/user-address');
                          _fetchUserAddress();
                        },
                        child: Text(
                          (_userAddress == null || _userAddress!.isEmpty) ? 'Tambah alamat' : 'Ganti alamat',
                          style: TextStyle(
                            fontSize: 13, 
                            fontWeight: FontWeight.w700, 
                            color: Colors.green.shade700
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildProductSection(List<CartItemModel> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(SolarIconsOutline.cart, color: Colors.grey, size: 18),
            const SizedBox(width: 8),
            Text(
              'Produk yang Diselamatkan (${items.length})',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFF1F1F1)),
            itemBuilder: (context, index) {
              final item = items[index];
              final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
              final discount = item.product.originalPrice != null && item.product.originalPrice! > 0
                ? ((item.product.originalPrice! - (item.product.price ?? 0)) / item.product.originalPrice! * 100).round()
                : 0;

              final isFood = item.product.category?.slug.toLowerCase() == 'makanan' || item.product.category?.name?.toLowerCase() == 'makanan';
              String expiryText = '';
              if (isFood && item.product.pickupEnd != null) {
                final now = DateTime.now();
                final endDateTime = DateTime(
                  now.year, now.month, now.day, 
                  item.product.pickupEnd!.hour, item.product.pickupEnd!.minute
                );
                final diff = endDateTime.difference(now);
                if (diff.isNegative) {
                  expiryText = 'Berakhir';
                } else {
                  final hours = diff.inHours;
                  final minutes = diff.inMinutes % 60;
                  if (hours > 0) {
                    expiryText = '${hours}j ${minutes}m lagi';
                  } else {
                    expiryText = '${minutes}m lagi';
                  }
                }
              }

              return Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      CloudinaryService.getOptimizedUrl(item.product.image ?? '', width: 100, height: 100),
                      width: 50, height: 50, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: Colors.grey.shade200, width: 50, height: 50),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.product.name ?? 'Produk',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${item.product.merchant?.storeName} - ×${item.quantity}',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (discount > 0) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(4)),
                                child: Text('-$discount%', style: const TextStyle(color: Color(0xFF2E7D32), fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                              const SizedBox(width: 6),
                            ],
                            if (expiryText.isNotEmpty) ...[
                              Icon(SolarIconsOutline.clockCircle, color: Colors.orange.shade400, size: 12),
                              const SizedBox(width: 2),
                              Text(expiryText, style: TextStyle(color: Colors.orange.shade400, fontSize: 10, fontWeight: FontWeight.w600)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(currencyFormat.format(item.totalPrice), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF2E7D32))),
                      if (item.product.originalPrice != null)
                        Text(currencyFormat.format(item.totalOriginalPrice), style: TextStyle(fontSize: 11, color: Colors.grey.shade400, decoration: TextDecoration.lineThrough)),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(SolarIconsOutline.wallet, color: Colors.grey, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Metode Pembayaran',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              _buildMethodOption(
                icon: SolarIconsOutline.banknote,
                title: 'Transfer Bank',
                subtitle: 'BCA / Mandiri / BRI',
                value: 'transfer',
                groupValue: _paymentMethod,
                onChanged: (val) => setState(() => _paymentMethod = val!),
              ),
              const Divider(height: 24, color: Color(0xFFF1F1F1)),
              _buildMethodOption(
                icon: SolarIconsOutline.scanner,
                title: 'QRIS',
                subtitle: 'Membayar dengan Scan QR',
                value: 'qris',
                groupValue: _paymentMethod,
                onChanged: (val) => setState(() => _paymentMethod = val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildShippingSection(List<CartItemModel> items, bool isDeliveryEnabled) {
    // Ambil alamat merchant pertama sebagai contoh pickup point
    final merchantAddress = items.isNotEmpty ? (items.first.product.merchant?.location ?? 'Alamat toko tidak tersedia') : '-';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(SolarIconsOutline.routing, color: Colors.grey, size: 18),
            const SizedBox(width: 8),
            const Text(
              'Pilihan pengiriman',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(
            children: [
              if (isDeliveryEnabled) ...[
                _buildMethodOption(
                  icon: SolarIconsOutline.routing,
                  title: 'LastBite Delivery',
                  subtitle: 'Driver tersedia!',
                  value: 'delivery',
                  groupValue: _shippingMethod,
                  onChanged: (val) => setState(() => _shippingMethod = val!),
                ),
                const Divider(height: 24, color: Color(0xFFF1F1F1)),
              ],
              _buildMethodOption(
                icon: SolarIconsOutline.shop,
                title: 'Ambil di Penjual',
                subtitle: merchantAddress,
                value: 'pickup',
                groupValue: _shippingMethod,
                onChanged: (val) => setState(() => _shippingMethod = val!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMethodOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String?> onChanged,
  }) {
    final bool isSelected = value == groupValue;

    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        color: Colors.transparent,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF1F8F1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: const Color(0xFF2E7D32), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? const Color(0xFF2E7D32) : Colors.grey.shade300, width: 2),
                color: isSelected ? const Color(0xFF2E7D32) : Colors.white,
              ),
              child: isSelected ? const Icon(SolarIconsOutline.checkCircle, color: Colors.white, size: 14) : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummarySection(double subtotal, double deliveryFee, double adminFee, double savings, double total, int count) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(SolarIconsOutline.bill, color: Colors.grey, size: 18),
              const SizedBox(width: 8),
              const Text('Ringkasan Pembayaran', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 20),
          _summaryRow('Subtotal ($count item)', currencyFormat.format(subtotal)),
          const SizedBox(height: 12),
          _summaryRow('Biaya Penanganan', currencyFormat.format(adminFee)),
          const SizedBox(height: 12),
          _summaryRow('Biaya Pengiriman', _shippingMethod == 'delivery' ? currencyFormat.format(deliveryFee) : 'Rp 0'),
          const SizedBox(height: 12),
          if (savings > 0) ...[
            _summaryRow('Total hemat hari ini', '-${currencyFormat.format(savings)}', isGreen: true),
            const Divider(height: 40, color: Color(0xFFF1F1F1)),
          ] else ...[
            const Divider(height: 40, color: Color(0xFFF1F1F1)),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total Bayar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              Text(
                currencyFormat.format(total),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF0F943B)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(SolarIconsOutline.leaf, color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Dengan pesanan ini, kamu mencegah ~420g sampah makanan!',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade900, fontWeight: FontWeight.w600, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, String value, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        Text(
          value, 
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.w700, 
            color: isGreen ? const Color(0xFF2E7D32) : Colors.black87
          )
        ),
      ],
    );
  }

  Widget _buildBottomAction(double total, List<CartItemModel> selectedItems, bool isSaving, bool isTooFar) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SizedBox(
        height: 56,
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isSaving ? null : () async {
            if (_shippingMethod == 'delivery' && isTooFar) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Jarak pengiriman terlalu jauh (>20 km). Silakan gunakan metode Ambil Sendiri atau perbarui alamat.'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            if (_shippingMethod == 'delivery' && (_userAddress == null || _userAddress!.isEmpty)) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Harap tambahkan alamat pengiriman terlebih dahulu.'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              return;
            }

            final isDirectCheckout = widget.directItems != null;
            final success = await ref.read(orderProvider.notifier).createOrder(
              items: selectedItems,
              totalPrice: total,
              paymentMethod: _paymentMethod,
              shippingMethod: _shippingMethod,
            );

            if (success) {
              ref.invalidate(userOrdersProvider);
              
              if (!isDirectCheckout) {
                await ref.read(cartProvider.notifier).removeSelected();
              }
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Pesanan berhasil dibuat!'),
                    backgroundColor: Color(0xFF2E7D32),
                  ),
                );
                context.go('/orders');
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Gagal membuat pesanan, coba lagi.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0F943B),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
            elevation: 0,
          ),
          child: isSaving
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Bayar Sekarang - ${currencyFormat.format(total)}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
        ),
      ),
    );
  }
}
