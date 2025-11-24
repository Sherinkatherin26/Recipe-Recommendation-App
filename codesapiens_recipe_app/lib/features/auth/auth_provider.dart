// lib/features/auth/auth_provider.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/db/sqlite_db.dart';
import '../../core/api_service.dart';

class AuthProvider extends ChangeNotifier {
  static const _kCurrentUserKey = 'codesapiens_current_user';

  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;

  AuthProvider() {
    _restoreSession();
  }

  Future<void> _persistCurrentUser(String? email) async {
    final prefs = await SharedPreferences.getInstance();
    if (email == null) {
      await prefs.remove(_kCurrentUserKey);
    } else {
      await prefs.setString(_kCurrentUserKey, email);
    }
  }

  /// Use local SQLite for signup. Returns null on success, or error string.
  Future<String?> signup(String name, String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) return 'Missing email or password';
    final displayName = (name.isEmpty) ? (normalized.contains('@') ? normalized.split('@').first : 'User') : name;
    // If user exists locally -> error
    final exists = await LocalDatabase.instance.userExists(normalized);
    if (exists) return 'This email is already registered';
    final added = await LocalDatabase.instance.addUser(displayName, normalized, password);
    if (!added) return 'Failed to create account';
    _isAuthenticated = true;
    _userEmail = normalized;
    _userName = displayName;
    await _persistCurrentUser(normalized);
    // record signup activity
    await LocalDatabase.instance.addActivity(normalized, 'signup');
    notifyListeners();
    return null;
  }

  /// Login offline against SQLite users. Returns null on success else error.
  Future<String?> login(String email, String password) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || password.isEmpty) return 'Missing email or password';
    try {
      final user = await LocalDatabase.instance.getUserByEmail(normalized);
      if (user == null) return 'Account does not exist';
      if (user['password'] != password) return 'Incorrect password';
      _isAuthenticated = true;
      _userEmail = normalized;
      _userName = user['name'] ?? normalized.split('@').first;
      await _persistCurrentUser(normalized);
      await LocalDatabase.instance.addActivity(normalized, 'login');
      notifyListeners();
      return null;
    } catch (e) {
      return 'Error during login: ${e.toString()}';
    }
  }

  /// Update profile fields locally (name, password). Returns null or error.
  Future<String?> updateProfile({String? name, String? password}) async {
    if (_userEmail == null) return 'Not authenticated';
    final success = await LocalDatabase.instance.updateUser(_userEmail!, name: name, password: password);
    if (!success) return 'Failed to update profile';
    if (name != null) _userName = name;
    await LocalDatabase.instance.addActivity(_userEmail!, 'update_profile');
    notifyListeners();
    return null;
  }

  /// Validate token / session. Returns true if session is valid.
  ///
  /// Behavior:
  /// 1. Try ApiService.validateToken() (best-effort). If it returns true,
  ///    try to restore user info from SharedPreferences/local DB.
  /// 2. If backend call fails or returns false, fall back to local SharedPreferences
  ///    + LocalDatabase user lookup.
  Future<bool> validateToken() async {
    try {
      // Try backend first (if available). ApiService.validateToken is best-effort.
      final backendOk = await ApiService.instance.validateToken().catchError((_) => false);
      if (backendOk) {
        // If backend token valid, attempt to restore user from prefs/local DB
        final prefs = await SharedPreferences.getInstance();
        final savedEmail = prefs.getString(_kCurrentUserKey);
        if (savedEmail != null) {
          final user = await LocalDatabase.instance.getUserByEmail(savedEmail);
          if (user != null) {
            _isAuthenticated = true;
            _userEmail = user['email'];
            _userName = user['name'];
            notifyListeners();
            return true;
          } else {
            // backend valid but we don't have local user: keep not authenticated
            _isAuthenticated = false;
            _userEmail = null;
            _userName = null;
            notifyListeners();
            return true; // token valid but no local user — still a valid token state
          }
        }
        // no saved user, but token valid
        _isAuthenticated = true;
        notifyListeners();
        return true;
      }
    } catch (_) {
      // ignore backend errors and fall back
    }

    // Fallback: restore from local prefs + local DB
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedEmail = prefs.getString(_kCurrentUserKey);
      if (savedEmail != null) {
        final user = await LocalDatabase.instance.getUserByEmail(savedEmail);
        if (user != null) {
          _isAuthenticated = true;
          _userEmail = user['email'];
          _userName = user['name'];
          notifyListeners();
          return true;
        }
      }
    } catch (_) {
      // ignore
    }

    // No valid session
    _isAuthenticated = false;
    _userEmail = null;
    _userName = null;
    notifyListeners();
    return false;
  }

  /// Logout: clear local session
  Future<void> logout() async {
    _isAuthenticated = false;
    _userEmail = null;
    _userName = null;
    await _persistCurrentUser(null);
    notifyListeners();
  }

  /// Restore session from shared prefs (initial load)
  Future<void> _restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString(_kCurrentUserKey);
      if (email != null) {
        final user = await LocalDatabase.instance.getUserByEmail(email);
        if (user != null) {
          _isAuthenticated = true;
          _userEmail = user['email'];
          _userName = user['name'];
        } else {
          _isAuthenticated = false;
          _userEmail = null;
          _userName = null;
        }
      }
    } catch (_) {
      _isAuthenticated = false;
      _userEmail = null;
      _userName = null;
    }
    notifyListeners();
  }
}
