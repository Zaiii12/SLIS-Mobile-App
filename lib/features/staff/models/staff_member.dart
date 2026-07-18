/// A staff account, from identity-service's `GET /api/auth/users/`
/// (`UserSerializer` fields: `user_id`, `name`, `email`, `role`,
/// `profile_picture`) — same shape [Teacher] already uses, but unfiltered by
/// role since the staff directory lists every account, not just teachers.
class StaffMember {
  const StaffMember({
    required this.userId,
    required this.name,
    required this.email,
    required this.role,
    this.profilePicture,
  });

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      userId: json['user_id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      profilePicture: json['profile_picture'] as String?,
    );
  }

  final int userId;
  final String name;
  final String email;
  final String role;
  final String? profilePicture;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}
