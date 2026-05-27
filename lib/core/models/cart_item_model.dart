import 'package:lastbite/core/models/product_model.dart';

class CartItemModel {
  final ProductModel product;
  final int quantity;
  final bool isSelected;

  CartItemModel({
    required this.product,
    this.quantity = 1,
    this.isSelected = true,
  });

  CartItemModel copyWith({
    ProductModel? product,
    int? quantity,
    bool? isSelected,
  }) {
    return CartItemModel(
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  double get totalPrice => (product.price ?? 0) * quantity;
  double get totalOriginalPrice => (product.originalPrice ?? 0) * quantity;
  double get totalSavings => totalOriginalPrice - totalPrice;
}
