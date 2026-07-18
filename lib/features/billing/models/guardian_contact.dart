/// A guardian contact record from student-service's `GET /api/guardians/`
/// (`students/models.py:133`). A student can have multiple guardian rows
/// (mother/father/guardian) — callers should prefer the one with
/// `isPrimaryContact == true`.
class GuardianContact {
  const GuardianContact({
    required this.fullName,
    required this.relationship,
    required this.mobileNumber,
    required this.emailAddress,
    required this.isPrimaryContact,
  });

  factory GuardianContact.fromJson(Map<String, dynamic> json) {
    return GuardianContact(
      fullName: json['full_name'] as String? ?? '',
      relationship: json['relationship'] as String? ?? '',
      mobileNumber: json['mobile_number'] as String?,
      emailAddress: json['email_address'] as String?,
      isPrimaryContact: json['is_primary_contact'] as bool? ?? false,
    );
  }

  final String fullName;
  final String relationship;
  final String? mobileNumber;
  final String? emailAddress;
  final bool isPrimaryContact;
}
