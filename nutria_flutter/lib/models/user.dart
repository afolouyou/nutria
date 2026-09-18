class User {
  final String id;
  final String email;
  final String name;
  final String provider;
  final String? avatar;

  const User({
    required this.id,
    required this.email,
    required this.name,
    required this.provider,
    this.avatar,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'])?.toString() ?? '',
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      provider: (json['provider'] ?? 'local').toString(),
      avatar: json['avatar_url']?.toString() ?? json['avatar']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'provider': provider,
      if (avatar != null) 'avatar': avatar,
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? provider,
    String? avatar,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      provider: provider ?? this.provider,
      avatar: avatar ?? this.avatar,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          other.id == id &&
          other.email == email &&
          other.name == name &&
          other.provider == provider &&
          other.avatar == avatar;

  @override
  int get hashCode => Object.hash(id, email, name, provider, avatar);

  @override
  String toString() => 'User(id: $id, email: $email, name: $name, provider: $provider)';
}
