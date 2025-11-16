import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart'
    show Database, ConflictAlgorithm, openDatabase, getDatabasesPath;
import 'package:path/path.dart' show join;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class LocalDatabase {
  LocalDatabase._privateConstructor();
  static final LocalDatabase instance = LocalDatabase._privateConstructor();

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Database? _db;
  // In-memory cache for web fallback
  static const _kWebFavoritesKey = 'codesapiens_favorites';

  Future<Database> get database async {
    if (kIsWeb) {
      // On web we don't use sqflite
      throw StateError('database is not available on web');
    }
    if (_db != null) return _db!;
    try {
      _db = await _initDB('codesapiens_app.db');
      return _db!;
    } catch (e, st) {
      debugPrint('LocalDatabase: failed to open DB: $e\n$st');
      rethrow;
    }
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    try {
      return await openDatabase(
        path,
        version: 3,
        onCreate: _createDB,
        onUpgrade: (db, oldVersion, newVersion) async {
          debugPrint(
              'LocalDatabase: upgrading from version $oldVersion to $newVersion');
          if (oldVersion < 2) {
            // Add activities table if upgrading from version 1
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
              debugPrint(
                  'LocalDatabase: failed to create activities table: $e');
            }
          }
          if (oldVersion < 3) {
            // Ensure users table exists (for safety)
            try {
              await db.execute('''
                CREATE TABLE IF NOT EXISTS users(
                  email TEXT PRIMARY KEY,
                  name TEXT,
                  password TEXT
                )
              ''');
            } catch (e) {
              debugPrint('LocalDatabase: failed to create users table: $e');
            }
          }
        },
      );
    } catch (e, st) {
      debugPrint('LocalDatabase: openDatabase error: $e\n$st');
      throw Exception('Failed to open local database: $e');
    }
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE favorites(
        id TEXT PRIMARY KEY
      )
    ''');
    // users table for local auth
    await db.execute('''
      CREATE TABLE users(
        email TEXT PRIMARY KEY,
        name TEXT,
        password TEXT
      )
    ''');
    // activities table to record user actions
    await db.execute('''
      CREATE TABLE activities(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        email TEXT,
        activity TEXT,
        timestamp INTEGER
      )
    ''');
    // user-specific favorites (email + recipe id)
    await db.execute('''
      CREATE TABLE user_favorites(
        email TEXT,
        id TEXT,
        PRIMARY KEY(email, id)
      )
    ''');
    // followers table: follower -> followee
    await db.execute('''
      CREATE TABLE followers(
        follower TEXT,
        followee TEXT,
        PRIMARY KEY(follower, followee)
      )
    ''');
    // user progress table: stores per-user recipe progress (viewed, in_progress, completed)
    await db.execute('''
      CREATE TABLE user_progress(
        email TEXT,
        id TEXT,
        status TEXT,
        position INTEGER,
        timestamp INTEGER,
        PRIMARY KEY(email, id)
      )
    ''');
  }

  Future<List<String>> getFavorites() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebFavoritesKey);
      if (raw == null) return <String>[];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => e as String).toList();
    }
    final db = await database;
    final res = await db.query('favorites');
    return res.map((r) => r['id'] as String).toList();
  }

  // -- User-specific favorites --
  Future<List<String>> getUserFavorites(String email) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      // No per-user web fallback currently
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('codesapiens_user_favorites_$normalized');
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => e as String).toList();
    }
    final db = await database;
    final res = await db
        .query('user_favorites', where: 'email = ?', whereArgs: [normalized]);
    return res.map((r) => r['id'] as String).toList();
  }

  Future<void> addUserFavorite(String email, String id) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'codesapiens_user_favorites_$normalized';
      final raw = prefs.getString(key);
      final List<dynamic> list = raw == null ? [] : jsonDecode(raw);
      if (!list.contains(id)) {
        list.add(id);
        await prefs.setString(key, jsonEncode(list));
      }
      return;
    }
    final db = await database;
    await db.insert('user_favorites', {'email': normalized, 'id': id},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeUserFavorite(String email, String id) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'codesapiens_user_favorites_$normalized';
      final raw = prefs.getString(key);
      final List<dynamic> list = raw == null ? [] : jsonDecode(raw);
      list.remove(id);
      await prefs.setString(key, jsonEncode(list));
      return;
    }
    final db = await database;
    await db.delete('user_favorites',
        where: 'email = ? AND id = ?', whereArgs: [normalized, id]);
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

  // -- Followers management --
  Future<void> addFollower(String follower, String followee) async {
    final f = _normalizeEmail(follower);
    final t = _normalizeEmail(followee);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'codesapiens_followers_$f';
      final raw = prefs.getString(key);
      final List<dynamic> list = raw == null ? [] : jsonDecode(raw);
      if (!list.contains(t)) {
        list.add(t);
        await prefs.setString(key, jsonEncode(list));
      }
      return;
    }
    final db = await database;
    await db.insert('followers', {'follower': f, 'followee': t},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> removeFollower(String follower, String followee) async {
    final f = _normalizeEmail(follower);
    final t = _normalizeEmail(followee);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'codesapiens_followers_$f';
      final raw = prefs.getString(key);
      final List<dynamic> list = raw == null ? [] : jsonDecode(raw);
      list.remove(t);
      await prefs.setString(key, jsonEncode(list));
      return;
    }
    final db = await database;
    await db.delete('followers',
        where: 'follower = ? AND followee = ?', whereArgs: [f, t]);
  }

  Future<List<String>> getFollowing(String follower) async {
    final f = _normalizeEmail(follower);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'codesapiens_followers_$f';
      final raw = prefs.getString(key);
      if (raw == null) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => e as String).toList();
    }
    final db = await database;
    final res =
        await db.query('followers', where: 'follower = ?', whereArgs: [f]);
    return res.map((r) => r['followee'] as String).toList();
  }

  Future<List<String>> getFollowers(String followee) async {
    final t = _normalizeEmail(followee);
    if (kIsWeb) {
      // For web fallback, gather all keys and collect followers who list followee
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((k) => k.startsWith('codesapiens_followers_'));
      final List<String> out = [];
      for (final k in keys) {
        final raw = prefs.getString(k);
        if (raw == null) continue;
        final list = jsonDecode(raw) as List<dynamic>;
        if (list.contains(t)) {
          out.add(k.replaceFirst('codesapiens_followers_', ''));
        }
      }
      return out;
    }
    final db = await database;
    final res =
        await db.query('followers', where: 'followee = ?', whereArgs: [t]);
    return res.map((r) => r['follower'] as String).toList();
  }

  // --- Users (simple local auth) ---
  static const _kWebUsersKey = 'codesapiens_users';
  static const _kWebActivitiesKey = 'codesapiens_activities';

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
    } catch (e, st) {
      debugPrint('LocalDatabase.addUser error: $e\n$st');
      return false;
    }
  }

  Future<Map<String, String>?> getUserByEmail(String email) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kWebUsersKey);
      if (raw == null) return null;
      final List<dynamic> list = jsonDecode(raw);
      final item = list.cast<Map<String, dynamic>>().firstWhere(
            (e) => e['email'] == normalized,
            orElse: () => {},
          );
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
    } catch (e, st) {
      debugPrint('LocalDatabase.getUserByEmail error: $e\n$st');
      return null;
    }
  }

  Future<bool> verifyUser(String email, String password) async {
    try {
      final user = await getUserByEmail(email);
      if (user == null) return false;
      return user['password'] == password;
    } catch (e, st) {
      debugPrint('LocalDatabase.verifyUser error: $e\n$st');
      return false;
    }
  }

  // --- User progress (per-recipe) ---
  static const _kWebUserProgressPrefix = 'codesapiens_user_progress_';

  Future<Map<String, dynamic>?> getUserProgressForRecipe(
      String email, String id) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kWebUserProgressPrefix$normalized';
      final raw = prefs.getString(key);
      if (raw == null) return null;
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      final item = map[id];
      if (item == null) return null;
      return item as Map<String, dynamic>;
    }
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
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kWebUserProgressPrefix$normalized';
      final raw = prefs.getString(key);
      if (raw == null) return [];
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      final out = <Map<String, dynamic>>[];
      map.forEach((k, v) {
        out.add({
          'id': k,
          'status': v['status'],
          'position': v['position'],
          'timestamp': v['timestamp']
        });
      });
      return out;
    }
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

  Future<void> setUserProgress(String email, String id, String status,
      {int? position}) async {
    final normalized = _normalizeEmail(email);
    final ts = DateTime.now().millisecondsSinceEpoch;
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kWebUserProgressPrefix$normalized';
      final raw = prefs.getString(key);
      final Map<String, dynamic> map =
          raw == null ? {} : jsonDecode(raw) as Map<String, dynamic>;
      map[id] = {'status': status, 'position': position ?? 0, 'timestamp': ts};
      await prefs.setString(key, jsonEncode(map));
      return;
    }
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

  Future<void> removeUserProgress(String email, String id) async {
    final normalized = _normalizeEmail(email);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_kWebUserProgressPrefix$normalized';
      final raw = prefs.getString(key);
      if (raw == null) return;
      final Map<String, dynamic> map = jsonDecode(raw) as Map<String, dynamic>;
      map.remove(id);
      await prefs.setString(key, jsonEncode(map));
      return;
    }
    final db = await database;
    await db.delete('user_progress',
        where: 'email = ? AND id = ?', whereArgs: [normalized, id]);
  }

  // --- Activities ---
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

  Future<void> close() async {
    final db = _db;
    if (db != null) {
      await db.close();
      _db = null;
    }
  }
}
