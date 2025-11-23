import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';

class ActivitiesProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _activities = [];

  List<Map<String, dynamic>> get activities => List.unmodifiable(_activities);

  Future<void> loadActivitiesForUser(String email) async {
    try {
      _activities.clear();
      final rows = await LocalDatabase.instance.getActivities(email);
      final normalized = email.trim().toLowerCase();
      for (final r in rows) {
        _activities.add({'email': normalized, 'activity': r['activity'], 'timestamp': r['timestamp']});
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ActivitiesProvider.loadActivitiesForUser error: $e');
    }
  }

  Future<void> syncActivitiesFromFollowing(String email) async {
    try {
      final following = await LocalDatabase.instance.getFollowing(email);
      final List<Map<String, dynamic>> merged = List.from(_activities);
      for (final f in following) {
        final rows = await LocalDatabase.instance.getActivities(f);
        for (final r in rows) {
          final item = {'email': f, 'activity': r['activity'], 'timestamp': r['timestamp']};
          final exists = merged.any((m) =>
              m['email'] == item['email'] &&
              m['activity'] == item['activity'] &&
              m['timestamp'] == item['timestamp']);
          if (!exists) merged.add(item);
        }
      }
      merged.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
      _activities
        ..clear()
        ..addAll(merged);
      notifyListeners();
    } catch (e) {
      debugPrint('ActivitiesProvider.syncActivitiesFromFollowing error: $e');
    }
  }

  Future<void> syncLocalActivitiesToBackend(String email) async {
    // offline-only mode: nothing to push. Keep method for compatibility.
    return;
  }

  void clear() {
    _activities.clear();
    notifyListeners();
  }
}
