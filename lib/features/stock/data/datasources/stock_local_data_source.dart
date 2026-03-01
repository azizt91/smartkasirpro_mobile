import 'package:dartz/dartz.dart';
import 'package:sqflite/sqflite.dart';
import '../../../../core/database/database_helper.dart';
import '../../../../core/error/failures.dart';
import 'package:mobile_app/features/product/data/models/product_model.dart';
import '../models/pending_stock_adjustment_model.dart';
import '../models/stock_movement_model.dart';

abstract class StockLocalDataSource {
  Future<List<ProductModel>> getProductsSortedByStock();
  Future<List<ProductModel>> getLowStockProducts();
  Future<List<StockMovementModel>> getStockMovements(int productId);
  Future<void> savePendingAdjustment(PendingStockAdjustmentModel adjustment);
  Future<List<PendingStockAdjustmentModel>> getPendingAdjustments();
  Future<void> deletePendingAdjustment(int id);
  Future<void> updateProductStock(int productId, int newStock);
}

class StockLocalDataSourceImpl implements StockLocalDataSource {
  final DatabaseHelper databaseHelper;

  StockLocalDataSourceImpl({required this.databaseHelper});

  @override
  Future<List<ProductModel>> getProductsSortedByStock() async {
    final db = await databaseHelper.database;
    // Sort by stock ascending (low stock first)
    final result = await db.query('products', orderBy: 'stock ASC');
    return result.map((json) => ProductModel.fromJson(json)).toList();
  }

  @override
  Future<List<ProductModel>> getLowStockProducts() async {
    final db = await databaseHelper.database;
    final result = await db.query(
      'products', 
      where: 'is_low_stock = 1 OR stock <= minimum_stock',
      orderBy: 'stock ASC'
    );
    return result.map((json) => ProductModel.fromJson(json)).toList();
  }

  @override
  Future<List<StockMovementModel>> getStockMovements(int productId) async {
    final db = await databaseHelper.database;
    final result = await db.query(
      'stock_movements',
      where: 'product_id = ?',
      whereArgs: [productId],
      orderBy: 'created_at DESC',
    );
    return result.map((json) => StockMovementModel.fromJson(json)).toList();
  }

  @override
  Future<void> savePendingAdjustment(PendingStockAdjustmentModel adjustment) async {
    final db = await databaseHelper.database;
    
    // Also update local product immediately for UI reactivity
    // Calculate new stock based on type
    final productResult = await db.query('products', where: 'id = ?', whereArgs: [adjustment.productId]);
    if (productResult.isNotEmpty) {
      final product = ProductModel.fromJson(productResult.first);
      int newStock = product.stock;
      
      if (adjustment.type == 'add') {
         newStock += adjustment.quantity;
      } else if (adjustment.type == 'subtract') {
         newStock -= adjustment.quantity;
      } else if (adjustment.type == 'set') {
         newStock = adjustment.quantity;
      }
      
      // Prevent negative stock
      if (newStock < 0) newStock = 0;
      
      await updateProductStock(adjustment.productId, newStock);
      
      // Save pending adjustment with 'set' type and the final calculated stock
      // This prevents double-apply: local does add/subtract, API gets absolute 'set' value
      final syncAdjustment = PendingStockAdjustmentModel(
        productId: adjustment.productId,
        type: 'set',
        quantity: newStock,
        notes: adjustment.notes,
        createdAt: adjustment.createdAt,
      );
      await db.insert('pending_stock_adjustments', syncAdjustment.toMap());
      
      // Also save to local stock movements cache so it shows in history immediately
      await db.insert('stock_movements', {
          'product_id': adjustment.productId,
          'type': adjustment.type == 'subtract' ? 'out' : (adjustment.type == 'add' ? 'in' : 'adjustment'),
          'quantity': adjustment.quantity,
          'reference_type': 'Manual Adjustment (Offline)',
          'reference_id': null,
          'notes': adjustment.notes,
          'created_at': adjustment.createdAt.toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
      });
    }
  }

  @override
  Future<List<PendingStockAdjustmentModel>> getPendingAdjustments() async {
    final db = await databaseHelper.database;
    final result = await db.query('pending_stock_adjustments');
    return result.map((json) => PendingStockAdjustmentModel.fromMap(json)).toList();
  }

  @override
  Future<void> deletePendingAdjustment(int id) async {
    final db = await databaseHelper.database;
    await db.delete('pending_stock_adjustments', where: 'id = ?', whereArgs: [id]);
  }
  
  @override
  Future<void> updateProductStock(int productId, int newStock) async {
    final db = await databaseHelper.database;
    // Update stock and check is_low_stock status logic (simple check vs minimum_stock)
    // We need minimum_stock to update is_low_stock properly.
    // Let's just update stock for now, trigger logic elsewhere or fetch first.
    // Optimized: Update directly.
    await db.rawUpdate('''
      UPDATE products 
      SET stock = ?, 
          is_low_stock = CASE WHEN ? <= minimum_stock THEN 1 ELSE 0 END, 
          updated_at = ? 
      WHERE id = ?
    ''', [newStock, newStock, DateTime.now().toIso8601String(), productId]);
  }
}
