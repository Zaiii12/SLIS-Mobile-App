import '../../dashboard/models/dashboard_data.dart';
import '../models/attendance_status.dart';
import '../models/roster_entry.dart';
import 'attendance_api.dart';

class AttendanceRepository {
  AttendanceRepository(this._api);

  final AttendanceApi _api;

  Future<AttendanceBreakdown> fetchSummary(DateTime date) => _api.fetchSummary(date);

  Future<List<RosterEntry>> fetchRoster(int sectionAdvisoryId) =>
      _api.fetchRoster(sectionAdvisoryId);

  Future<Map<int, AttendanceStatus>> fetchExisting({
    required int sectionAdvisoryId,
    required DateTime date,
  }) =>
      _api.fetchExisting(sectionAdvisoryId: sectionAdvisoryId, date: date);

  Future<void> submitBulk({required Map<int, AttendanceStatus> marks, required DateTime date}) =>
      _api.submitBulk(marks: marks, date: date);
}
