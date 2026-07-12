/// A student record from student-service's `GET /api/students/`. Field
/// names confirmed against a live response — the name is split across
/// first/middle/last/suffix, and there is no level/enrollment_status/
/// school_year here (those live on the enrollment record in
/// enrollment-service, not on the student record itself).
class Student {
  const Student({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.suffix,
    required this.lrn,
    required this.status,
    required this.birthDate,
    required this.sex,
    required this.address,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: json['student_id'].toString(),
      firstName: json['first_name'] as String? ?? '',
      middleName: json['middle_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      suffix: json['suffix'] as String?,
      lrn: json['lrn']?.toString() ?? '',
      status: json['status'] as String? ?? 'active',
      birthDate: json['birth_date'] as String? ?? '',
      sex: json['sex'] as String? ?? '',
      address: json['current_address'] as String? ?? '',
    );
  }

  final String id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String? suffix;
  final String lrn;
  final String status;
  final String birthDate;
  final String sex;
  final String address;

  String get name {
    final parts = [
      firstName,
      middleName,
      lastName,
      if (suffix != null && suffix!.isNotEmpty) suffix,
    ].where((p) => p != null && p.isNotEmpty);
    return parts.join(' ');
  }

  bool get isActive => status == 'active';

  /// Two-letter initials for the list/detail avatar, e.g. "MG" for "Isabella Garcia".
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final combined = (first + last).toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }
}
