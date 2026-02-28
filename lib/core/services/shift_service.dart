import 'package:dio/dio.dart';

class ShiftService {
  final Dio dio;

  ShiftService({required this.dio});

  /// Check if the current user has an open shift.
  Future<Map<String, dynamic>> checkShift() async {
    try {
      final response = await dio.get('/shifts/check');
      return response.data;
    } catch (e) {
      throw Exception('Gagal cek shift: $e');
    }
  }

  /// Open a new shift with starting cash.
  Future<Map<String, dynamic>> openShift(double startingCash) async {
    try {
      final response = await dio.post('/shifts/open', data: {
        'starting_cash': startingCash,
      });
      return response.data;
    } catch (e) {
      throw Exception('Gagal membuka shift: $e');
    }
  }

  /// Close the currently open shift.
  Future<Map<String, dynamic>> closeShift(double actualCash, {String? notes}) async {
    try {
      final response = await dio.post('/shifts/close', data: {
        'actual_cash': actualCash,
        'notes': notes,
      });
      return response.data;
    } catch (e) {
      throw Exception('Gagal menutup shift: $e');
    }
  }
}
