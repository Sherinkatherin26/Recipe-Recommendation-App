import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};

  FavoritesProvider() {
    _loadFavorites();
  }

  // Load device-level (legacy) favorites
  Future<void> _loadFavorites() async {
    try {
      final ids = await LocalDatabase.instance.getFavorites();
      _favoriteIds.addAll(ids);
      notifyListeners();
    } catch (_) {
      // Ignore DB errors and keep working in memory
    }
  }

  // Load favorites for a specific user (user-level favorites)
  Future<void> loadFavoritesForUser(String email) async {
    try {
      _favoriteIds.clear();
      final ids = await LocalDatabase.instance.getUserFavorites(email);
      _favoriteIds.addAll(ids);
      notifyListeners();
    } catch (_) {}
  }

  // Sync favorites for `email` by merging favorites from all users that `email` follows
  Future<void> syncFavoritesFromFollowing(String email) async {
    try {
      final following = await LocalDatabase.instance.getFollowing(email);
      final Set<String> merged = {};
      for (final f in following) {
        final favs = await LocalDatabase.instance.getUserFavorites(f);
        merged.addAll(favs);
      }

      // Add merged favorites to the user's favorites in DB and in-memory
      for (final id in merged) {
        await LocalDatabase.instance.addUserFavorite(email, id);
        _favoriteIds.add(id);
      }
      notifyListeners();
    } catch (_) {}
  }

  bool isFavorite(String recipeId) => _favoriteIds.contains(recipeId);

  /// Toggle favorite state. Optionally provide `userEmail` to record activity.
  /// This keeps the same (synchronous) signature so callers don't need to change.
  /// DB writes are fired and not awaited here; they are fast local operations.
  /// If you prefer awaiting DB writes, change this to return Future<void> and
  /// await LocalDatabase calls.
  void toggleFavorite(String recipeId, {String? userEmail}) {
    final nowFavorite = !_favoriteIds.contains(recipeId);
    if (!nowFavorite) {
      _favoriteIds.remove(recipeId);
      if (userEmail == null) {
        LocalDatabase.instance.removeFavorite(recipeId);
      } else {
        LocalDatabase.instance.removeUserFavorite(userEmail, recipeId);
      }
      // record activity
      if (userEmail != null) {
        try {
          LocalDatabase.instance
              .addActivity(userEmail, 'removed_favorite:$recipeId');
        } catch (_) {}
      }
    } else {
      _favoriteIds.add(recipeId);
      if (userEmail == null) {
        LocalDatabase.instance.addFavorite(recipeId);
      } else {
        LocalDatabase.instance.addUserFavorite(userEmail, recipeId);
      }
      if (userEmail != null) {
        try {
          LocalDatabase.instance
              .addActivity(userEmail, 'added_favorite:$recipeId');
        } catch (_) {}
      }
    }
    notifyListeners();
  }

  List<String> get favoriteIds => _favoriteIds.toList();

  /// Clear in-memory favorites (used on logout to reset user-specific state)
  void clear() {
    _favoriteIds.clear();
    notifyListeners();
  }
}
