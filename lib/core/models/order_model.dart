import 'package:lastbite/core/models/user_model.dart';
import 'package:lastbite/core/models/order_item_model.dart';
import 'package:lastbite/core/models/payment_model.dart';

class OrderModel {
  final String id;
  final String buyerId;
  final double? totalPrice;
  final String? status; // 'pending_payment', 'paid', 'ready_for_pickup', 'completed'
  final String? paymentStatus; // 'unpaid', 'waiting_verification', 'verified'
  final String? pickupCode;
  final String? deliveryMethod; // 'pickup', 'delivery'
  final DateTime? pickedUpAt;
  final DateTime? createdAt;

  // Relational data
  final UserModel? buyer;
  final List<OrderItemModel>? items;
  final PaymentModel? payment;

  const OrderModel({
    required this.id,
    required this.buyerId,
    this.totalPrice,
    this.status,
    this.paymentStatus,
    this.pickupCode,
    this.deliveryMethod,
    this.pickedUpAt,
    this.createdAt,
    this.buyer,
    this.items,
    this.payment,
  });

  OrderModel copyWith({
    String? id,
    String? buyerId,
    double? totalPrice,
    String? status,
    String? paymentStatus,
    String? pickupCode,
    String? deliveryMethod,
    DateTime? pickedUpAt,
    DateTime? createdAt,
    UserModel? buyer,
    List<OrderItemModel>? items,
    PaymentModel? payment,
  }) {
    return OrderModel(
      id: id ?? this.id,
      buyerId: buyerId ?? this.buyerId,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      pickupCode: pickupCode ?? this.pickupCode,
      deliveryMethod: deliveryMethod ?? this.deliveryMethod,
      pickedUpAt: pickedUpAt ?? this.pickedUpAt,
      createdAt: createdAt ?? this.createdAt,
      buyer: buyer ?? this.buyer,
      items: items ?? this.items,
      payment: payment ?? this.payment,
    );
  }

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    return OrderModel(
      id: json['id'] as String,
      buyerId: json['buyer_id'] as String,
      totalPrice: json['total_price'] != null ? (json['total_price'] as num).toDouble() : null,
      status: json['status'] as String?,
      paymentStatus: json['payment_status'] as String?,
      pickupCode: json['pickup_code'] as String?,
      deliveryMethod: json['delivery_method'] as String?,
      pickedUpAt: json['picked_up_at'] != null 
          ? DateTime.parse(
              (json['picked_up_at'] as String).endsWith('Z') || (json['picked_up_at'] as String).contains('+')
                  ? json['picked_up_at'] as String
                  : '${json['picked_up_at']}Z'
            ).toLocal() 
          : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(
              (json['created_at'] as String).endsWith('Z') || (json['created_at'] as String).contains('+')
                  ? json['created_at'] as String
                  : '${json['created_at']}Z'
            ).toLocal() 
          : null,
      
      // Handle joined relational data
      buyer: json['users'] != null 
          ? (json['users'] is List 
              ? ((json['users'] as List).isNotEmpty ? UserModel.fromJson((json['users'] as List).first) : null)
              : UserModel.fromJson(json['users'])) 
          : null,
      items: json['order_items'] != null
          ? (json['order_items'] is List 
              ? (json['order_items'] as List).map((i) => OrderItemModel.fromJson(i)).toList()
              : [OrderItemModel.fromJson(json['order_items'])])
          : null,
      payment: json['payments'] != null
          ? (json['payments'] is List
              ? ((json['payments'] as List).isNotEmpty ? PaymentModel.fromJson((json['payments'] as List).first) : null)
              : PaymentModel.fromJson(json['payments']))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'buyer_id': buyerId,
      if (totalPrice != null) 'total_price': totalPrice,
      if (status != null) 'status': status,
      if (paymentStatus != null) 'payment_status': paymentStatus,
      if (pickupCode != null) 'pickup_code': pickupCode,
      if (deliveryMethod != null) 'delivery_method': deliveryMethod,
      if (pickedUpAt != null) 'picked_up_at': pickedUpAt!.toIso8601String(),
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
