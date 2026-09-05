class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? phone;
  final String? location;
  final String? organization;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    this.role = 'customer',
    this.phone,
    this.location,
    this.organization,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id']?.toString() ?? '',
      email: json['email'] ?? '',
      name: json['name'] ?? '',
      role: json['role']?.toString() ?? 'customer',
      phone: json['phone']?.toString(),
      location: json['location']?.toString(),
      organization: json['organization']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role,
      'phone': phone,
      'location': location,
      'organization': organization,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? phone,
    String? location,
    String? organization,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      organization: organization ?? this.organization,
    );
  }
}

