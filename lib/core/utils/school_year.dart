/// Computes the current Philippine school year string, e.g. "2025-2026".
///
/// School years run August through the following July, matching the same
/// rule the ASIA web admin portal uses: from August onward the SY starts in
/// the current year; before that, it started the previous year.
class SchoolYear {
  SchoolYear._();

  static String current({DateTime? now}) {
    final date = now ?? DateTime.now();
    final startYear = date.month >= 8 ? date.year : date.year - 1;
    return '$startYear-${startYear + 1}';
  }
}
