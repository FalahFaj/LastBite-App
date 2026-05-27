import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static final LocalStorageService _instance = LocalStorageService._internal();

  factory LocalStorageService() {
    return _instance;
  }

  LocalStorageService._internal();

  // Box name constants
  static const String authBoxName = 'auth_box';

  // Getter for auth box
  Box get authBox => Hive.box(authBoxName);

  // Helper methodologies for common operations
  Future<void> saveToken(String token) async {
    await authBox.put('auth_token', token);
  }

  String? getToken() {
    return authBox.get('auth_token');
  }

  Future<void> clearAuth() async {
    await authBox.delete('auth_token');
  }
}
