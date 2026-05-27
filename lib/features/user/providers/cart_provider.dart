import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/core/models/cart_item_model.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:lastbite/core/services/supabase_service.dart';

class CartNotifier extends Notifier<List<CartItemModel>> {
  final _supabase = SupabaseService().client;

  @override
  List<CartItemModel> build() {
    _loadCart();
    return [];
  }

  Future<void> _loadCart() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await _supabase
          .from('cart')
          .select('*, products(*, merchants(*), categories(*))')
          .eq('user_id', user.id);

      final List<CartItemModel> items = (response as List).map((e) {
        return CartItemModel(
          product: ProductModel.fromJson(e['products']),
          quantity: e['quantity'] as int,
          isSelected: true, // Default selected saat load
        );
      }).toList();

      state = items;
    } catch (e) {
      // Handle error (bisa tambahkan logging)
      print('Error loading cart: $e');
    }
  }

  Future<void> addToCart(ProductModel product) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Optimistic Update: Tambah di UI dulu biar cepat
    final existingIndex = state.indexWhere((item) => item.product.id == product.id);
    if (existingIndex != -1) {
      state = [
        for (int i = 0; i < state.length; i++)
          if (i == existingIndex)
            state[i].copyWith(quantity: state[i].quantity + 1)
          else
            state[i],
      ];
    } else {
      state = [...state, CartItemModel(product: product)];
    }

    try {
      // Panggil RPC
      await _supabase.rpc('add_to_cart', params: {
        'p_product_id': product.id,
        'p_quantity': 1,
      });
    } catch (e) {
      print('Error adding to cart: $e');
      _loadCart();
    }
  }

  Future<void> removeFromCart(String productId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // UI Update
    state = state.where((item) => item.product.id != productId).toList();

    try {
      await _supabase
          .from('cart')
          .delete()
          .eq('user_id', user.id)
          .eq('product_id', productId);
    } catch (e) {
      print('Error removing from cart: $e');
      _loadCart();
    }
  }

  Future<void> updateQuantity(String productId, int quantity) async {
    if (quantity <= 0) {
      removeFromCart(productId);
      return;
    }

    final user = _supabase.auth.currentUser;
    if (user == null) return;

    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(quantity: quantity)
        else
          item,
    ];

    try {
      await _supabase
          .from('cart')
          .update({'quantity': quantity})
          .eq('user_id', user.id)
          .eq('product_id', productId);
    } catch (e) {
      print('Error updating quantity: $e');
      _loadCart();
    }
  }

  void toggleSelection(String productId) {
    state = [
      for (final item in state)
        if (item.product.id == productId)
          item.copyWith(isSelected: !item.isSelected)
        else
          item,
    ];
  }

  void toggleMerchantSelection(String merchantId, bool selected) {
    state = [
      for (final item in state)
        if (item.product.merchantId == merchantId)
          item.copyWith(isSelected: selected)
        else
          item,
    ];
  }

  void toggleAll(bool selected) {
    state = state.map((item) => item.copyWith(isSelected: selected)).toList();
  }

  Future<void> clearCart() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    state = [];

    try {
      await _supabase.from('cart').delete().eq('user_id', user.id);
    } catch (e) {
      print('Error clearing cart: $e');
      _loadCart();
    }
  }

  Future<void> removeSelected() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final selectedIds = state.where((item) => item.isSelected).map((item) => item.product.id).toList();
    if (selectedIds.isEmpty) return;

    // UI Update
    state = state.where((item) => !item.isSelected).toList();

    try {
      await _supabase
          .from('cart')
          .delete()
          .eq('user_id', user.id)
          .filter('product_id', 'in', selectedIds);
    } catch (e) {
      print('Error removing selected: $e');
      _loadCart();
    }
  }
}

final cartProvider = NotifierProvider<CartNotifier, List<CartItemModel>>(() {
  return CartNotifier();
});

final cartTotalItemsProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).length;
});

final cartSelectedItemsProvider = Provider<List<CartItemModel>>((ref) {
  return ref.watch(cartProvider).where((item) => item.isSelected).toList();
});

final cartTotalPriceProvider = Provider<double>((ref) {
  final selectedItems = ref.watch(cartSelectedItemsProvider);
  return selectedItems.fold(0, (sum, item) => sum + item.totalPrice);
});

final cartTotalSavingsProvider = Provider<double>((ref) {
  final selectedItems = ref.watch(cartSelectedItemsProvider);
  return selectedItems.fold(0, (sum, item) => sum + item.totalSavings);
});
