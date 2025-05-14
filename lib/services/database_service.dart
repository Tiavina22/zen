import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'dart:io' show Platform;

class DatabaseService {
  static const String tableName = 'clipboard_items';
  static Database? _database;

  static Future<void> initialize() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    final String path = join(await getDatabasesPath(), 'clipboard_manager.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE $tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            content TEXT NOT NULL,
            timestamp INTEGER NOT NULL,
            position INTEGER NOT NULL
          )
        ''');
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // Ajouter la colonne position
          await db.execute('ALTER TABLE $tableName ADD COLUMN position INTEGER DEFAULT 0');
          // Mettre à jour les positions existantes basées sur le timestamp
          final items = await db.query(tableName, orderBy: 'timestamp DESC');
          for (var i = 0; i < items.length; i++) {
            await db.update(
              tableName,
              {'position': i},
              where: 'id = ?',
              whereArgs: [items[i]['id']],
            );
          }
        }
      },
    );
  }

  static Future<int> insertItem(String content) async {
    final db = await database;
    // Obtenir la position la plus basse
    final minPosition = await db.rawQuery('SELECT MIN(position) as minPos FROM $tableName');
    final position = (minPosition.first['minPos'] as int?) ?? 0;
    
    return await db.insert(
      tableName,
      {
        'content': content,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'position': position - 1, // Insérer au début de la liste
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<Map<String, dynamic>>> getItems() async {
    final db = await database;
    return await db.query(
      tableName,
      orderBy: 'position ASC',
    );
  }

  static Future<void> updateItemPosition(int id, int newPosition) async {
    final db = await database;
    await db.update(
      tableName,
      {'position': newPosition},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> reorderItems(int oldPosition, int newPosition) async {
    final db = await database;
    await db.transaction((txn) async {
      final items = await txn.query(
        tableName,
        orderBy: 'position ASC',
      );

      if (oldPosition < newPosition) {
        // Déplacement vers le bas
        for (var i = oldPosition + 1; i <= newPosition; i++) {
          await txn.update(
            tableName,
            {'position': i - 1},
            where: 'id = ?',
            whereArgs: [items[i]['id']],
          );
        }
      } else {
        // Déplacement vers le haut
        for (var i = newPosition; i < oldPosition; i++) {
          await txn.update(
            tableName,
            {'position': i + 1},
            where: 'id = ?',
            whereArgs: [items[i]['id']],
          );
        }
      }

      // Mettre à jour l'élément déplacé
      await txn.update(
        tableName,
        {'position': newPosition},
        where: 'id = ?',
        whereArgs: [items[oldPosition]['id']],
      );
    });
  }

  static Future<void> deleteItem(int id) async {
    final db = await database;
    await db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteAllItems() async {
    final db = await database;
    await db.delete(tableName);
  }
} 