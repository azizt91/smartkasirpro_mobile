import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:mobile_app/core/error/failures.dart';
import '../models/customer_model.dart'; // Correct relative path
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CustomerRepository {
  final Dio dio;
  final FlutterSecureStorage secureStorage;

  CustomerRepository({required this.dio, required this.secureStorage});

  Future<Either<Failure, List<CustomerModel>>> getCustomers() async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      print('DEBUG: Fetching Customers. Token: ${token != null ? "Present" : "Missing"}');
      
      final response = await dio.get(
        '/customers',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      
      print('DEBUG: Customer API Response Status: ${response.statusCode}');
      print('DEBUG: Customer API Response Data: ${response.data}');

      if (response.statusCode == 200 && response.data['success']) {
        final List<dynamic> data = response.data['customers'];
        final customers = data.map((e) => CustomerModel.fromJson(e)).toList();
        print('DEBUG: Parsed ${customers.length} customers');
        return Right(customers);
      } else {
        print('DEBUG: Failed to load customers: ${response.data}');
        return Left(ServerFailure(response.data['message'] ?? 'Failed to load customers'));
      }
    } on DioException catch (e) {
      print('DEBUG: DioException in getCustomers: ${e.message} - ${e.response?.data}');
      return Left(ServerFailure(e.message ?? 'Network error'));
    } catch (e) {
      print('DEBUG: Exception in getCustomers: $e');
      return Left(ServerFailure(e.toString()));
    }
  }
  
  Future<Either<Failure, List<Map<String, dynamic>>>> getEmployees() async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.get(
        '/employees',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.statusCode == 200 && response.data['success']) {
        final List<dynamic> data = response.data['employees'];
        return Right(data.map((e) => e as Map<String, dynamic>).toList());
      } else {
        return Left(ServerFailure('Failed to load employees'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, CustomerModel>> createCustomer(String name, String? phone, {String? email, String? address}) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.post(
        '/customers',
        data: {
          'name': name,
          'phone': phone,
          'email': email,
          'address': address,
        },
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data['customer'] ?? response.data;
        return Right(CustomerModel.fromJson(data));
      } else {
        return Left(ServerFailure(response.data['message'] ?? 'Failed to create customer'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, CustomerModel>> updateCustomer(CustomerModel customer) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.put(
        '/customers/${customer.id}',
        data: customer.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        final data = response.data['customer'] ?? response.data;
        // If API doesn't return the updated object, return the input customer (optimistic) or refetch
        // Assuming API returns updated object
         return Right(CustomerModel.fromJson(data));
      } else {
        return Left(ServerFailure(response.data['message'] ?? 'Failed to update customer'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }

  Future<Either<Failure, void>> deleteCustomer(int id) async {
    try {
      final token = await secureStorage.read(key: 'auth_token');
      final response = await dio.delete(
        '/customers/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (response.statusCode == 200) {
        return const Right(null);
      } else {
        return Left(ServerFailure(response.data['message'] ?? 'Failed to delete customer'));
      }
    } on DioException catch (e) {
      return Left(ServerFailure(e.response?.data['message'] ?? e.message ?? 'Network error'));
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}
