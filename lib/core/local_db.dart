import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Base de datos SQLite local (en el teléfono).
///
/// Tabla `cache`      : copia de las últimas respuestas de la API (para leer sin internet).
/// Tabla `pendientes` : cola de registros creados sin conexión, listos para enviarse después.
class LocalDb {
  /// Usuario con sesión activa (lo fija AuthProvider). Separa los datos de cada usuario.
  static int usuarioId = 0;

  static Database? _db;
  static Future<Database> get _database async => _db ??= await _abrir();

  static Future<Database> _abrir() async {
    final ruta = p.join(await getDatabasesPath(), 'limpiecingo_local.db');
    return openDatabase(
      ruta,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE cache (
            clave TEXT PRIMARY KEY,
            json TEXT NOT NULL,
            actualizado INTEGER NOT NULL
          )''');
        await db.execute('''
          CREATE TABLE pendientes (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            usuario_id INTEGER NOT NULL,
            tipo TEXT NOT NULL,
            payload TEXT NOT NULL,
            creado INTEGER NOT NULL
          )''');
      },
    );
  }

  static String _k(String nombre) => '$usuarioId:$nombre';

  // ---------- Caché de lecturas ----------
  static Future<void> guardar(String nombre, Object? data) async {
    final db = await _database;
    await db.insert(
      'cache',
      {'clave': _k(nombre), 'json': jsonEncode(data), 'actualizado': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Object?> leer(String nombre) async {
    final db = await _database;
    final r = await db.query('cache', where: 'clave = ?', whereArgs: [_k(nombre)], limit: 1);
    return r.isEmpty ? null : jsonDecode(r.first['json'] as String);
  }

  // ---------- Caché global (sin usuario): recordar quién tenía sesión ----------
  static Future<void> guardarGlobal(String nombre, Object? data) async {
    final db = await _database;
    await db.insert(
      'cache',
      {'clave': 'global:$nombre', 'json': jsonEncode(data), 'actualizado': DateTime.now().millisecondsSinceEpoch},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<Object?> leerGlobal(String nombre) async {
    final db = await _database;
    final r = await db.query('cache', where: 'clave = ?', whereArgs: ['global:$nombre'], limit: 1);
    return r.isEmpty ? null : jsonDecode(r.first['json'] as String);
  }

  // ---------- Cola de pendientes ----------
  static Future<void> encolar(String tipo, Map<String, dynamic> payload) async {
    final db = await _database;
    await db.insert('pendientes', {
      'usuario_id': usuarioId,
      'tipo': tipo,
      'payload': jsonEncode(payload),
      'creado': DateTime.now().millisecondsSinceEpoch,
    });
  }

  static Future<List<Map<String, Object?>>> pendientes() async {
    final db = await _database;
    return db.query('pendientes', where: 'usuario_id = ?', whereArgs: [usuarioId], orderBy: 'id ASC');
  }

  static Future<int> contarPendientes() async {
    final db = await _database;
    final r = await db.rawQuery('SELECT COUNT(*) AS n FROM pendientes WHERE usuario_id = ?', [usuarioId]);
    return (r.first['n'] as int?) ?? 0;
  }

  static Future<void> borrarPendiente(int id) async {
    final db = await _database;
    await db.delete('pendientes', where: 'id = ?', whereArgs: [id]);
  }
}
