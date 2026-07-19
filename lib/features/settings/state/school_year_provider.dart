import 'package:flutter/foundation.dart';

import '../../../core/utils/school_year.dart';
import '../../billing/data/billing_repository.dart';
import '../data/school_year_store.dart';

/// Global "school year" filter, shared by every year-scoped screen
/// (Dashboard, Financial Stats, Calendar) — matches the ASIA web admin
/// portal's `SchoolYearContext`. [schoolYear]/[options] are always readable
/// synchronously (seeded from [SchoolYear.current] at construction) so
/// `context.watch`/`context.read` is safe before [initialize] resolves.
///
/// Resolution order on first launch: [options] is always centered on the
/// real current year (backend's `school-settings/current/`, falling back to
/// [SchoolYear.current] if that fails) — a persisted user selection only
/// overrides [schoolYear] itself, never re-centers [options], so switching
/// back and forth never loses real future years from the list. Once the
/// user manually picks a year via [setSchoolYear], that choice is persisted
/// and wins over the backend default on every future launch.
class SchoolYearProvider extends ChangeNotifier {
  SchoolYearProvider({
    required this._billingRepository,
    required this._store,
  }) : _schoolYear = SchoolYear.current(),
       _options = SchoolYear.buildOptions(SchoolYear.current());

  final BillingRepository _billingRepository;
  final SchoolYearStore _store;
  bool _initialized = false;

  String _schoolYear;
  List<String> _options;

  String get schoolYear => _schoolYear;
  List<String> get options => _options;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // [_options] is always centered on the real current year (backend's
    // current_school_year, falling back to SchoolYear.current()) — NOT on
    // whatever the persisted/picked selection is. Otherwise a persisted
    // selection from a past year would permanently hide real future years
    // from the picker (see the mobile app's school-year filter bug: picking
    // 2023-2024 once re-centered the whole list around it, so 2025-2026/
    // 2026-2027 disappeared even after switching to a later year).
    String currentYear;
    try {
      final backendYear = await _billingRepository.fetchCurrentSchoolYear();
      currentYear = (backendYear != null && backendYear.isNotEmpty)
          ? backendYear
          : SchoolYear.current();
    } catch (_) {
      currentYear = SchoolYear.current();
    }
    _options = SchoolYear.buildOptions(currentYear);

    final persisted = await _store.load();
    if (persisted != null && persisted.isNotEmpty) {
      _schoolYear = persisted;
      if (!_options.contains(persisted)) {
        _options = [persisted, ..._options]..sort((a, b) => b.compareTo(a));
      }
      notifyListeners();
      return;
    }

    _schoolYear = currentYear;
    notifyListeners();
    await _store.save(currentYear);
  }

  Future<void> setSchoolYear(String year) async {
    if (year == _schoolYear) return;
    _schoolYear = year;
    // [_options] deliberately does NOT recenter on [year] — it stays
    // anchored to the real current year resolved in [initialize]. Extend
    // (rather than replace) the list only if [year] falls outside it, so a
    // manually-typed/out-of-range value is still selectable without losing
    // the real future years.
    if (!_options.contains(year)) {
      _options = [year, ..._options]..sort((a, b) => b.compareTo(a));
    }
    notifyListeners();
    await _store.save(year);
  }
}
