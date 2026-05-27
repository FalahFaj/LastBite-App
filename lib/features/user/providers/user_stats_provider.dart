import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lastbite/core/models/user_stats_model.dart';

final userStatsProvider = FutureProvider<UserStats>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return UserStats(totalPortions: 0, totalSavings: 0);

  // Dapatkan awal bulan ini
  final now = DateTime.now();
  final monthStart = DateTime(now.year, now.month, 1).toUtc().toIso8601String();

  // Ambil pesanan yang sudah selesai (completed) untuk user ini di bulan ini
  final response = await supabase
      .from('orders')
      .select('id, order_items(quantity, price, products(original_price))')
      .eq('buyer_id', user.id)
      .eq('status', 'completed')
      .gte('created_at', monthStart);

  int totalPortions = 0;
  double totalSavings = 0;

  final List orders = response as List;
  for (final order in orders) {
    final List items = order['order_items'] as List? ?? [];
    for (final item in items) {
      final qty = (item['quantity'] as int? ?? 0);
      final price = (item['price'] as num? ?? 0).toDouble();
      
      // Ambil original_price dari produk, jika null gunakan price (berarti tidak ada diskon)
      final product = item['products'] as Map?;
      final originalPrice = (product?['original_price'] as num? ?? price).toDouble();
      
      totalPortions += qty;
      totalSavings += (originalPrice - price) * qty;
    }
  }

  return UserStats(totalPortions: totalPortions, totalSavings: totalSavings);
});
