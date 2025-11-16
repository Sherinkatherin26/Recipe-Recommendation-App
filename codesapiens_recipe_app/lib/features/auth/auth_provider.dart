import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';
import '../../core/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  // Signup: accept any email and register it in the database
  // Returns null on success, or an error message string on failure.
  Future<String?> signup(String name, String email, String password) async {
    // basic validation: email and password required; name optional (use email prefix if empty)
    if (email.isEmpty || password.isEmpty) return 'Missing email or password';
    
    final displayName = name.isEmpty ? (email.contains('@') ? email.split('@').first : 'User') : name;
    final normalized = email.trim();
    
    try {
      await ApiService.instance.signup(displayName, normalized, password);
      // backend returned token and user info
      _isAuthenticated = true;
      _userEmail = normalized;
      _userName = displayName;
      notifyListeners();
      return null;
    } catch (_) {
      // fallback to local DB if backend not reachable
      final added = await LocalDatabase.instance.addUser(displayName, normalized, password);
      if (!added) return 'Account already exists for this email';
      _isAuthenticated = true;
      _userEmail = normalized;
      _userName = displayName;
      notifyListeners();
      try {
        await LocalDatabase.instance.addActivity(normalized, 'signup');
      } catch (_) {}
      return null;
    }
  }

  // Login: verify email/password against registered users in database
  // Returns null on success, or an error message string on failure.
  Future<String?> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return 'Missing email or password';

    final normalized = email.trim();
    try {
      final data = await ApiService.instance.login(normalized, password);
      // store token is done by ApiService
      _isAuthenticated = true;
      _userEmail = normalized;
      _userName = data['name'] ?? normalized.split('@').first;
      try {
        await LocalDatabase.instance.addActivity(normalized, 'login');
      } catch (_) {}
      notifyListeners();
      return null;
    } catch (_) {
      // fallback to local DB
      final user = await LocalDatabase.instance.getUserByEmail(normalized);
      if (user == null) return 'Account does not exist';
      if (password != user['password']) return 'Incorrect password';
      _isAuthenticated = true;
      _userEmail = normalized;
      _userName = user['name'] ?? 'User';
      try {
        await LocalDatabase.instance.addActivity(normalized, 'login');
      } catch (_) {}
      notifyListeners();
      return null;
    }
  }

  // Mock logout
  Future<void> logout() async {
    try {
      await Future.delayed(
          const Duration(milliseconds: 500)); // Simulate network request
      _isAuthenticated = false;
      _userEmail = null;
      _userName = null;
      debugPrint('AuthProvider.logout: cleared authentication');
      // remove token from ApiService storage
      await ApiService.instance.setToken(null);
      notifyListeners();
    } catch (e) {
      // Handle logout error
      rethrow;
    }
  }
}
