class MerchantModel {
  final String id;
  final String userId;
  final String storeName;
  final String? category;
  final String? ownerName;
  final String? officePhone;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? avatarUrl;
  final DateTime? createdAt;

  MerchantModel({
    required this.id,
    required this.userId,
    required this.storeName,
    this.category,
    this.ownerName,
    this.officePhone,
    this.location,
    this.latitude,
    this.longitude,
    this.avatarUrl,
    this.createdAt,
  });

  factory MerchantModel.fromJson(Map<String, dynamic> json) {
    return MerchantModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      storeName: json['store_name'] as String,
      category: json['category'] as String?,
      ownerName: json['owner_name'] as String?,
      officePhone: json['office_phone'] as String?,
      location: json['location'] as String?,
      latitude: json['latitude'] != null ? double.parse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.parse(json['longitude'].toString()) : null,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'store_name': storeName,
      if (category != null) 'category': category,
      if (ownerName != null) 'owner_name': ownerName,
      if (officePhone != null) 'office_phone': officePhone,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    };
  }
}
