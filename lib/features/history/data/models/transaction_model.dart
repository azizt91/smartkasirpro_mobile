import 'dart:convert';
import 'package:equatable/equatable.dart';

class TransactionModel extends Equatable {
  final int? id; // Server ID
  final String transactionCode;
  final double totalAmount;
  final String paymentMethod;
  final String createdAt;
  final String status; // NEW
  final Map<String, dynamic> payload; // Full details
  final bool isSynced; // Helper for UI

  const TransactionModel({
    this.id,
    required this.transactionCode,
    required this.totalAmount,
    required this.paymentMethod,
    required this.createdAt,
    this.status = 'completed',
    required this.payload,
    this.isSynced = true,
  });

  String? get customerName => payload['customer_name'] as String?;
  String get paymentStatus => payload['payment_status'] as String? ?? 'paid';
  String get orderStatus => payload['order_status'] as String? ?? 'completed';

  double _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  double get subtotal => _parseDouble(payload['subtotal']);
  double get discount => _parseDouble(payload['discount']);
  double get tax => _parseDouble(payload['tax']);
  double get amountPaid => _parseDouble(payload['amount_paid']);
  double get changeAmount => _parseDouble(payload['change_amount']);

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    // Check if it's from Server (nested structure) or Local Cache (flat structure)
    // Server: {id, transaction_code, total_amount, payment_method, created_at, items: [...], ...}
    // Local Cache: {id, transaction_code, total_amount, payment_method, created_at, payload: "..."}
    
    if (json.containsKey('payload') && json['payload'] is String) {
       // From Local Cache
       final payloadMap = jsonDecode(json['payload']);
       return TransactionModel(
         id: json['id'],
         transactionCode: json['transaction_code'] ?? '',
         totalAmount: (json['total_amount'] is num)
             ? (json['total_amount'] as num).toDouble()
             : double.tryParse(json['total_amount'].toString()) ?? 0.0,
         paymentMethod: json['payment_method'] ?? '',
         createdAt: json['created_at'],
         status: json['status'] ?? 'completed',
         payload: payloadMap,
         isSynced: true,
       );
    } else {
       // From Server
       return TransactionModel(
         id: json['id'],
         transactionCode: json['transaction_code'] ?? '',
         totalAmount: (json['total_amount'] is num)
             ? (json['total_amount'] as num).toDouble()
             : double.tryParse(json['total_amount'].toString()) ?? 0.0,
         paymentMethod: json['payment_method'] ?? '',
         createdAt: json['created_at'],
         status: json['status'] ?? 'completed',
         payload: json, // Store full object as payload
         isSynced: true,
       );
    }
  }

  factory TransactionModel.fromPending(Map<String, dynamic> json) {
    // From PendingTransactions table
    // {id, payload: "...", created_at, status}
    final payloadMap = jsonDecode(json['payload']);
    
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return TransactionModel(
      id: null, // No Server ID yet
      transactionCode: payloadMap['transaction_code'] ?? 'PENDING',
      totalAmount: parseDouble(payloadMap['total_amount']),
      paymentMethod: payloadMap['payment_method'] ?? '',
      createdAt: json['created_at'],
      status: 'pending',
      payload: payloadMap,
      isSynced: false,
    );
  }

  Map<String, dynamic> toCachedMap() {
    return {
      'id': id,
      'transaction_code': transactionCode,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'created_at': createdAt,
      'status': status,
      'payload': jsonEncode(payload),
    };
  }

  /// Returns the full data map suitable for receipt printing
  Map<String, dynamic> toJson() {
    final data = Map<String, dynamic>.from(payload);
    data['id'] = id;
    data['transaction_code'] = transactionCode;
    data['total_amount'] = totalAmount;
    data['payment_method'] = paymentMethod;
    data['created_at'] = createdAt;
    data['status'] = status;
    return data;
  }

  @override
  List<Object?> get props => [id, transactionCode, totalAmount, isSynced, status];
}
