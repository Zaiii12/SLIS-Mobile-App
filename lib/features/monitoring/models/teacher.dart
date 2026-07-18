/// A teacher account, from identity-service's `GET /api/auth/users/`
/// (`UserSerializer` fields: `user_id`, `name`, `email`, `role`,
/// `profile_picture`). That endpoint lists every user regardless of role,
/// so [Teacher.fromJson] is only ever called after filtering `role ==
/// 'teacher'` client-side — there is no server-side role filter.
class Teacher {
  const Teacher({required this.userId, required this.name, required this.email});

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      userId: json['user_id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  final int userId;
  final String name;
  final String email;
}
