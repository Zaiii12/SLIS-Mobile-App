import '../models/student.dart';
import 'students_api.dart';

/// Thin pass-through over [StudentsApi]. Kept as its own layer (matching
/// the Dashboard/Advisory pattern) so a future caching layer or write
/// endpoints can slot in without changing the UI's call sites.
class StudentsRepository {
  StudentsRepository(this._api);

  final StudentsApi _api;

  Future<StudentsPage> fetchStudents({
    String? search,
    String? status,
    String? ordering,
    int page = 1,
  }) {
    return _api.fetchStudents(
      search: search,
      status: status,
      ordering: ordering,
      page: page,
    );
  }

  /// Newest-first slice for the admin dashboard's "Recently Added Students"
  /// card. `student_id` (auto-incrementing PK) is the only real proxy for
  /// creation order — `StudentViewSet` has no `created_at` field at all.
  Future<List<Student>> fetchRecentStudents({int limit = 5}) async {
    final page = await fetchStudents(ordering: '-student_id', page: 1);
    return page.students.take(limit).toList();
  }
}
