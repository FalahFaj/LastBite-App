import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  // Singleton instance
  static final SupabaseService _instance = SupabaseService._internal();

  factory SupabaseService() {
    return _instance;
  }

  SupabaseService._internal();

  // Expose the Supabase client
  final SupabaseClient client = Supabase.instance.client;

  // You can add helper wrappers here in the future
  // Example: 
  // Future<void> signIn(String email, String password) async { ... }
}
