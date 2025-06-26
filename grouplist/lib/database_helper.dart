// lib/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'groupdata.dart';
import 'list.dart';

class DatabaseHelper {
  // Padrão Singleton para garantir uma única instância do banco de dados.
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Inicializa o banco de dados
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'grouplist.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
  }

  // Cria as tabelas quando o banco de dados é criado pela primeira vez
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE groups (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        category TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        groupId TEXT NOT NULL,
        name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        checked INTEGER NOT NULL,
        FOREIGN KEY (groupId) REFERENCES groups (id) ON DELETE CASCADE
      )
    ''');
  }

  // Operações CRUD para Grupos

  Future<void> insertOrUpdateGroup(GroupData group) async {
    final db = await database;
    await db.insert(
      'groups',
      {
        'id': group.id,
        'name': group.name,
        'category': group.category,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<GroupData>> getGroups() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('groups');
    return List.generate(maps.length, (i) {
      return GroupData(
        name: maps[i]['name'],
        category: maps[i]['category'],
        id: maps[i]['id'],
        membersUids: maps[i]['membersUids'] != null
            ? List<String>.from(maps[i]['membersUids'])
            : <String>[],
        createdByUid: maps[i]['createdByUid'] ?? '',
      );
    });
  }
  
  Future<void> deleteGroup(String id) async {
    final db = await database;
    await db.delete(
      'groups',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
  
  Future<void> clearAllGroups() async {
    final db = await database;
    await db.delete('groups');
  }

  // Operações CRUD para Itens

  Future<void> insertOrUpdateItem(ItemData item, String groupId) async {
    final db = await database;
    await db.insert(
      'items',
      {
        'id': item.id,
        'groupId': groupId,
        'name': item.name,
        'quantity': item.quantity,
        'checked': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Adicione este método em lib/database_helper.dart
Future<void> deleteItem(String id) async {
  final db = await database;
  await db.delete(
    'items',
    where: 'id = ?',
    whereArgs: [id],
  );
}

  Future<List<ItemData>> getItems(String groupId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );
    return List.generate(maps.length, (i) {
      return ItemData(
        id: maps[i]['id'],
        name: maps[i]['name'],
        quantity: maps[i]['quantity'],
        
      );
    });
  }

  Future<void> clearItemsForGroup(String groupId) async {
    final db = await database;
    await db.delete('items', where: 'groupId = ?', whereArgs: [groupId]);
  }
}