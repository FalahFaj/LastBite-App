import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final deliveryConfigProvider = FutureProvider.autoDispose<bool>((ref) async {
  try {
    final response = await Supabase.instance.client
        .from('app_configs')
        .select('value')
        .eq('key', 'is_delivery_enabled')
        .maybeSingle();

    if (response != null && response['value'] != null) {
      final value = response['value'].toString().toLowerCase();
      return value == 'true';
    }
  } catch (e) {
    if (kDebugMode) {
      print('Error fetching delivery config: $e');
    }
  }
  return true; // default to true if missing
});
