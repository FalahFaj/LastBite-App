class UserModel {
  final String id;
  final String? name;
  final String? phone;
  final String? userPictureUrl;
  final String? address;
  final double? latitude;
  final double? longitude;
  final DateTime? createdAt;
  final bool notifyNearbyDiscounts;
  final bool notifyExpiringOffers;

  const UserModel({
    required this.id,
    this.name,
    this.phone,
    this.userPictureUrl,
    this.address,
    this.latitude,
    this.longitude,
    this.createdAt,
    this.notifyNearbyDiscounts = true,
    this.notifyExpiringOffers = true,
  });

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    String? userPictureUrl,
    String? address,
    double? latitude,
    double? longitude,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      userPictureUrl: userPictureUrl ?? this.userPictureUrl,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdAt: createdAt ?? this.createdAt,
      notifyNearbyDiscounts: notifyNearbyDiscounts ?? this.notifyNearbyDiscounts,
      notifyExpiringOffers: notifyExpiringOffers ?? this.notifyExpiringOffers,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      userPictureUrl: json['user_picture_url'] as String? ?? json['avatar_url'] as String?,
      address: json['address'] as String?,
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : null,
      notifyNearbyDiscounts: json['notify_nearby_discounts'] as bool? ?? true,
      notifyExpiringOffers: json['notify_expiring_offers'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (userPictureUrl != null) 'user_picture_url': userPictureUrl,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'notify_nearby_discounts': notifyNearbyDiscounts,
      'notify_expiring_offers': notifyExpiringOffers,
    };
  }
}

