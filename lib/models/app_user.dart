enum UserRole {
  customer,
  vendor;

  static UserRole fromString(String? value) =>
      value == 'vendor' ? UserRole.vendor : UserRole.customer;

  String get label => this == UserRole.vendor ? 'Business owner' : 'Customer';
}

class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
  });

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final String? phone;

  bool get isVendor => role == UserRole.vendor;

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    name: (json['name'] as String?) ?? '',
    email: (json['email'] as String?) ?? '',
    role: UserRole.fromString(json['role'] as String?),
    phone: json['phone'] as String?,
  );
}
