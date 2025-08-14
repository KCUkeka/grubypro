import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/grocery_item.dart';
import '../models/pantry_item.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'gruby.db');
    return await openDatabase(path, version: 1, onCreate: _createDb);
  }

  Future<void> _createDb(Database db, int version) async {
    await db.execute('''
      CREATE TABLE grocery_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        isPurchased INTEGER NOT NULL,
        createdAt INTEGER NOT NULL,
        barcode TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE pantry_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        expiryDate INTEGER,
        addedAt INTEGER NOT NULL,
        barcode TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE purchase_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category TEXT NOT NULL,
        purchaseDate INTEGER NOT NULL,
        barcode TEXT
      )
    ''');
  }

  // Grocery Items CRUD
  Future<int> insertGroceryItem(GroceryItem item) async {
    final db = await database;
    return await db.insert('grocery_items', item.toMap());
  }

  Future<List<GroceryItem>> getGroceryItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'grocery_items',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) => GroceryItem.fromMap(maps[i]));
  }

  Future<int> updateGroceryItem(GroceryItem item) async {
    final db = await database;
    return await db.update(
      'grocery_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteGroceryItem(int id) async {
    final db = await database;
    return await db.delete('grocery_items', where: 'id = ?', whereArgs: [id]);
  }

  // Pantry Items CRUD
  Future<int> insertPantryItem(PantryItem item) async {
    final db = await database;
    return await db.insert('pantry_items', item.toMap());
  }

  Future<List<PantryItem>> getPantryItems() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'pantry_items',
      orderBy: 'addedAt DESC',
    );
    return List.generate(maps.length, (i) => PantryItem.fromMap(maps[i]));
  }

  Future<int> updatePantryItem(PantryItem item) async {
    final db = await database;
    return await db.update(
      'pantry_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deletePantryItem(int id) async {
    final db = await database;
    return await db.delete('pantry_items', where: 'id = ?', whereArgs: [id]);
  }

  // Purchase History
  Future<void> addToPurchaseHistory(
    String name,
    String category,
    String? barcode,
  ) async {
    final db = await database;
    await db.insert('purchase_history', {
      'name': name,
      'category': category,
      'purchaseDate': DateTime.now().millisecondsSinceEpoch,
      'barcode': barcode,
    });
  }

  Future<List<String>> getSuggestions(String query) async {
    final db = await database;
    final result = await db.query(
      'purchase_history',
      columns: ['DISTINCT name'],
      where: 'name LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'purchaseDate DESC',
      limit: 5,
    );
    return result.map((item) => item['name'] as String).toList();
  }

  Future<List<PantryItem>> getExpiringSoonItems() async {
    final db = await database;
    final threeDaysFromNow =
        DateTime.now().add(Duration(days: 3)).millisecondsSinceEpoch;
    final now = DateTime.now().millisecondsSinceEpoch;

    final List<Map<String, dynamic>> maps = await db.query(
      'pantry_items',
      where: 'expiryDate IS NOT NULL AND expiryDate BETWEEN ? AND ?',
      whereArgs: [now, threeDaysFromNow],
      orderBy: 'expiryDate ASC',
    );
    return List.generate(maps.length, (i) => PantryItem.fromMap(maps[i]));
  }
}
