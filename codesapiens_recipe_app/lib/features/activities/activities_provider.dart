import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';

class ActivitiesProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _activities = [];

  List<Map<String, dynamic>> get activities => List.unmodifiable(_activities);

  Future<void> loadActivitiesForUser(String email) async {
    try {
      _activities.clear();
      final rows = await LocalDatabase.instance.getActivities(email);
      // Annotate own activities with the user's email for consistent items
      final normalized = email.trim().toLowerCase();
      for (final r in rows) {
        _activities.add({'email': normalized, 'activity': r['activity'], 'timestamp': r['timestamp']});
      }
      notifyListeners();
    } catch (e) {
      debugPrint('ActivitiesProvider.loadActivitiesForUser error: $e');
    }
  }

  /// Merge activities from users that [email] is following into the
  /// in-memory activity feed. This does not write merged activities to the DB;
  /// it only composes a feed for the currently authenticated user.
  Future<void> syncActivitiesFromFollowing(String email) async {
    try {
      final following = await LocalDatabase.instance.getFollowing(email);
      final List<Map<String, dynamic>> merged = List.from(_activities);
      for (final f in following) {
        final rows = await LocalDatabase.instance.getActivities(f);
        for (final r in rows) {
          // annotate activity with the actor email
          final item = {
            'email': f,
            'activity': r['activity'],
            'timestamp': r['timestamp']
          };
          // avoid duplicates by timestamp+activity+email
          final exists = merged.any((m) =>
              m['email'] == item['email'] &&
              m['activity'] == item['activity'] &&
              m['timestamp'] == item['timestamp']);
          if (!exists) merged.add(item);
        }
      }

      // sort by timestamp descending
      merged.sort((a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));

      _activities
        ..clear()
        ..addAll(merged);
      notifyListeners();
    } catch (e) {
      debugPrint('ActivitiesProvider.syncActivitiesFromFollowing error: $e');
    }
  }

  void clear() {
    _activities.clear();
    notifyListeners();
  }
}
