import '../models/staff_member.dart';
import 'staff_api.dart';

/// Thin pass-through over [StaffApi], matching the Dashboard/Teachers
/// repository pattern.
class StaffRepository {
  StaffRepository(this._api);

  final StaffApi _api;

  Future<List<StaffMember>> fetchStaff() => _api.fetchStaff();
}
