import 'package:flutter/foundation.dart';

class PreferencesProvider extends ChangeNotifier {
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

  void toggleDarkMode() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void toggleVegetarian() {
    _isVegetarian = !_isVegetarian;
    notifyListeners();
  }

  void toggleVegan() {
    _isVegan = !_isVegan;
    notifyListeners();
  }

  void toggleGlutenFree() {
    _isGlutenFree = !_isGlutenFree;
    notifyListeners();
  }

  void toggleNotifications() {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
  }

  void setLanguage(String newLanguage) {
    _language = newLanguage;
    notifyListeners();
  }
}
