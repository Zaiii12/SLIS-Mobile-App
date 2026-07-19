import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's manually-selected global school year to on-device
/// storage via `shared_preferences` — a non-sensitive UI preference, so
/// unlike [TokenStorage] this doesn't need Keychain/Keystore. Purely local;
/// the backend default (billing-service's `school-settings/current/`) is
/// only ever used to seed the *first* selection, never synced afterward.
class SchoolYearStore {
  static const _key = 'selected_school_year';

  Future<String?> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  Future<void> save(String year) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, year);
  }
}
