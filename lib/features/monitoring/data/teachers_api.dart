import 'package:dio/dio.dart';

import '../models/teacher.dart';

/// Calls identity-service's `GET /api/auth/users/` — lists every user
/// unpaginated, gated server-side to `ADMIN_ROLES` (`admin`/`super_admin`,
/// NOT `registrar` — confirmed in `accounts/audit.py`). Callers must be
/// admin/super_admin or this 403s.
class TeachersApi {
  TeachersApi(this._identity);

  final Dio _identity;

  /// The endpoint has no server-side role filter, so every user is fetched
  /// and non-teachers are dropped client-side.
  Future<List<Teacher>> fetchTeachers() async {
    final response = await _identity.get('/api/auth/users/');
    final results = (response.data as List).cast<Map<String, dynamic>>();
    return results.where((r) => r['role'] == 'teacher').map(Teacher.fromJson).toList();
  }
}
