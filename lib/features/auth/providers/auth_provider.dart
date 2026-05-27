import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:lastbite/core/services/supabase_service.dart';
import 'package:lastbite/core/services/local_storage_service.dart';
import 'package:lastbite/core/services/notification_service.dart';
import 'dart:async';

// Stream provider to globally listen to Supabase Authentication changes
final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService().client.auth.onAuthStateChange;
});

// Provides the current user instance from Supabase
final currentUserProvider = Provider<User?>((ref) {
  return SupabaseService().client.auth.currentUser;
});

class AuthNotifier extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {
    // Initial state is void
  }

  Future<void> login(String email, String password) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final response = await SupabaseService().client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      // Save token to Hive as backup or for other custom offline use
      final session = response.session;
      if (session != null) {
        await LocalStorageService().saveToken(session.accessToken);
        await NotificationService.updateToken();
      }
    });
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      
      final dynamic emailResponse = await SupabaseService().client.rpc(
        'check_email_exists', 
        params: {'lookup_email': email}
      );
      if (emailResponse == true) throw Exception('already_registered');

      final dynamic phoneResponse = await SupabaseService().client.rpc(
        'check_phone_exists', 
        params: {'lookup_phone': phone}
      );
      if (phoneResponse == true) throw Exception('unique_phone');

      await SupabaseService().client.auth.signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
        },
      );

      // Token will be updated automatically on next login, 
      // but if the user is automatically logged in after sign up:
      await NotificationService.updateToken();
    });
  }

  Future<void> logout() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await SupabaseService().client.auth.signOut();
      await LocalStorageService().clearAuth();
    });
  }
}

final authNotifierProvider = AsyncNotifierProvider<AuthNotifier, void>(() {
  return AuthNotifier();
});
