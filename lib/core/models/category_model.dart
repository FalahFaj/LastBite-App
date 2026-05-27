class CategoryModel {
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final String? colorHex;
  final DateTime? createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    this.colorHex,
    this.createdAt,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      icon: json['icon'] as String?,
      colorHex: json['color_hex'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      if (icon != null) 'icon': icon,
      if (colorHex != null) 'color_hex': colorHex,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
