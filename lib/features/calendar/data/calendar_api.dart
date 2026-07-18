import 'package:dio/dio.dart';

import '../models/calendar_event.dart';

/// A single page of `/api/calendar-events/` results. enrollment-service
/// paginates via `CalendarPagination` (20/page, max 500) with standard DRF
/// `{count, next, previous, results}` shape.
class CalendarEventsPage {
  const CalendarEventsPage({required this.events, required this.hasMore});

  final List<CalendarEvent> events;
  final bool hasMore;
}

/// Calls enrollment-service's `GET /api/calendar-events/`
/// (`CalendarEventViewSet`, `academic_calendar/views.py`), gated
/// server-side to `IsAdminRegistrarOrReadOnly` — every authenticated
/// non-guardian staff role can read; only admin/super_admin/registrar can
/// write. This app only reads for now.
class CalendarApi {
  CalendarApi(this._enrollment);

  final Dio _enrollment;

  /// `ordering` accepts `start_date`/`event_type`/`school_year` (either
  /// direction, `-` prefix for desc); anything else is ignored server-side.
  Future<CalendarEventsPage> fetchEvents({
    String? schoolYear,
    String? eventType,
    String? search,
    String ordering = 'start_date',
    int page = 1,
    int pageSize = 200,
  }) async {
    final response = await _enrollment.get(
      '/api/calendar-events/',
      queryParameters: {
        if (schoolYear != null && schoolYear.isNotEmpty) 'school_year': schoolYear,
        if (eventType != null && eventType.isNotEmpty) 'event_type': eventType,
        if (search != null && search.isNotEmpty) 'search': search,
        'ordering': ordering,
        'page': page,
        'page_size': pageSize,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    final hasMore = data is Map<String, dynamic> && data['next'] != null;
    return CalendarEventsPage(
      events: (results ?? [])
          .cast<Map<String, dynamic>>()
          .map(CalendarEvent.fromJson)
          .toList(),
      hasMore: hasMore,
    );
  }
}
