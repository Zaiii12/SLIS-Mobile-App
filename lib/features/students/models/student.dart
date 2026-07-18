/// The real `Student.status` choices (`students/models.py` in
/// student-service) — five values, not just active/inactive.
enum StudentStatus { active, inactive, transferred, graduated, dropped }

extension StudentStatusLabel on StudentStatus {
  String get label {
    switch (this) {
      case StudentStatus.active:
        return 'Active';
      case StudentStatus.inactive:
        return 'Inactive';
      case StudentStatus.transferred:
        return 'Transferred';
      case StudentStatus.graduated:
        return 'Graduated';
      case StudentStatus.dropped:
        return 'Dropped';
    }
  }

  /// The exact `status` query param value the backend expects.
  String get apiValue {
    switch (this) {
      case StudentStatus.active:
        return 'active';
      case StudentStatus.inactive:
        return 'inactive';
      case StudentStatus.transferred:
        return 'transferred';
      case StudentStatus.graduated:
        return 'graduated';
      case StudentStatus.dropped:
        return 'dropped';
    }
  }
}

StudentStatus studentStatusFromJson(String value) {
  switch (value) {
    case 'active':
      return StudentStatus.active;
    case 'transferred':
      return StudentStatus.transferred;
    case 'graduated':
      return StudentStatus.graduated;
    case 'dropped':
      return StudentStatus.dropped;
    default:
      return StudentStatus.inactive;
  }
}

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
    this.updatedAt,
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
      updatedAt: json['updated_at'] as String?,
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

  /// Server-side `updated_at` timestamp, echoed back on PATCH for
  /// student-service's optimistic-locking check (see StudentSerializer.validate
  /// in ASIA's student-service) — prevents silently clobbering a concurrent edit.
  final String? updatedAt;

  /// Fields the backend actually allows registrar/admin to write
  /// (`StudentSerializer` — `student_id`/`lrn`/`updated_at` are read-only or
  /// system-managed and intentionally excluded here).
  Map<String, dynamic> toEditJson() {
    return {
      'first_name': firstName,
      'middle_name': middleName.isEmpty ? null : middleName,
      'last_name': lastName,
      'suffix': suffix,
      'status': status,
      'birth_date': birthDate,
      'sex': sex,
      'current_address': address,
      if (updatedAt != null) 'updated_at': updatedAt,
    };
  }

  Student copyWith({
    String? firstName,
    String? middleName,
    String? lastName,
    String? suffix,
    String? status,
    String? birthDate,
    String? sex,
    String? address,
  }) {
    return Student(
      id: id,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      suffix: suffix ?? this.suffix,
      lrn: lrn,
      status: status ?? this.status,
      birthDate: birthDate ?? this.birthDate,
      sex: sex ?? this.sex,
      address: address ?? this.address,
      updatedAt: updatedAt,
    );
  }

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

  /// One of `active`/`inactive`/`transferred`/`graduated`/`dropped` — the
  /// real `Student.status` choices (`students/models.py`), matching ASIA
  /// web's `STATUS_META`/`STATUS_FILTERS`.
  StudentStatus get statusValue => studentStatusFromJson(status);

  /// Two-letter initials for the list/detail avatar, e.g. "MG" for "Isabella Garcia".
  String get initials {
    final first = firstName.isNotEmpty ? firstName[0] : '';
    final last = lastName.isNotEmpty ? lastName[0] : '';
    final combined = (first + last).toUpperCase();
    return combined.isEmpty ? '?' : combined;
  }
}
