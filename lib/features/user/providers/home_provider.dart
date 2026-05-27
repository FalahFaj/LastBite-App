import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/core/models/category_model.dart';
import 'package:lastbite/core/models/product_model.dart';
import 'package:lastbite/core/models/user_model.dart';
import 'package:lastbite/core/services/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ── Kategori ──────────────────────────────────────────────────────────────
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final response = await SupabaseService().client
      .from('categories')
      .select()
      .order('created_at', ascending: true);
  return (response as List).map((e) => CategoryModel.fromJson(e)).toList();
});

// ── Produk Tersedia (Realtime Auto-Refresh) ────────────────────────────────
class ProductsNotifier extends AsyncNotifier<List<ProductModel>> {
  RealtimeChannel? _channel;

  @override
  Future<List<ProductModel>> build() async {
    // Subscribe realtime — dibersihkan otomatis saat provider di-dispose
    _subscribeRealtime();
    ref.onDispose(() => _channel?.unsubscribe());
    return _fetchProducts();
  }

  Future<List<ProductModel>> _fetchProducts() async {
    final response = await SupabaseService().client
        .from('products')
        .select('*, merchants(*), categories(*)')
        .eq('status', 'available')
        .order('created_at', ascending: false);
    return (response as List).map((e) => ProductModel.fromJson(e)).toList();
  }

  void _subscribeRealtime() {
    _channel = SupabaseService()
        .client
        .channel('products-changes-buyer')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'products',
          callback: (_) {
            // Setiap INSERT / UPDATE / DELETE → refresh state
            state = const AsyncLoading();
            _fetchProducts().then((data) {
              state = AsyncData(data);
            }).catchError((e, st) {
              state = AsyncError(e, st);
            });
          },
        )
        .subscribe();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetchProducts);
  }
}

final availableProductsProvider =
    AsyncNotifierProvider<ProductsNotifier, List<ProductModel>>(
  ProductsNotifier.new,
);

// ── Cek Merchant ──────────────────────────────────────────────────────────
final isMerchantProvider = FutureProvider<bool>((ref) async {
  final user = SupabaseService().client.auth.currentUser;
  if (user == null) return false;
  final response = await SupabaseService().client
      .from('merchants')
      .select('id')
      .eq('user_id', user.id)
      .maybeSingle();
  return response != null;
});

final userProfileProvider = FutureProvider<UserModel?>((ref) async {
  final user = SupabaseService().client.auth.currentUser;
  if (user == null) return null;

  final response = await SupabaseService().client
      .from('users')
      .select()
      .eq('id', user.id)
      .maybeSingle();

  if (response == null) return null;
  return UserModel.fromJson(response);
});
