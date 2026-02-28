import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('kasir_app.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (kIsWeb) {
      // Web Support
      var databaseFactory = databaseFactoryFfiWeb;
      return await databaseFactory.openDatabase(filePath, options: OpenDatabaseOptions(
        version: 3,
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      ));
    } else {
      // Mobile Support
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, filePath);

      return await openDatabase(
        path, 
        version: 3, 
        onCreate: _createDB,
        onUpgrade: _onUpgrade,
      );
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE transactions ADD COLUMN status TEXT DEFAULT 'completed'");
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE products ADD COLUMN type TEXT DEFAULT 'barang'");
      await db.execute("ALTER TABLE products ADD COLUMN commission_type TEXT");
      await db.execute("ALTER TABLE products ADD COLUMN commission_amount REAL DEFAULT 0");
    }
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT';
    const intType = 'INTEGER';
    const realType = 'REAL';
    const boolType = 'INTEGER'; // SQLite uses 0 and 1 for boolean

    // Categories Table
    await db.execute('''
      CREATE TABLE categories (
        id $intType PRIMARY KEY,
        name $textType NOT NULL,
        description $textType,
        created_at $textType,
        updated_at $textType
      )
    ''');

    // Product Groups Table
    await db.execute('''
      CREATE TABLE product_groups (
        id $intType PRIMARY KEY,
        category_id $intType,
        name $textType NOT NULL,
        description $textType,
        has_variants $boolType,
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Products Table (Mixed: Single Products and Variants)
    await db.execute('''
      CREATE TABLE products (
        id $intType PRIMARY KEY,
        product_group_id $intType,
        category_id $intType,
        name $textType NOT NULL,
        variant_name $textType,
        barcode $textType,
        purchase_price $realType,
        selling_price $realType,
        stock $intType,
        minimum_stock $intType,
        image $textType,
        description $textType,
        type $textType DEFAULT 'barang',
        commission_type $textType,
        commission_amount $realType DEFAULT 0,
        is_low_stock $boolType,
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (product_group_id) REFERENCES product_groups (id),
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    // Pending Transactions Table (For Offline Sync)
    await db.execute('''
      CREATE TABLE pending_transactions (
        id $idType,
        payload $textType NOT NULL, -- JSON String of the full request body
        created_at $textType NOT NULL,
        status $textType DEFAULT 'waiting', -- waiting, failed
        error_message $textType
      )
    ''');

    // Stock Movements Table (Cache)
    await db.execute('''
      CREATE TABLE stock_movements (
        id $idType,
        product_id $intType NOT NULL,
        type $textType NOT NULL, -- in, out, adjustment
        quantity $intType NOT NULL,
        reference_type $textType,
        reference_id $intType,
        notes $textType,
        created_at $textType,
        updated_at $textType,
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');

    // Pending Stock Adjustments Table (Offline)
    await db.execute('''
      CREATE TABLE pending_stock_adjustments (
        id $idType,
        product_id $intType NOT NULL,
        type $textType NOT NULL, -- add, subtract, set
        quantity $intType NOT NULL,
        notes $textType,
        created_at $textType NOT NULL,
        status $textType DEFAULT 'waiting',
        error_message $textType
      )
    ''');
    
    // Cached Transactions Table (From Server)
    await db.execute('''
      CREATE TABLE transactions (
        id $intType PRIMARY KEY, -- ID from Server
        transaction_code $textType,
        total_amount $realType,
        payment_method $textType,
        created_at $textType,
        status $textType DEFAULT 'completed',
        payload $textType -- Full JSON details for simple caching
      )
    ''');
    
    // Expenses Table (Cache)
    await db.execute('''
      CREATE TABLE expenses (
        id $intType PRIMARY KEY,
        name $textType NOT NULL,
        amount $realType NOT NULL,
        expense_date $textType NOT NULL,
        description $textType,
        created_at $textType
      )
    ''');

    // Pending Expenses Table (Offline)
    await db.execute('''
      CREATE TABLE pending_expenses (
        id $intType PRIMARY KEY AUTOINCREMENT,
        payload $textType NOT NULL, -- JSON
        expense_date $textType NOT NULL,
        status $textType DEFAULT 'waiting'
      )
    ''');
  }

  Future<void> clearAllData() async {
    final db = await instance.database;
    await db.transaction((txn) async {
       // Clear Cache Tables
       await txn.delete('transactions');
       await txn.delete('stock_movements');
       await txn.delete('expenses');
       
       // Clear Product Data (Will be re-synced)
       await txn.delete('products');
       await txn.delete('product_groups');
       await txn.delete('categories');
       
       // Clear Pending as well to avoid foreign key conflicts after server reset
       await txn.delete('pending_transactions'); 
       await txn.delete('pending_stock_adjustments');
       await txn.delete('pending_expenses');
    });
  }

  Future<void> close() async {
    final db = await instance.database;
    db.close();
  }
}
