import 'package:flutter/foundation.dart';

import '../data/advisory_api.dart';
import '../models/section_advisory.dart';

enum AdvisoryStatus { initial, loading, loaded, error }

/// Shared cache of the current user's [SectionAdvisory] list, fetched once
/// on login and read by both Attendance and Grades (per the RBAC handoff,
/// this avoids fetching `/api/section-advisories/` twice). A teacher with no
/// advisory rows gets an empty (not error) list — the doc is explicit that
/// this is a valid, intentional state ("No sections assigned"), not a
/// failure.
class AdvisoryProvider extends ChangeNotifier {
  AdvisoryProvider({required AdvisoryApi advisoryApi}) : _advisoryApi = advisoryApi;

  final AdvisoryApi _advisoryApi;

  AdvisoryStatus _status = AdvisoryStatus.initial;
  List<SectionAdvisory> _advisories = const [];
  String? _errorMessage;

  AdvisoryStatus get status => _status;
  List<SectionAdvisory> get advisories => _advisories;
  String? get errorMessage => _errorMessage;

  /// True once a successful fetch returned zero rows — teacher has no
  /// SectionAdvisory assigned. Distinct from [AdvisoryStatus.error].
  bool get hasNoSectionsAssigned => _status == AdvisoryStatus.loaded && _advisories.isEmpty;

  /// Fetches the advisory list. Pass [teacherUserId] for a teacher role;
  /// omit (null) for staff roles to get all sections school-wide.
  Future<void> load({int? teacherUserId}) async {
    _status = AdvisoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _advisories = await _advisoryApi.fetchSectionAdvisories(teacherUserId: teacherUserId);
      _status = AdvisoryStatus.loaded;
    } catch (_) {
      _status = AdvisoryStatus.error;
      _errorMessage = 'Unable to load sections. Check your connection and try again.';
    }
    notifyListeners();
  }

  /// Clears cached advisory data on logout so the next login starts fresh.
  void clear() {
    _status = AdvisoryStatus.initial;
    _advisories = const [];
    _errorMessage = null;
    notifyListeners();
  }
}
