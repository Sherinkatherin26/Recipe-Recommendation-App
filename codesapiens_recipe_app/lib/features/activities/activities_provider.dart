import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';
import '../../core/api_service.dart';

class ActivitiesProvider extends ChangeNotifier {
  final List<Map<String, dynamic>> _activities = [];

  List<Map<String, dynamic>> get activities => List.unmodifiable(_activities);

  Future<void> loadActivitiesForUser(String email) async {
    try {
      _activities.clear();
      // Always try backend first - even if empty, backend is the source of truth
      try {
        final remote = await ApiService.instance.getActivities();
        // Annotate activities with the user's email for consistent items
        final normalized = email.trim().toLowerCase();
        for (final r in remote) {
          _activities.add({
            'email': normalized,
            'activity': r['activity'] as String,
            'timestamp': r['timestamp'] as int
          });
        }
        notifyListeners();
        // Also sync to local DB for offline access (but backend is source of truth)
        for (final r in remote) {
          try {
            await LocalDatabase.instance.addActivity(
                email, r['activity'] as String);
          } catch (_) {}
        }
        return; // Backend succeeded, use it (even if empty)
      } catch (_) {
        // Backend failed, fallback to local DB
      }
      
      // Fallback to local DB only if backend is unavailable
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

  /// Sync local activities to backend before logout
  Future<void> syncLocalActivitiesToBackend(String email) async {
    try {
      // Get local activities that might not be in backend
      final localActivities = await LocalDatabase.instance.getActivities(email);
      
      // Get backend activities to check what's already there
      try {
        final backendActivities = await ApiService.instance.getActivities();
        final backendSet = backendActivities.map((a) => 
          '${a['activity']}_${a['timestamp']}').toSet();
        
        // Upload local activities that aren't in backend
        for (final local in localActivities) {
          final key = '${local['activity']}_${local['timestamp']}';
          if (!backendSet.contains(key)) {
            try {
              await ApiService.instance.addActivity(
                local['activity'] as String,
                timestamp: local['timestamp'] as int
              );
            } catch (_) {
              // Continue with other activities if one fails
            }
          }
        }
      } catch (_) {
        // Backend not available, activities will remain in local DB
      }
    } catch (e) {
      debugPrint('ActivitiesProvider.syncLocalActivitiesToBackend error: $e');
    }
  }

  void clear() {
    _activities.clear();
    notifyListeners();
  }
}
