class User {
  final String id;
  final String username;
  final String email;
  final String avatar;
  final String status;

  User({
    required this.id,
    required this.username,
    required this.email,
    this.avatar = '',
    this.status = 'offline',
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? json['_id'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar'] ?? '',
      status: json['status'] ?? 'offline',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'avatar': avatar,
      'status': status,
    };
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? avatar,
    String? status,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      avatar: avatar ?? this.avatar,
      status: status ?? this.status,
    );
  }
}
