import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';
import '../../core/api_service.dart';

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
      // Try server-side favorites first (if authenticated/token present)
      try {
        final remote = await ApiService.instance.getFavorites();
        if (remote.isNotEmpty) {
          _favoriteIds.addAll(remote);
          notifyListeners();
          // also ensure local DB mirrors remote
          for (final id in remote) {
            await LocalDatabase.instance.addUserFavorite(email, id);
          }
          return;
        }
      } catch (_) {
        // remote failed - fallback to local DB
      }

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
  /// This method now awaits local DB writes to ensure persistence before
  /// operations like logout occur.
  Future<void> toggleFavorite(String recipeId, {String? userEmail}) async {
    final nowFavorite = !_favoriteIds.contains(recipeId);
    if (!nowFavorite) {
      _favoriteIds.remove(recipeId);
      try {
        // Try remote sync first when logged in
        if (userEmail != null) {
          try {
            await ApiService.instance.removeFavorite(recipeId);
          } catch (_) {}
        }
        if (userEmail == null) {
          await LocalDatabase.instance.removeFavorite(recipeId);
        } else {
          await LocalDatabase.instance.removeUserFavorite(userEmail, recipeId);
          // Backend automatically records this activity, but save locally as backup
          // (only if backend call failed above)
          try {
            await LocalDatabase.instance.addActivity(userEmail, 'removed_favorite:$recipeId');
          } catch (_) {}
        }
      } catch (_) {
        // ignore DB errors but keep in-memory state updated
      }
    } else {
      _favoriteIds.add(recipeId);
      try {
        // Try remote sync first when logged in
        if (userEmail != null) {
          try {
            await ApiService.instance.addFavorite(recipeId);
          } catch (_) {}
        }
        if (userEmail == null) {
          await LocalDatabase.instance.addFavorite(recipeId);
        } else {
          await LocalDatabase.instance.addUserFavorite(userEmail, recipeId);
          // Backend automatically records this activity, but save locally as backup
          // (only if backend call failed above)
          try {
            await LocalDatabase.instance.addActivity(userEmail, 'added_favorite:$recipeId');
          } catch (_) {}
        }
      } catch (_) {
        // ignore DB errors
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
