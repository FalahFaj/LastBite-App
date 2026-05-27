class BannerModel {
  final String id;
  final String imageUrl;
  final String title;
  final bool isActive;
  final String? actionUrl;
  final String position;
  final DateTime? createdAt;

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.title,
    required this.isActive,
    this.actionUrl,
    required this.position,
    this.createdAt,
  });

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      title: json['title'] as String,
      isActive: json['is_active'] as bool? ?? true,
      actionUrl: json['action_url'] as String?,
      position: json['position'] as String,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(
              (json['created_at'] as String).endsWith('Z') || (json['created_at'] as String).contains('+')
                  ? json['created_at']
                  : '${json['created_at']}Z',
            ).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_url': imageUrl,
      'title': title,
      'is_active': isActive,
      if (actionUrl != null) 'action_url': actionUrl,
      'position': position,
      if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
    };
  }
}
