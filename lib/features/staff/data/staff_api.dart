import 'package:dio/dio.dart';

import '../models/staff_member.dart';

/// Calls identity-service's `GET /api/auth/users/` (`UserListView`, gated
/// server-side to `ADMIN_ROLES` — `admin`/`super_admin` only, confirmed in
/// `accounts/audit.py`). Unpaginated: returns a plain JSON array, not DRF's
/// `{count, next, previous, results}` envelope.
class StaffApi {
  StaffApi(this._identity);

  final Dio _identity;

  Future<List<StaffMember>> fetchStaff() async {
    final response = await _identity.get('/api/auth/users/');
    final results = (response.data as List).cast<Map<String, dynamic>>();
    return results.map(StaffMember.fromJson).toList();
  }
}
