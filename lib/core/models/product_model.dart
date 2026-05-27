import 'package:flutter/material.dart';
import 'package:lastbite/core/models/merchant_model.dart';
import 'package:lastbite/core/models/category_model.dart';

class ProductModel {
  final String id;
  final String merchantId;
  final String? name;
  final String? description;
  final double? price;
  final double? originalPrice;
  final String? image;
  final TimeOfDay? pickupStart;
  final TimeOfDay? pickupEnd;
  final String? status; // 'available', 'reserved', 'sold'
  final DateTime? createdAt;
  final String? categoryId; // Added for category
  final int? stock;

  // Relational data
  final MerchantModel? merchant;
  final CategoryModel? category; // Added for category relations

  const ProductModel({
    required this.id,
    required this.merchantId,
    this.name,
    this.description,
    this.price,
    this.originalPrice,
    this.image,
    this.pickupStart,
    this.pickupEnd,
    this.status,
    this.createdAt,
    this.categoryId,
    this.stock,
    this.merchant,
    this.category,
  });

  ProductModel copyWith({
    String? id,
    String? merchantId,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? image,
    TimeOfDay? pickupStart,
    TimeOfDay? pickupEnd,
    String? status,
    DateTime? createdAt,
    String? categoryId,
    int? stock,
    MerchantModel? merchant,
    CategoryModel? category,
  }) {
    return ProductModel(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      image: image ?? this.image,
      pickupStart: pickupStart ?? this.pickupStart,
      pickupEnd: pickupEnd ?? this.pickupEnd,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      categoryId: categoryId ?? this.categoryId,
      stock: stock ?? this.stock,
      merchant: merchant ?? this.merchant,
      category: category ?? this.category,
    );
  }

  // Helper for parsing Supabase 'time' (HH:mm:ss) string to Flutter TimeOfDay
  static TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length >= 2) {
      return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 0, 
        minute: int.tryParse(parts[1]) ?? 0
      );
    }
    return null;
  }

  // Helper for formatting Flutter TimeOfDay to Supabase 'time' (HH:mm:ss) string
  static String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:00';
  }

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      merchantId: (json['merchant_id'] as String?) ?? '',
      name: json['name'] as String?,
      description: json['description'] as String?,
      price: json['price'] != null ? (json['price'] as num).toDouble() : null,
      originalPrice: json['original_price'] != null ? (json['original_price'] as num).toDouble() : null,
      image: json['image'] as String?,
      pickupStart: _parseTime(json['pickup_start'] as String?),
      pickupEnd: _parseTime(json['pickup_end'] as String?),
      status: json['status'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
      categoryId: json['category_id'] as String?,
      stock: json['stock'] as int?,
      merchant: json['merchants'] != null
          ? (json['merchants'] is List
              ? ((json['merchants'] as List).isNotEmpty 
                  ? MerchantModel.fromJson((json['merchants'] as List).first as Map<String, dynamic>) 
                  : null)
              : MerchantModel.fromJson(json['merchants'] as Map<String, dynamic>))
          : null,
      category: json['categories'] != null
          ? (json['categories'] is List
              ? ((json['categories'] as List).isNotEmpty 
                  ? CategoryModel.fromJson((json['categories'] as List).first as Map<String, dynamic>) 
                  : null)
              : CategoryModel.fromJson(json['categories'] as Map<String, dynamic>))
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'merchant_id': merchantId,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (price != null) 'price': price,
      if (originalPrice != null) 'original_price': originalPrice,
      if (image != null) 'image': image,
      if (pickupStart != null) 'pickup_start': _formatTime(pickupStart),
      if (pickupEnd != null) 'pickup_end': _formatTime(pickupEnd),
      if (status != null) 'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (categoryId != null) 'category_id': categoryId,
      if (stock != null) 'stock': stock,
    };
  }
}
