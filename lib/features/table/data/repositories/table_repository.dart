import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:mobile_app/core/error/failures.dart';
import '../models/table_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TableRepository {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  TableRepository({required this.dio, required this.secureStorage});

  Future<Either<Failure, List<TableModel>>> getTables() async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.get(
        '/tables',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data['success']) {
        final List<dynamic> data = response.data['data'];
        final tables = data.map((e) => TableModel.fromJson(e)).toList();
        return Right(tables);
      } else {
        return Left(ServerFailure('Failed to load tables'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, TableModel>> createTable(String name) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.post(
        '/tables',
        data: {'nama_meja': name},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return Right(TableModel.fromJson(response.data['data']));
      } else {
        return Left(ServerFailure(response.data['message'] ?? 'Failed to create table'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, TableModel>> updateTable(int id, String name, String status) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.put(
        '/tables/$id',
        data: {'nama_meja': name, 'status': status},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return Right(TableModel.fromJson(response.data['data']));
      } else {
        return Left(ServerFailure(response.data['message'] ?? 'Failed to update table'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> deleteTable(int id) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.delete(
        '/tables/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return const Right(null);
      } else {
        return Left(ServerFailure(response.data['message'] ?? 'Failed to delete table'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> clearTable(int id) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.post(
        '/tables/$id/clear',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200) {
        return const Right(null);
      } else {
        return Left(ServerFailure(response.data['message'] ?? 'Failed to clear table'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
