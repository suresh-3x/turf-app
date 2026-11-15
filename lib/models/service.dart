import 'app_user.dart';

class Service {
  const Service({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.category,
    required this.location,
    required this.pricePerSlot,
    this.imageUrl,
    this.isActive = true,
    this.averageRating,
    this.reviewCount = 0,
    this.vendor,
  });

  final String id;
  final String vendorId;
  final String name;
  final String description;
  final String category;
  final String location;
  final double pricePerSlot;
  final String? imageUrl;
  final bool isActive;
  final double? averageRating;
  final int reviewCount;

  /// Only filled in when the query embeds the vendor's profile.
  final AppUser? vendor;

  factory Service.fromJson(Map<String, dynamic> json) {
    final vendorJson = json['vendor'];
    return Service(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      name: (json['name'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      category: (json['category'] as String?) ?? '',
      location: (json['location'] as String?) ?? '',
      pricePerSlot: (json['price_per_slot'] as num?)?.toDouble() ?? 0,
      imageUrl: json['image_url'] as String?,
      isActive: (json['is_active'] as bool?) ?? true,
      vendor: vendorJson is Map<String, dynamic> && vendorJson['id'] != null
          ? AppUser.fromJson(vendorJson)
          : null,
    );
  }

  /// Columns written by the vendor when creating or editing a service.
  Map<String, dynamic> toWriteJson() => {
    'vendor_id': vendorId,
    'name': name,
    'description': description,
    'category': category,
    'location': location,
    'price_per_slot': pricePerSlot,
    'image_url': imageUrl,
    'is_active': isActive,
  };

  Service copyWith({bool? isActive, double? averageRating, int? reviewCount}) => Service(
    id: id,
    vendorId: vendorId,
    name: name,
    description: description,
    category: category,
    location: location,
    pricePerSlot: pricePerSlot,
    imageUrl: imageUrl,
    isActive: isActive ?? this.isActive,
    averageRating: averageRating ?? this.averageRating,
    reviewCount: reviewCount ?? this.reviewCount,
    vendor: vendor,
  );
}
