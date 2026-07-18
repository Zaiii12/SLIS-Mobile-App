/// Mirrors enrollment-service's `CalendarEventSerializer`
/// (`academic_calendar/serializers.py`). Events are date-only — no
/// start/end time fields exist server-side, so multi-day spans (e.g.
/// a quarter break) are represented purely via `startDate`/`endDate`.
class CalendarEvent {
  const CalendarEvent({
    required this.eventId,
    required this.schoolYear,
    required this.title,
    required this.eventType,
    required this.startDate,
    required this.endDate,
    required this.description,
  });

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      eventId: json['event_id'].toString(),
      schoolYear: json['school_year'] as String? ?? '',
      title: json['title'] as String? ?? '',
      eventType: json['event_type'] as String? ?? 'other',
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      description: json['description'] as String?,
    );
  }

  final String eventId;
  final String schoolYear;
  final String title;
  final String eventType;
  final DateTime startDate;
  final DateTime endDate;
  final String? description;

  bool get isMultiDay =>
      startDate.year != endDate.year ||
      startDate.month != endDate.month ||
      startDate.day != endDate.day;
}

/// Matches the backend's `EVENT_TYPES` choices
/// (`academic_calendar/models.py`) with the same display labels used by
/// the ASIA web admin-portal's `EVENT_TYPE_DEFAULTS`.
const calendarEventTypeLabels = {
  'holiday': 'Holiday',
  'exam': 'Exam / Assessment',
  'enrollment': 'Enrollment Period',
  'quarter_break': 'Quarter Break',
  'school_day_off': 'School Day Off',
  'event': 'Event',
  'other': 'Other',
};
