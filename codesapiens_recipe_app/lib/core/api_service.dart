// Offline mode: ApiService is a harmless stub to avoid compile errors if some
// files still import it. Do not use for networking in offline-only mode.
class ApiService {
  ApiService._private();
  static final ApiService instance = ApiService._private();

  // keep the field so older code that sets baseUrl won't crash
  String baseUrl = '';

  Future<void> setToken(String? token) async {
    // no-op in offline mode
  }

  // If any code accidentally calls these, throw a clear error so we can find it.
  Never _error() => throw UnsupportedError(
      'ApiService is disabled in offline-only mode. Remove network calls.');

  Future<T> _never<T>() => Future<T>.error(_error());

  Future<Map<String, dynamic>> login(String email, String password) => _never();
  Future<Map<String, dynamic>> signup(String name, String email, String password) =>
      _never();
  Future<List<String>> getFavorites() => _never();
  Future<void> addFavorite(String id) => _never();
  Future<void> removeFavorite(String id) => _never();
  Future<List<Map<String, dynamic>>> getActivities({int limit = 100}) => _never();
  Future<void> addActivity(String activity, {int? timestamp}) => _never();
  Future<bool> validateToken() => _never();
}
