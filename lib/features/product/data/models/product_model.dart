import 'package:equatable/equatable.dart';

class ProductModel extends Equatable {
  final int id;
  final int? productGroupId;
  final int categoryId;
  final String name;
  final String? variantName;
  final String? barcode;
  final double purchasePrice;
  final double sellingPrice;
  final int stock;
  final int minimumStock;
  final String? image;
  final String? description;
  final bool isLowStock;
  final String type;
  final double? commissionAmount;

  const ProductModel({
    required this.id,
    this.productGroupId,
    required this.categoryId,
    required this.name,
    this.variantName,
    this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.stock,
    required this.minimumStock,
    this.image,
    this.description,
    required this.isLowStock,
    this.type = 'barang',
    this.commissionAmount,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'],
      productGroupId: json['product_group_id'] is String ? int.tryParse(json['product_group_id']) : json['product_group_id'],
      categoryId: json['category_id'] is String ? int.parse(json['category_id']) : json['category_id'],
      name: json['name'],
      variantName: json['variant_name'],
      barcode: json['barcode'],
      purchasePrice: (json['purchase_price'] is String ? double.tryParse(json['purchase_price']) : (json['purchase_price'] as num?)?.toDouble()) ?? 0.0,
      sellingPrice: (json['selling_price'] is String ? double.tryParse(json['selling_price']) : (json['selling_price'] as num?)?.toDouble()) ?? 0.0,
      stock: (json['stock'] is String ? int.tryParse(json['stock']) : json['stock']) ?? 0,
      minimumStock: (json['minimum_stock'] is String ? int.tryParse(json['minimum_stock']) : json['minimum_stock']) ?? 0,
      image: json['image_url'] ?? json['image'],
      description: json['description'],
      isLowStock: json['is_low_stock'] == 1 || json['is_low_stock'] == true || json['is_low_stock'] == '1',
      type: json['type'] ?? 'barang',
      commissionAmount: (json['commission_amount'] is String ? double.tryParse(json['commission_amount']) : (json['commission_amount'] as num?)?.toDouble()),
    );
  }



  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_group_id': productGroupId,
      'category_id': categoryId,
      'name': name,
      'variant_name': variantName,
      'barcode': barcode,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
      'stock': stock,
      'minimum_stock': minimumStock,
      'image': image,
      'description': description,
      'is_low_stock': isLowStock ? 1 : 0,
      'type': type,
      'commission_amount': commissionAmount,
    };
  }

  @override
  List<Object?> get props => [id, name, barcode, sellingPrice, stock];
}
