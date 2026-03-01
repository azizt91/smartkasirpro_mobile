import 'package:dartz/dartz.dart';
import '../../../../core/error/failures.dart';
import '../datasources/transaction_local_data_source.dart';
import '../datasources/transaction_remote_data_source.dart';
import '../models/pending_transaction_model.dart';
import 'package:mobile_app/features/history/data/models/transaction_model.dart';
import 'dart:convert';

abstract class TransactionRepository {
  Future<Either<Failure, Map<String, dynamic>?>> submitTransaction(Map<String, dynamic> transactionData);
  Future<String?> syncPendingTransactions();
  Future<Either<Failure, List<TransactionModel>>> getTransactions();
  Future<Either<Failure, void>> voidTransaction(int id);
}

class TransactionRepositoryImpl implements TransactionRepository {
  final TransactionLocalDataSource localDataSource;
  final TransactionRemoteDataSource remoteDataSource;

  TransactionRepositoryImpl({
    required this.localDataSource,
    required this.remoteDataSource,
  });

  @override
  Future<Either<Failure, Map<String, dynamic>?>> submitTransaction(Map<String, dynamic> transactionData) async {
    // 1. Always save to local DB first (Offline First)
    final pendingTx = PendingTransactionModel(
      payload: transactionData,
      createdAt: DateTime.now().toIso8601String(),
      status: 'waiting',
    );
    
    try {
      await localDataSource.cachePendingTransaction(pendingTx);
      print('DEBUG SYNC: Transaction saved to local DB');
      
      // 2. Try to sync immediately and get the server response
      final syncResult = await syncPendingTransactionsWithResult();
      
      if (syncResult != null) {
        print('DEBUG SYNC: Synced with server, got transaction_code: ${syncResult['transaction_code']}');
        return Right(syncResult);
      }
      
      // Sync failed or no result, return null (offline mode)
      return const Right(null);
    } catch (e) {
      print('DEBUG SYNC: Local save failed: $e');
      return Left(CacheFailure(e.toString()));
    }
  }

  /// Sync pending transactions and return the last synced transaction data
  Future<Map<String, dynamic>?> syncPendingTransactionsWithResult() async {
    final pendingTransactions = await localDataSource.getPendingTransactions();
    print('DEBUG SYNC: Found ${pendingTransactions.length} pending transactions');
    
    Map<String, dynamic>? lastSyncedData;

    for (var tx in pendingTransactions) {
      try {
        print('DEBUG SYNC: Syncing TX id=${tx.id}, payload keys=${tx.payload.keys.toList()}');
        final syncedData = await remoteDataSource.sendTransaction(tx.payload);
        print('DEBUG SYNC: ✅ Synced successfully! Server Code=${syncedData['transaction_code']}');
        
        // Save the full response (including payment data) to return to caller
        lastSyncedData = syncedData;
        
        // 1. Cache the synced transaction locally (without payment key)
        final cacheData = Map<String, dynamic>.from(syncedData);
        cacheData.remove('payment'); // Don't cache payment gateway details
        final model = TransactionModel.fromJson(cacheData);
        await localDataSource.upsertTransactions([model]);
        
        // 2. Delete from pending
        if (tx.id != null) {
          await localDataSource.deletePendingTransaction(tx.id!);
        }
      } catch (e) {
        print('DEBUG SYNC: ❌ Sync FAILED for tx id=${tx.id}: $e');
        
        final errorStr = e.toString();
        if (errorStr.contains('422') || errorStr.contains('Stok') || errorStr.contains('Nominal')) {
          print('DEBUG SYNC: Removing stuck TX id=${tx.id} (bad data, will never sync)');
          if (tx.id != null) {
            await localDataSource.deletePendingTransaction(tx.id!);
          }
        }
      }
    }
    
    return lastSyncedData;
  }

  @override
  Future<String?> syncPendingTransactions() async {
    final pendingTransactions = await localDataSource.getPendingTransactions();
    print('DEBUG SYNC: Found ${pendingTransactions.length} pending transactions');
    
    String? lastError;

    for (var tx in pendingTransactions) {
      try {
        print('DEBUG SYNC: Syncing TX id=${tx.id}, payload keys=${tx.payload.keys.toList()}');
        final syncedData = await remoteDataSource.sendTransaction(tx.payload);
        print('DEBUG SYNC: ✅ Synced successfully! Server Code=${syncedData['transaction_code']}');
        
        // Success: 
        // 1. Cache the synced transaction locally to ensure it appears in history immediately
        final cacheData = Map<String, dynamic>.from(syncedData);
        cacheData.remove('payment');
        final model = TransactionModel.fromJson(cacheData);
        await localDataSource.upsertTransactions([model]);
        
        // 2. Delete from pending
        if (tx.id != null) {
          await localDataSource.deletePendingTransaction(tx.id!);
        }

      } catch (e) {
        print('DEBUG SYNC: ❌ Sync FAILED for tx id=${tx.id}: $e');
        lastError = e.toString();
        
        // If it's a 422 (validation error) or contains 'Stok' or 'Nominal',
        // the data is bad and will never sync — delete it from the queue
        final errorStr = e.toString();
        if (errorStr.contains('422') || errorStr.contains('Stok') || errorStr.contains('Nominal')) {
          print('DEBUG SYNC: Removing stuck TX id=${tx.id} (bad data, will never sync)');
          if (tx.id != null) {
            await localDataSource.deletePendingTransaction(tx.id!);
          }
        }
      }
    }
    
    return lastError;
  }
  @override
  Future<Either<Failure, List<TransactionModel>>> getTransactions() async {
    try {
      // 1. Fetch from Server
      // If online, fetch and cache
      // If offline, catch exception and return cached + pending
      
      final remoteTransactions = await remoteDataSource.getTransactions();
      await localDataSource.cacheTransactions(remoteTransactions);
      
      // 2. Get Cached
      final cached = await localDataSource.getCachedTransactions();
      
      // 3. Get Pending
      final pending = await localDataSource.getPendingHistory();
      
      // 4. Merge (Pending first)
      return Right([...pending, ...cached]);
      
    } catch (e) {
      // Offline fallback
      try {
        final cached = await localDataSource.getCachedTransactions();
        final pending = await localDataSource.getPendingHistory();
        return Right([...pending, ...cached]);
      } catch (e2) {
        return Left(CacheFailure(e2.toString()));
      }
    }
  }

  @override
  Future<Either<Failure, void>> voidTransaction(int id) async {
    try {
       await remoteDataSource.voidTransaction(id);
       // If success, we should ideally refresh the list or delete from local cache?
       // Refreshing list via Bloc is best.
       return const Right(null);
    } catch (e) {
       return Left(ServerFailure(e.toString()));
    }
  }
}
