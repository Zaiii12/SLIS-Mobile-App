import 'calendar_api.dart';

/// Thin pass-through over [CalendarApi], matching the Dashboard/Billing
/// repository pattern.
class CalendarRepository {
  CalendarRepository(this._api);

  final CalendarApi _api;

  Future<CalendarEventsPage> fetchEvents({
    String? schoolYear,
    String? eventType,
    String? search,
    String ordering = 'start_date',
    int page = 1,
    int pageSize = 200,
  }) {
    return _api.fetchEvents(
      schoolYear: schoolYear,
      eventType: eventType,
      search: search,
      ordering: ordering,
      page: page,
      pageSize: pageSize,
    );
  }
}
