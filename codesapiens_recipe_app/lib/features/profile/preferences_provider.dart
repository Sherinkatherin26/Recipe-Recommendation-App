import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Keys used to persist preferences
const _kPrefDarkMode = 'pref_dark_mode';
const _kPrefVegetarian = 'pref_vegetarian';
const _kPrefVegan = 'pref_vegan';
const _kPrefGlutenFree = 'pref_gluten_free';
const _kPrefNotifications = 'pref_notifications';
const _kPrefLanguage = 'pref_language';

class PreferencesProvider extends ChangeNotifier {
  PreferencesProvider() {
    // Load saved preferences (fire-and-forget)
    _loadFromPrefs();
  }

  // Theme preferences
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  // Dietary preferences
  bool _isVegetarian = false;
  bool _isVegan = false;
  bool _isGlutenFree = false;

  bool get isVegetarian => _isVegetarian;
  bool get isVegan => _isVegan;
  bool get isGlutenFree => _isGlutenFree;

  // Notification preferences
  bool _notificationsEnabled = true;
  bool get notificationsEnabled => _notificationsEnabled;

  // Language preference
  String _language = 'English';
  String get language => _language;

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_kPrefDarkMode) ?? _isDarkMode;
      _isVegetarian = prefs.getBool(_kPrefVegetarian) ?? _isVegetarian;
      _isVegan = prefs.getBool(_kPrefVegan) ?? _isVegan;
      _isGlutenFree = prefs.getBool(_kPrefGlutenFree) ?? _isGlutenFree;
      _notificationsEnabled =
          prefs.getBool(_kPrefNotifications) ?? _notificationsEnabled;
      _language = prefs.getString(_kPrefLanguage) ?? _language;
      notifyListeners();
    } catch (_) {
      // ignore prefs errors and keep defaults
    }
  }

  Future<void> _saveToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kPrefDarkMode, _isDarkMode);
      await prefs.setBool(_kPrefVegetarian, _isVegetarian);
      await prefs.setBool(_kPrefVegan, _isVegan);
      await prefs.setBool(_kPrefGlutenFree, _isGlutenFree);
      await prefs.setBool(_kPrefNotifications, _notificationsEnabled);
      await prefs.setString(_kPrefLanguage, _language);
    } catch (_) {
      // ignore write errors
    }
  }

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    _saveToPrefs();
  }

  void toggleVegetarian() {
    _isVegetarian = !_isVegetarian;
    notifyListeners();
    _saveToPrefs();
  }

  void toggleVegan() {
    _isVegan = !_isVegan;
    notifyListeners();
    _saveToPrefs();
  }

  void toggleGlutenFree() {
    _isGlutenFree = !_isGlutenFree;
    notifyListeners();
    _saveToPrefs();
  }

  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
    _saveToPrefs();
  }

  void setLanguage(String newLanguage) {
    _language = newLanguage;
    notifyListeners();
    _saveToPrefs();
  }
}
