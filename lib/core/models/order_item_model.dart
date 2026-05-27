import 'package:lastbite/core/models/product_model.dart';

class OrderItemModel {
  final String id;
  final String orderId;
  final String productId;
  final int? quantity;
  final double? price;

  // Relational data
  final ProductModel? product;

  const OrderItemModel({
    required this.id,
    required this.orderId,
    required this.productId,
    this.quantity,
    this.price,
    this.product,
  });

  OrderItemModel copyWith({
    String? id,
    String? orderId,
    String? productId,
    int? quantity,
    double? price,
    ProductModel? product,
  }) {
    return OrderItemModel(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      product: product ?? this.product,
    );
  }

  factory OrderItemModel.fromJson(Map<String, dynamic> json) {
    return OrderItemModel(
      id: json['id'] as String? ?? '',
      orderId: json['order_id'] as String? ?? '',
      productId: json['product_id'] as String? ?? '',
      quantity: json['quantity'] as int?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      // Handle joined product data
      product: json['products'] != null ? ProductModel.fromJson(json['products']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'product_id': productId,
      if (quantity != null) 'quantity': quantity,
      if (price != null) 'price': price,
    };
  }
}
