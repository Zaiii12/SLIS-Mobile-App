import '../models/teacher.dart';
import 'teachers_api.dart';

/// Thin pass-through over [TeachersApi], matching the Dashboard/Advisory/
/// Students repository pattern.
class TeachersRepository {
  TeachersRepository(this._api);

  final TeachersApi _api;

  Future<List<Teacher>> fetchTeachers() => _api.fetchTeachers();
}
