import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';

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
    
    // Try to register the user in the database
    final added = await LocalDatabase.instance.addUser(displayName, normalized, password);
    if (!added) return 'Account already exists for this email';
    
    // Set authenticated state
    _isAuthenticated = true;
    _userEmail = normalized;
    _userName = displayName;
    debugPrint('AuthProvider.signup: authenticated user=$normalized name=$displayName');
    notifyListeners();
    
    // Record signup activity
    try {
      await LocalDatabase.instance.addActivity(normalized, 'signup');
    } catch (_) {}
    return null;
  }

  // Login: verify email/password against registered users in database
  // Returns null on success, or an error message string on failure.
  Future<String?> login(String email, String password) async {
    if (email.isEmpty || password.isEmpty) return 'Missing email or password';

    final normalized = email.trim();
    
    // Look up user in database
    final user = await LocalDatabase.instance.getUserByEmail(normalized);
    if (user == null) {
      // Account not found — prompt user to sign up
      return 'Account does not exist';
    }

    // Verify password
    if (password != user['password']) {
      return 'Incorrect password';
    }

    // Password matches — set authenticated state
    _isAuthenticated = true;
    _userEmail = normalized;
    _userName = user['name'] ?? 'User';
    debugPrint('AuthProvider.login: set authenticated for $normalized name=${_userName}');
    
    // Record login activity
    try {
      await LocalDatabase.instance.addActivity(normalized, 'login');
    } catch (_) {}
    
    notifyListeners();
    debugPrint('AuthProvider.login: notifyListeners called');
    return null;
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
      notifyListeners();
    } catch (e) {
      // Handle logout error
      rethrow;
    }
  }
}
