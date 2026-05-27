import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastbite/core/models/order_model.dart';
import 'package:lastbite/core/services/supabase_service.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class UserOrdersNotifier extends Notifier<AsyncValue<List<OrderModel>>> {
  final _supabase = SupabaseService().client;
  RealtimeChannel? _subscription;

  @override
  AsyncValue<List<OrderModel>> build() {
    _fetchOrders();
    _setupSubscription();

    ref.onDispose(() {
      _subscription?.unsubscribe();
    });

    return const AsyncValue.loading();
  }

  void _setupSubscription() {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    _subscription = _supabase.channel('public:orders:buyer_${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'orders',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'buyer_id',
          value: user.id,
        ),
        callback: (payload) {
          _fetchOrders();
        },
      )
      .subscribe();
  }

  Future<void> _fetchOrders() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      state = const AsyncValue.data([]);
      return;
    }

    try {
      final response = await _supabase
          .from('orders')
          .select('*, order_items(*, products(*, merchants(*))), payments(*)')
          .eq('buyer_id', user.id)
          .order('created_at', ascending: false);

      final now = DateTime.now();
      final List<OrderModel> orders = [];

      for (final json in (response as List)) {
        OrderModel order = OrderModel.fromJson(json);
        
        // Auto-cancel logic if payment is expired (> 60 minutes)
        if (order.status == 'pending_payment' && order.createdAt != null) {
          final expiryTime = order.createdAt!.add(const Duration(minutes: 60));
          if (now.isAfter(expiryTime)) {
            // Update model locally
            order = order.copyWith(status: 'cancelled');
            
            // Fire and forget update to Supabase
            _supabase.from('orders')
                .update({'status': 'cancelled'})
                .eq('id', order.id)
                .eq('status', 'pending_payment')
                .then((_) => null)
                .catchError((e) => print('Error auto-cancelling in provider: $e'));
          }
        }
        
        // Auto-complete logic if picked_up is > 2 hours
        if (order.status == 'picked_up' && order.pickedUpAt != null) {
          final completeTime = order.pickedUpAt!.add(const Duration(hours: 2));
          if (now.isAfter(completeTime)) {
            // Update model locally
            order = order.copyWith(status: 'completed');
            
            // Fire and forget update to Supabase
            _supabase.from('orders')
                .update({'status': 'completed'})
                .eq('id', order.id)
                .eq('status', 'picked_up')
                .then((_) => null)
                .catchError((e) => print('Error auto-completing in provider: $e'));
          }
        }
        orders.add(order);
      }

      state = AsyncValue.data(orders);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    await _fetchOrders();
  }
}

final userOrdersProvider = NotifierProvider<UserOrdersNotifier, AsyncValue<List<OrderModel>>>(() {
  return UserOrdersNotifier();
});
