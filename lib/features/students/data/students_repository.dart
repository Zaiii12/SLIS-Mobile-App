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
    String? sex,
    String? ordering,
    int page = 1,
  }) {
    return _api.fetchStudents(
      search: search,
      status: status,
      sex: sex,
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

  Future<Student> updateStudent(String id, Map<String, dynamic> body) {
    return _api.updateStudent(id, body);
  }

  /// Looks up a single student by id — used to open [StudentDetailScreen]
  /// from rows (recent enrollments, roster) that only carry a student id,
  /// not the full [Student] record.
  Future<Student> fetchStudentById(String id) {
    return _api.fetchStudentById(id);
  }
}
