class AdminModel {
  final String uid;
  final String email;
  final String role; // 'super_admin', 'moderator', 'support'
  final List<String> permissions;
  final DateTime createdAt;
  final DateTime? lastLogin;

  AdminModel({
    required this.uid,
    required this.email,
    this.role = 'moderator',
    this.permissions = const [],
    required this.createdAt,
    this.lastLogin,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'permissions': permissions,
      'createdAt': createdAt.toIso8601String(),
      'lastLogin': lastLogin?.toIso8601String(),
    };
  }

  factory AdminModel.fromMap(Map<String, dynamic> map) {
    return AdminModel(
      uid: map['uid'] ?? '',
      email: map['email'] ?? '',
      role: map['role'] ?? 'moderator',
      permissions: List<String>.from(map['permissions'] ?? []),
      createdAt: DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      lastLogin: map['lastLogin'] != null ? DateTime.parse(map['lastLogin']) : null,
    );
  }
}