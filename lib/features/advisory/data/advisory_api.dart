import 'package:dio/dio.dart';

import '../../../core/utils/school_year.dart';
import '../models/section_advisory.dart';

/// Calls enrollment-service's `/api/section-advisories/` — read-open to any
/// authenticated user. Per the RBAC handoff: teachers pass
/// `teacher_user_id` to scope to their own sections; staff (registrar,
/// admin, super_admin) omit it and get every section school-wide.
class AdvisoryApi {
  AdvisoryApi(this._enrollment);

  final Dio _enrollment;

  Future<List<SectionAdvisory>> fetchSectionAdvisories({int? teacherUserId}) async {
    final response = await _enrollment.get(
      '/api/section-advisories/',
      queryParameters: {
        if (teacherUserId != null) 'teacher_user_id': teacherUserId,
        'school_year': SchoolYear.current(),
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
    return (results ?? [])
        .cast<Map<String, dynamic>>()
        .map(SectionAdvisory.fromJson)
        .toList();
  }
}
