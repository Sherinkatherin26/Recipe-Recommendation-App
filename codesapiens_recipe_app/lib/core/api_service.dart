import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  ApiService._private();
  static final ApiService instance = ApiService._private();

  // Default to emulator localhost. Change to your machine IP when testing on a
  // physical device (e.g. http://192.168.1.12:5000)
  String baseUrl = 'http://10.0.2.2:5000';

  static const _kTokenKey = 'api_auth_token';

  Future<void> setToken(String? token) async {
    final prefs = await SharedPreferences.getInstance();
    if (token == null) {
      await prefs.remove(_kTokenKey);
    } else {
      await prefs.setString(_kTokenKey, token);
    }
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kTokenKey);
  }

  Map<String, String> _authHeaders(String? token) => token == null
      ? {'Content-Type': 'application/json'}
      : {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};

  Future<Map<String, dynamic>> signup(
      String name, String email, String password) async {
    final url = Uri.parse('$baseUrl/signup');
    final res = await http.post(url,
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
        headers: {'Content-Type': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token != null) await setToken(token);
      return data;
    }
    throw Exception('Signup failed: ${res.body}');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final res = await http.post(url,
        body: jsonEncode({'email': email, 'password': password}),
        headers: {'Content-Type': 'application/json'});
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final token = data['access_token'] as String?;
      if (token != null) await setToken(token);
      return data;
    }
    throw Exception('Login failed: ${res.body}');
  }

  Future<List<String>> getFavorites() async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/favorites');
    final res = await http.get(url, headers: _authHeaders(token));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.map((e) => e as String).toList();
    }
    throw Exception('getFavorites failed: ${res.body}');
  }

  Future<void> addFavorite(String id) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/favorites');
    final res = await http.post(url,
        body: jsonEncode({'id': id}), headers: _authHeaders(token));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('addFavorite failed: ${res.body}');
    }
  }

  Future<void> removeFavorite(String id) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/favorites/$id');
    final res = await http.delete(url, headers: _authHeaders(token));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('removeFavorite failed: ${res.body}');
    }
  }

  Future<List<Map<String, dynamic>>> getProgress() async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/progress');
    final res = await http.get(url, headers: _authHeaders(token));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('getProgress failed: ${res.body}');
  }

  Future<void> setProgress(String id, String status, {int position = 0}) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/progress');
    final res = await http.post(url,
        body: jsonEncode({'id': id, 'status': status, 'position': position}),
        headers: _authHeaders(token));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('setProgress failed: ${res.body}');
    }
  }

  Future<void> deleteProgress(String id) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/progress/$id');
    final res = await http.delete(url, headers: _authHeaders(token));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('deleteProgress failed: ${res.body}');
    }
  }

  Future<Map<String, dynamic>> getMe() async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/me');
    final res = await http.get(url, headers: _authHeaders(token));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data;
    }
    throw Exception('getMe failed: ${res.body}');
  }

  Future<List<Map<String, dynamic>>> getActivities({int limit = 100}) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/activities?limit=$limit');
    final res = await http.get(url, headers: _authHeaders(token));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      final data = jsonDecode(res.body) as List<dynamic>;
      return data.cast<Map<String, dynamic>>();
    }
    throw Exception('getActivities failed: \\${res.body}');
  }

  Future<void> addActivity(String activity, {int? timestamp}) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/activities');
    final body = <String, dynamic>{'activity': activity};
    if (timestamp != null) {
      body['timestamp'] = timestamp;
    }
    final res = await http.post(url,
        body: jsonEncode(body), headers: _authHeaders(token));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('addActivity failed: ${res.body}');
    }
  }

  Future<void> logActivity(String activity, {int? timestamp}) async {
    final token = await _getToken();
    final url = Uri.parse('$baseUrl/activities');
    final body = <String, dynamic>{'activity': activity};
    if (timestamp != null) {
      body['timestamp'] = timestamp;
    }
    final res = await http.post(url,
        body: jsonEncode(body), headers: _authHeaders(token));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('logActivity failed: \\${res.body}');
    }
  }

  // Validate token: checks if the stored token is still valid
  Future<bool> validateToken() async {
    final token = await _getToken();
    if (token == null) return false;

    final url = Uri.parse('$baseUrl/validate-token');
    final res = await http.get(url, headers: _authHeaders(token));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return true;
    }
    return false;
  }
}
