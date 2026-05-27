import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final merchantProvider = AsyncNotifierProvider<MerchantNotifier, void>(() {
  return MerchantNotifier();
});

class MerchantNotifier extends AsyncNotifier<void> {
  final _supabase = Supabase.instance.client;

  @override
  Future<void> build() async {}

  Future<void> registerMerchant({
    required String storeName,
    required String category,
    required String locationName,
    required String ownerName,
    required String officePhone,
    required String password,
    required double latitude,
    required double longitude,
  }) async {
    state = const AsyncValue.loading();
    
    final currentUser = _supabase.auth.currentUser;
    if (currentUser == null) {
      state = AsyncValue.error('Anda harus login terlebih dahulu.', StackTrace.current);
      return;
    }

    try {
      final email = currentUser.email;
      if (email == null) throw 'Alamat Email tidak ditemukan dalam sesi Anda.';

      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      // 2. Prepare merchant data dictionary for insertion
      final merchantPayload = {
        'user_id': currentUser.id,
        'store_name': storeName,
        'category': category,
        'owner_name': ownerName,
        'office_phone': officePhone,
        'location': locationName,
        'latitude': latitude,
        'longitude': longitude,
      };

      // 3. Insert into merchants table
      await _supabase.from('merchants').insert(merchantPayload);

      // Successfully registered as merchant
      state = const AsyncValue.data(null);

    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid credentials') || e.message.toLowerCase().contains('invalid login credentials')) {
        state = AsyncValue.error('Password yang Anda masukkan salah. Registrasi Mitra dibatalkan.', StackTrace.current);
      } else {
        state = AsyncValue.error(e.message, StackTrace.current);
      }
    } catch (e, stack) {
      state = AsyncValue.error('Gagal memproses data: ${e.toString()}', stack);
    }
  }
}
