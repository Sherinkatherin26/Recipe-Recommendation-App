import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' show join;

class LocalDatabase {
  LocalDatabase._privateConstructor();
  static final LocalDatabase instance = LocalDatabase._privateConstructor();

  Database? _db;
  static const _kWebUsersKey = 'codesapiens_users';
  static const _kWebActivitiesKey = 'codesapiens_activities';
  static const _kWebFavoritesKey = 'codesapiens_favorites';

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<Database> get database async {
    if (kIsWeb) throw StateError('database is not available on web');
    if (_db != null) return _db!;
    _db = await _initDB('codesapiens_app.db');
    return _db!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createDB,
      onUpgrade: (db, oldV, newV) async {
        debugPrint('LocalDatabase: upgrading from $oldV to $newV');
        if (oldV < 2) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS activities(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                email TEXT,
                activity TEXT,
                timestamp INTEGER
              )
            ''');
          } catch (e) {
            debugPrint('upgrade error v1->v2: $e');
          }
        }
        if (oldV < 3) {
          try {
            await db.execute('''
              CREATE TABLE IF NOT EXISTS users(
                email TEXT PRIMARY KEY,
                name TEXT,
                password TEXT
              )
            ''');
          } catch (e) {
            debugPrint('upgrade error v2->v3: $e');
          }
        }
      },
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS favorites(
        id TEXT PRIMARY KEY
      )
    ''');
    await db.execute('''
      CREATE TABLE user_recipes(
        id TEXT PRIMARY KEY,
        email TEXT,
        name TEXT,
        image TEXT,
        description TEXT,
        timestamp INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users(
        email TEXT PRIMARY KEY,
        name TEXT,
        password TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS activities(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT,
        activity TEXT,
        timestamp INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_favorites(
        email TEXT,
        id TEXT,
        PRIMARY KEY(email, id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS followers(
        follower TEXT,
        followee TEXT,
        PRIMARY KEY(follower, followee)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_progress(
        email TEXT,
        id TEXT,
        status TEXT,
        position INTEGER,
        timestamp INTEGER,
        PRIMARY KEY(email, id)
      )
    ''');
  }

  // -------------------------
  // Basic favorites (device-level)
  // -------------------------
  Future<List<String>> getFavorites() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebFavoritesKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => e as String).toList();
    }
    final db = await database;
    final res = await db.query('favorites');
    return res.map((r) => r['id'] as String).toList();
  }

  Future<void> addFavorite(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final favs = await getFavorites();
      if (!favs.contains(id)) {
        favs.add(id);
        await prefs.setString(_kWebFavoritesKey, jsonEncode(favs));
      }
      return;
    }
    final db = await database;
    await db.insert('favorites', {'id': id},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFavorite(String id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final favs = await getFavorites();
      favs.remove(id);
      await prefs.setString(_kWebFavoritesKey, jsonEncode(favs));
      return;
    }
    final db = await database;
    await db.delete('favorites', where: 'id = ?', whereArgs: [id]);
  }

  // -------------------------
  // Per-user favorites
  // -------------------------
  Future<List<String>> getUserFavorites(String email) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) return [];
    final db = await database;
    final res = await db
        .query('user_favorites', where: 'email = ?', whereArgs: [normalized]);
    return res.map((r) => r['id'] as String).toList();
  }

  Future<void> addUserFavorite(String email, String id) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      // no-op on web
      return;
    }
    final db = await database;
    await db.insert('user_favorites', {'email': normalized, 'id': id},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeUserFavorite(String email, String id) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) return;
    final db = await database;
    await db.delete('user_favorites',
        where: 'email = ? AND id = ?', whereArgs: [normalized, id]);
  }

  Future<void> addUserRecipe({
    required String id,
    required String email,
    required String name,
    required String image,
    required String description,
  }) async {
    final normalized = _normalizeEmail(email);
    final db = await database;
    await db.insert(
      'user_recipes',
      {
        'id': id,
        'email': normalized,
        'name': name,
        'image': image,
        'description': description,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<int> getUserRecipesCount(String email) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) return 0;
    final db = await database;
    try {
      final rows = await db.rawQuery(
          'SELECT COUNT(*) AS cnt FROM user_recipes WHERE email = ?',
          [normalized]);
      if (rows.isNotEmpty) {
        final v = rows.first['cnt'];
        if (v is int) return v;
        if (v is int?) return v ?? 0;
        if (v is String) return int.tryParse(v) ?? 0;
      }
      return 0;
    } catch (e) {
      debugPrint('getUserRecipesCount error: $e');
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> getUserRecipes(String email) async {
    final normalized = _normalizeEmail(email);
    final db = await database;
    return await db.query(
      'user_recipes',
      where: 'email = ?',
      whereArgs: [normalized],
      orderBy: 'timestamp DESC',
    );
  }

  // -------------------------
  // Followers
  // -------------------------
  Future<void> addFollower(String follower, String followee) async {
    final f = _normalizeEmail(follower);
    final t = _normalizeEmail(followee);
    if (kIsWeb) return;
    final db = await database;
    await db.insert('followers', {'follower': f, 'followee': t},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFollower(String follower, String followee) async {
    final f = _normalizeEmail(follower);
    final t = _normalizeEmail(followee);
    if (kIsWeb) return;
    final db = await database;
    await db.delete('followers',
        where: 'follower = ? AND followee = ?', whereArgs: [f, t]);
  }

  Future<List<String>> getFollowing(String follower) async {
    final f = _normalizeEmail(follower);
    if (kIsWeb) return [];
    final db = await database;
    final res =
        await db.query('followers', where: 'follower = ?', whereArgs: [f]);
    return res.map((r) => r['followee'] as String).toList();
  }

  Future<List<String>> getFollowers(String followee) async {
    final t = _normalizeEmail(followee);
    if (kIsWeb) return [];
    final db = await database;
    final res =
        await db.query('followers', where: 'followee = ?', whereArgs: [t]);
    return res.map((r) => r['follower'] as String).toList();
  }

  // -------------------------
  // Users (local auth)
  // -------------------------
  Future<bool> addUser(String name, String email, String password) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebUsersKey);
      final List<dynamic> list = raw == null ? [] : jsonDecode(raw);
      final exists =
          list.any((e) => (e as Map<String, dynamic>)['email'] == normalized);
      if (exists) return false;
      list.add({'email': normalized, 'name': name, 'password': password});
      await prefs.setString(_kWebUsersKey, jsonEncode(list));
      return true;
    }
    final db = await database;
    try {
      await db.insert(
          'users', {'email': normalized, 'name': name, 'password': password});
      return true;
    } catch (e) {
      debugPrint('LocalDatabase.addUser error: $e');
      return false;
    }
  }

  Future<bool> userExists(String email) async {
    final db = await database;
    final normalized = _normalizeEmail(email);
    final res = await db.query('users',
        where: 'email = ?', whereArgs: [normalized], limit: 1);
    return res.isNotEmpty;
  }

  Future<Map<String, String>?> getUserByEmail(String email) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebUsersKey);
      if (raw == null) return null;
      final List<dynamic> list = jsonDecode(raw);
      final item = list
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['email'] == normalized, orElse: () => {});
      if (item.isEmpty) return null;
      return {
        'email': item['email'] as String,
        'name': item['name'] as String,
        'password': item['password'] as String
      };
    }
    try {
      final db = await database;
      final res = await db.query('users',
          where: 'email = ?', whereArgs: [normalized], limit: 1);
      if (res.isEmpty) return null;
      final row = res.first;
      return {
        'email': row['email'] as String,
        'name': row['name'] as String,
        'password': row['password'] as String
      };
    } catch (e) {
      debugPrint('LocalDatabase.getUserByEmail error: $e');
      return null;
    }
  }

  /// Update user name/password. Returns true when update applied.
  Future<bool> updateUser(String email,
      {String? name, String? password}) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebUsersKey);
      final List<dynamic> list = raw == null ? [] : jsonDecode(raw);
      var updated = false;
      for (var i = 0; i < list.length; i++) {
        final e = list[i] as Map<String, dynamic>;
        if (e['email'] == normalized) {
          if (name != null) e['name'] = name;
          if (password != null) e['password'] = password;
          list[i] = e;
          updated = true;
          break;
        }
      }
      if (updated) {
        await prefs.setString(_kWebUsersKey, jsonEncode(list));
      }
      return updated;
    }
    try {
      final db = await database;
      final fields = <String, Object?>{};
      if (name != null) fields['name'] = name;
      if (password != null) fields['password'] = password;
      if (fields.isEmpty) return false;
      final updated = await db
          .update('users', fields, where: 'email = ?', whereArgs: [normalized]);
      return updated > 0;
    } catch (e, st) {
      debugPrint('LocalDatabase.updateUser error: $e\n$st');
      return false;
    }
  }

  Future<bool> verifyUser(String email, String password) async {
    try {
      final user = await getUserByEmail(email);
      if (user == null) return false;
      return user['password'] == password;
    } catch (e) {
      debugPrint('LocalDatabase.verifyUser error: $e');
      return false;
    }
  }

  // -------------------------
  // User progress
  // -------------------------
  Future<void> setUserProgress(String email, String id, String status,
      {int? position}) async {
    final normalized = _normalizeEmail(email);
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) return;
    final db = await database;
    await db.insert(
        'user_progress',
        {
          'email': normalized,
          'id': id,
          'status': status,
          'position': position ?? 0,
          'timestamp': ts
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getUserProgressForRecipe(
      String email, String id) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) return null;
    final db = await database;
    final res = await db.query('user_progress',
        where: 'email = ? AND id = ?', whereArgs: [normalized, id], limit: 1);
    if (res.isEmpty) return null;
    final row = res.first;
    return {
      'status': row['status'] as String?,
      'position': row['position'] as int?,
      'timestamp': row['timestamp'] as int?
    };
  }

  Future<List<Map<String, dynamic>>> getUserProgress(String email) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) return [];
    final db = await database;
    final res = await db
        .query('user_progress', where: 'email = ?', whereArgs: [normalized]);
    return res
        .map((r) => {
              'id': r['id'],
              'status': r['status'],
              'position': r['position'],
              'timestamp': r['timestamp']
            })
        .toList();
  }

  // -------------------------
  // Activities
  // -------------------------
  Future<void> addActivity(String email, String activity) async {
    final normalized = _normalizeEmail(email);
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebActivitiesKey);
      final List<dynamic> list = raw == null ? [] : jsonDecode(raw);
      list.add({'email': normalized, 'activity': activity, 'timestamp': ts});
      await prefs.setString(_kWebActivitiesKey, jsonEncode(list));
      return;
    }
    final db = await database;
    await db.insert('activities',
        {'email': normalized, 'activity': activity, 'timestamp': ts});
  }

  Future<List<Map<String, dynamic>>> getActivities(String email) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebActivitiesKey);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .cast<Map<String, dynamic>>()
          .where((e) => e['email'] == normalized)
          .map((e) => {'activity': e['activity'], 'timestamp': e['timestamp']})
          .toList();
    }
    final db = await database;
    final res = await db.query('activities',
        where: 'email = ?', whereArgs: [normalized], orderBy: 'timestamp DESC');
    return res
        .map((r) => {'activity': r['activity'], 'timestamp': r['timestamp']})
        .toList();
  }

  // -------------------------
  // Close DB
  // -------------------------
  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
