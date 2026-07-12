import 'students_api.dart';

/// Thin pass-through over [StudentsApi]. Kept as its own layer (matching
/// the Dashboard/Advisory pattern) so a future caching layer or write
/// endpoints can slot in without changing the UI's call sites.
class StudentsRepository {
  StudentsRepository(this._api);

  final StudentsApi _api;

  Future<StudentsPage> fetchStudents({String? search, String? status, int page = 1}) {
    return _api.fetchStudents(search: search, status: status, page: page);
  }
}
