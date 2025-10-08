import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/menu_item.dart';

class MenuDatabase {
  static final MenuDatabase instance = MenuDatabase._init();
  static Database? _database;

  MenuDatabase._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('menu.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, fileName);
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE menu_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        price_pence INTEGER NOT NULL,
        is_active INTEGER NOT NULL
      )
    ''');
  }

  Future<int> insertItem(MenuItem item) async {
    final db = await database;
    return await db.insert('menu_items', item.toMap());
  }

  Future<int> updateItem(MenuItem item) async {
    final db = await database;
    return await db.update(
      'menu_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteItem(int id) async {
    final db = await database;
    return await db.delete(
      'menu_items',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<MenuItem>> getActiveItems() async {
    final db = await database;
    final maps = await db.query(
      'menu_items',
      where: 'is_active = 1',
    );
    return List.generate(maps.length, (i) => MenuItem.fromMap(maps[i]));
  }
}
