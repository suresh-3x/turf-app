class Service {
  final String id;
  final String vendorId;
  final String name;
  final String description;
  final String category;
  final String location;

  Service({
    required this.id,
    required this.vendorId,
    required this.name,
    required this.description,
    required this.category,
    required this.location,
  });

  Service copyWith({
    String? id,
    String? vendorId,
    String? name,
    String? description,
    String? category,
    String? location,
  }) {
    return Service(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      location: location ?? this.location,
    );
  }

} 