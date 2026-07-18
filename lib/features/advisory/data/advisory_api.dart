import 'package:dio/dio.dart';

import '../models/section_advisory.dart';

/// Calls enrollment-service's `/api/section-advisories/` — read-open to any
/// authenticated user. Per the RBAC handoff: teachers pass
/// `teacher_user_id` to scope to their own sections; staff (registrar,
/// admin, super_admin) omit it and get every section school-wide.
class AdvisoryApi {
  AdvisoryApi(this._enrollment);

  final Dio _enrollment;

  /// Deliberately does not filter by `school_year` server-side: the web
  /// admin portal and this app have each computed "current school year"
  /// with different cutover-month rules at different times, so a teacher's
  /// advisory row can be saved under a school_year string this app doesn't
  /// expect, causing exact-match filtering to silently return zero rows.
  /// Instead we fetch every advisory for the teacher and let
  /// [SectionAdvisory.forMostRecentSchoolYear] pick the latest school year
  /// client-side.
  Future<List<SectionAdvisory>> fetchSectionAdvisories({int? teacherUserId}) async {
    final response = await _enrollment.get(
      '/api/section-advisories/',
      queryParameters: {
        if (teacherUserId != null) 'teacher_user_id': teacherUserId,
        // Default DRF pagination is PAGE_SIZE=20 (enrollment_service
        // settings) — without this, schools with >20 section advisories
        // silently lose everything past the first page (ordered
        // `-school_year, grade_level, section`), e.g. Monitoring's
        // School Level/Grade Level filters only showing whatever grade
        // sorts first. MAX_PAGE_SIZE is 500.
        'page_size': 500,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
    final advisories = (results ?? [])
        .cast<Map<String, dynamic>>()
        .map(SectionAdvisory.fromJson)
        .toList();
    return SectionAdvisory.forMostRecentSchoolYear(advisories);
  }
}
