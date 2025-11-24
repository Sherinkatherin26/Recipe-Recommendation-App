import 'package:flutter/foundation.dart';
import '../../core/db/sqlite_db.dart';

class FavoritesProvider extends ChangeNotifier {
  final Set<String> _favoriteIds = {};


  FavoritesProvider() {
    loadDeviceFavorites();
  }


  /// Public: Load device-level favorites (for guest mode)
  Future<void> loadDeviceFavorites() async {
    try {
      _favoriteIds.clear();
      final ids = await LocalDatabase.instance.getFavorites();
      _favoriteIds.addAll(ids);
      notifyListeners();
    } catch (e) {
      debugPrint('FavoritesProvider.loadDeviceFavorites error: $e');
    }
  }

  /// Load favorites for logged-in user
  Future<void> loadFavoritesForUser(String email) async {
    try {
      _favoriteIds.clear();
      final ids = await LocalDatabase.instance.getUserFavorites(email);
      _favoriteIds.addAll(ids);
      notifyListeners();
    } catch (e) {
      debugPrint('FavoritesProvider.loadFavoritesForUser error: $e');
    }
  }

  /// Merge favorites of all people user follows → into current user's favorites
  Future<void> syncFavoritesFromFollowing(String email) async {
    try {
      final following = await LocalDatabase.instance.getFollowing(email);

      // Use Set to avoid duplicates
      final Set<String> merged = {};

      for (final f in following) {
        final favs = await LocalDatabase.instance.getUserFavorites(f);
        merged.addAll(favs);
      }

      // Insert merged favorites for current user
      for (final id in merged) {
        await LocalDatabase.instance.addUserFavorite(email, id);
        _favoriteIds.add(id);
      }

      notifyListeners();
    } catch (e) {
      debugPrint('FavoritesProvider.syncFavoritesFromFollowing error: $e');
    }
  }

  bool isFavorite(String recipeId) => _favoriteIds.contains(recipeId);

  /// Toggle favorite (supports both guest + authenticated users)
  Future<void> toggleFavorite(String recipeId, {String? userEmail}) async {
    final isFav = _favoriteIds.contains(recipeId);

    // Update UI immediately for responsiveness
    if (isFav) {
      _favoriteIds.remove(recipeId);
      notifyListeners();
    } else {
      _favoriteIds.add(recipeId);
      notifyListeners();
    }

    try {
      // GUEST MODE: store in device table
      if (userEmail == null || userEmail.isEmpty) {
        if (isFav) {
          await LocalDatabase.instance.removeFavorite(recipeId);
        } else {
          await LocalDatabase.instance.addFavorite(recipeId);
        }
        return;
      }

      // LOGGED-IN USER MODE: store per user
      if (isFav) {
        await LocalDatabase.instance.removeUserFavorite(userEmail, recipeId);
        await LocalDatabase.instance
            .addActivity(userEmail, 'removed_favorite:$recipeId');
      } else {
        await LocalDatabase.instance.addUserFavorite(userEmail, recipeId);
        await LocalDatabase.instance
            .addActivity(userEmail, 'added_favorite:$recipeId');
      }
    } catch (e) {
      debugPrint('FavoritesProvider.toggleFavorite error: $e');
    }
  }

  List<String> get favoriteIds => List.unmodifiable(_favoriteIds);

  void clear() {
    _favoriteIds.clear();
    notifyListeners();
  }
}
