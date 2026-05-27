import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/core/models/cart_item_model.dart';
import 'package:lastbite/core/services/supabase_service.dart';

class OrderNotifier extends Notifier<bool> {
  final _supabase = SupabaseService().client;

  @override
  bool build() {
    return false; // Mengembalikan status loading (false = tidak sedang loading)
  }

  /// Membuat pesanan baru menggunakan fungsi RPC 'create_order' di Supabase
  Future<bool> createOrder({
    required List<CartItemModel> items,
    required double totalPrice,
    required String paymentMethod,
    required String shippingMethod,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    state = true; // Set loading to true

    try {
      // 1. Format items menjadi List of Map (JSON)
      final List<Map<String, dynamic>> jsonItems = items.map((item) {
        return {
          'product_id': item.product.id,
          'quantity': item.quantity,
          'price': item.product.price ?? 0,
        };
      }).toList();

      // 2. Panggil RPC
      final orderId = await _supabase.rpc('create_order', params: {
        'p_buyer_id': user.id,
        'p_total_price': totalPrice,
        'p_payment_method': paymentMethod,
        'p_delivery_method': shippingMethod,
        'p_items': jsonItems,
      });

      print('Order berhasil dibuat dengan ID: $orderId');
      state = false;
      return true;
    } catch (e) {
      print('Error creating order: $e');
      state = false;
      return false;
    }
  }
}

final orderProvider = NotifierProvider<OrderNotifier, bool>(() {
  return OrderNotifier();
});
