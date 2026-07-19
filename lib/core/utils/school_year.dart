/// Computes the current Philippine school year string, e.g. "2025-2026".
///
/// School years run July through the following June, matching the same
/// rule the ASIA web admin portal uses (`computeDefaultSchoolYear` in
/// schoolYear.js): from July onward the SY starts in the current year;
/// before that, it started the previous year.
class SchoolYear {
  SchoolYear._();

  static String current({DateTime? now}) {
    final date = now ?? DateTime.now();
    final startYear = date.month >= 7 ? date.year : date.year - 1;
    return '$startYear-${startYear + 1}';
  }

  /// Nearby school-year options centered on [centerYear], newest first —
  /// mirrors ASIA's `buildSchoolYearOptions` (schoolYear.js). [centerYear]
  /// may be a single year or a "YYYY-YYYY" string; only the leading 4-digit
  /// year is used.
  static List<String> buildOptions(
    String centerYear, {
    int past = 3,
    int future = 1,
  }) {
    final parsed = int.tryParse(
      RegExp(r'^\d{4}').firstMatch(centerYear)?.group(0) ?? '',
    );
    final center = parsed ?? DateTime.now().year;
    final length = past + future + 1;
    return List.generate(length, (i) {
      final y = center + future - i;
      return '$y-${y + 1}';
    });
  }
}
