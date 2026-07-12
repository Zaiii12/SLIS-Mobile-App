import 'package:dio/dio.dart';

import '../models/student.dart';

/// A single page of `/api/students/` results. Student-service paginates at
/// 20/page by default (`StandardPagination`, confirmed in
/// `student_service/settings.py`) with standard DRF `{count, next, previous,
/// results}` shape, so callers must page through `hasMore`/`fetchStudents`
/// with an incrementing `page` rather than assuming one call returns
/// everything.
class StudentsPage {
  const StudentsPage({required this.students, required this.hasMore});

  final List<Student> students;
  final bool hasMore;
}

/// Calls student-service's `GET /api/students/`. Read-open per the RBAC
/// handoff (teacher: Read; registrar/admin/super_admin: Read + Write — no
/// write endpoints are specified in the handoff yet, so only read is wired
/// here). Supports search by name/LRN and status filtering.
class StudentsApi {
  StudentsApi(this._student);

  final Dio _student;

  Future<StudentsPage> fetchStudents({String? search, String? status, int page = 1}) async {
    final response = await _student.get(
      '/api/students/',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
        'page': page,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
    final hasMore = data is Map<String, dynamic> && data['next'] != null;
    return StudentsPage(
      students: (results ?? []).cast<Map<String, dynamic>>().map(Student.fromJson).toList(),
      hasMore: hasMore,
    );
  }
}
