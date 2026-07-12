import 'package:dio/dio.dart';

import '../models/student.dart';

/// Calls student-service's `GET /api/students/`. Read-open per the RBAC
/// handoff (teacher: Read; registrar/admin/super_admin: Read + Write — no
/// write endpoints are specified in the handoff yet, so only read is wired
/// here). Supports search by name/LRN and status filtering.
class StudentsApi {
  StudentsApi(this._student);

  final Dio _student;

  Future<List<Student>> fetchStudents({String? search, String? status}) async {
    final response = await _student.get(
      '/api/students/',
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null) 'status': status,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic> ? data['results'] as List? : data as List?;
    return (results ?? []).cast<Map<String, dynamic>>().map(Student.fromJson).toList();
  }
}
