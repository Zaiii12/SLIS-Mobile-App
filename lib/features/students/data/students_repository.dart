import '../models/student.dart';
import 'students_api.dart';

/// Thin pass-through over [StudentsApi]. Kept as its own layer (matching
/// the Dashboard/Advisory pattern) so a future caching layer or write
/// endpoints can slot in without changing the UI's call sites.
class StudentsRepository {
  StudentsRepository(this._api);

  final StudentsApi _api;

  Future<List<Student>> fetchStudents({String? search, String? status}) {
    return _api.fetchStudents(search: search, status: status);
  }
}
