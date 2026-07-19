import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../settings/state/school_year_provider.dart';
import '../../shell/ui/widgets/school_year_picker_chip.dart';
import '../data/calendar_repository.dart';
import '../models/calendar_event.dart';
import 'calendar_pdf.dart';

const _eventTypeOptions = {
  '': 'All types',
  'holiday': 'Holiday',
  'exam': 'Exam / Assessment',
  'enrollment': 'Enrollment Period',
  'quarter_break': 'Quarter Break',
  'school_day_off': 'School Day Off',
  'event': 'Event',
  'other': 'Other',
};

const _eventTypeColors = {
  'holiday': Color(0xFFE03131),
  'exam': AppColors.infoBlueIcon,
  'enrollment': AppColors.successText2,
  'quarter_break': AppColors.infoPurpleIcon,
  'school_day_off': AppColors.warningText,
  'event': Color(0xFF0E9488),
  'other': AppColors.neutralPillText,
};

enum _LoadStatus { loading, loaded, error }

/// Read-only school calendar, backed by enrollment-service's
/// `GET /api/calendar-events/` (`CalendarEventViewSet`,
/// `academic_calendar/views.py`) — readable by every authenticated
/// non-guardian staff role (`IsAdminRegistrarOrReadOnly`). Shown to every
/// role in this app; there is no create/edit/delete UI yet since only
/// admin/registrar can write server-side and event management currently
/// happens on the ASIA web admin-portal.
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, required this.repository});

  final CalendarRepository repository;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _searchController = TextEditingController();

  String _eventType = '';
  String _search = '';
  _LoadStatus _loadStatus = _LoadStatus.loading;
  List<CalendarEvent> _events = const [];
  bool _refreshing = false;
  String? _fetchedForYear;

  @override
  void initState() {
    super.initState();
    _fetchedForYear = context.read<SchoolYearProvider>().schoolYear;
    _load();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool isRefresh = false}) async {
    setState(() {
      if (isRefresh) {
        _refreshing = true;
      } else {
        _loadStatus = _LoadStatus.loading;
      }
    });
    try {
      final result = await widget.repository.fetchEvents(
        schoolYear: context.read<SchoolYearProvider>().schoolYear,
        eventType: _eventType.isEmpty ? null : _eventType,
        ordering: 'start_date',
      );
      if (!mounted) return;
      setState(() {
        _events = result.events;
        _loadStatus = _LoadStatus.loaded;
        _refreshing = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('CalendarRepository.fetchEvents failed: $error\n$stackTrace');
      setState(() {
        _loadStatus = _LoadStatus.error;
        _refreshing = false;
      });
    }
  }

  List<CalendarEvent> get _filtered {
    if (_search.isEmpty) return _events;
    return _events.where((e) {
      return e.title.toLowerCase().contains(_search) ||
          (e.description?.toLowerCase().contains(_search) ?? false);
    }).toList();
  }

  List<CalendarEvent> get _upcomingAndPast {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final sorted = [..._filtered]..sort((a, b) => a.startDate.compareTo(b.startDate));
    return sorted.where((e) => !e.endDate.isBefore(todayStart)).toList() +
        sorted.where((e) => e.endDate.isBefore(todayStart)).toList().reversed.toList();
  }

  Map<String, List<CalendarEvent>> get _groupedByMonth {
    final groups = <String, List<CalendarEvent>>{};
    for (final event in _upcomingAndPast) {
      final key = DateFormat('MMMM yyyy').format(event.startDate);
      groups.putIfAbsent(key, () => []).add(event);
    }
    return groups;
  }

  Future<void> _openExportSheet() async {
    final months = <DateTime>{};
    for (final event in _events) {
      months.add(DateTime(event.startDate.year, event.startDate.month));
    }
    final sortedMonths = months.toList()..sort();
    final years = sortedMonths.map((m) => m.year).toSet().toList()..sort();

    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(sheetContext).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Export / Print',
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted3),
                      onPressed: () => Navigator.of(sheetContext).pop(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (years.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'BY YEAR',
                              style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.labelUppercase2),
                            ),
                          ),
                        ),
                      for (final year in years)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.calendar_today_outlined, size: 17, color: AppColors.primary),
                          title: Text('$year', style: GoogleFonts.dmSans(fontSize: 13)),
                          onTap: () {
                            Navigator.of(sheetContext).pop();
                            _exportYear(year);
                          },
                        ),
                      if (sortedMonths.isNotEmpty) ...[
                        const Divider(height: 1, color: AppColors.rowDivider),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'BY MONTH',
                              style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.labelUppercase2),
                            ),
                          ),
                        ),
                        for (final month in sortedMonths)
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.calendar_month_outlined, size: 17, color: AppColors.primary),
                            title: Text(DateFormat('MMMM yyyy').format(month), style: GoogleFonts.dmSans(fontSize: 13)),
                            onTap: () {
                              Navigator.of(sheetContext).pop();
                              _exportMonth(month);
                            },
                          ),
                      ],
                      if (years.isEmpty && sortedMonths.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                          child: Text(
                            'No events loaded to export yet.',
                            style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.textMuted3),
                          ),
                        ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportMonth(DateTime month) async {
    final events = _events
        .where((e) => e.startDate.year == month.year && e.startDate.month == month.month)
        .toList();
    await printCalendarEvents(
      periodLabel: DateFormat('MMMM yyyy').format(month),
      events: events,
    );
  }

  Future<void> _exportYear(int year) async {
    final events = _events.where((e) => e.startDate.year == year).toList();
    await printCalendarEvents(periodLabel: '$year', events: events);
  }

  @override
  Widget build(BuildContext context) {
    final schoolYear = context.watch<SchoolYearProvider>().schoolYear;
    if (schoolYear != _fetchedForYear) {
      _fetchedForYear = schoolYear;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'School Calendar',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
        actions: [
          const Center(child: SchoolYearPickerChip()),
          IconButton(
            icon: const Icon(Icons.print_outlined, size: 20, color: AppColors.textMuted3),
            onPressed: _loadStatus == _LoadStatus.loaded ? _openExportSheet : null,
            tooltip: 'Export / Print',
          ),
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh, size: 20, color: AppColors.textMuted3),
            onPressed: _refreshing ? null : () => _load(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            searchController: _searchController,
            eventType: _eventType,
            onEventTypeChanged: (v) {
              setState(() => _eventType = v);
              _load();
            },
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_loadStatus) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return _ErrorState(onRetry: () => _load());
      case _LoadStatus.loaded:
        final grouped = _groupedByMonth;
        if (grouped.isEmpty) {
          return _EmptyState(hasFilters: _eventType.isNotEmpty || _search.isNotEmpty);
        }
        return RefreshIndicator(
          onRefresh: () => _load(isRefresh: true),
          child: ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              for (final entry in grouped.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    entry.key,
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.labelUppercase1,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.cardWhite,
                    borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (var i = 0; i < entry.value.length; i++) ...[
                        _CalendarEventRow(event: entry.value[i]),
                        if (i != entry.value.length - 1)
                          const Divider(height: 1, color: AppColors.rowDivider),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.searchController,
    required this.eventType,
    required this.onEventTypeChanged,
  });

  final TextEditingController searchController;
  final String eventType;
  final ValueChanged<String> onEventTypeChanged;

  Future<void> _showTypePicker(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Event type',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingDark),
              ),
            ),
            for (final entry in _eventTypeOptions.entries)
              ListTile(
                dense: true,
                leading: entry.key.isEmpty
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: _eventTypeColors[entry.key]),
                      ),
                title: Text(entry.value, style: GoogleFonts.dmSans(fontSize: 13)),
                trailing: entry.key == eventType ? const Icon(Icons.check, size: 18, color: AppColors.primary) : null,
                onTap: () => Navigator.of(sheetContext).pop(entry.key),
              ),
          ],
        ),
      ),
    );
    if (picked != null) onEventTypeChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            style: GoogleFonts.dmSans(fontSize: 12.5, color: const Color(0xFF2D1A1A)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search events',
              hintStyle: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.iconMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.iconMuted),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close, size: 16, color: AppColors.iconMuted),
                      onPressed: searchController.clear,
                    ),
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: () => _showTypePicker(context),
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: eventType.isEmpty ? AppColors.neutralPillBg : AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: eventType.isEmpty ? Border.all(color: AppColors.cardBorder) : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (eventType.isNotEmpty) ...[
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    _eventTypeOptions[eventType] ?? eventType,
                    style: GoogleFonts.dmSans(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: eventType.isEmpty ? AppColors.textMuted1 : Colors.white,
                    ),
                  ),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: eventType.isEmpty ? AppColors.textMuted1 : Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEventRow extends StatelessWidget {
  const _CalendarEventRow({required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    final color = _eventTypeColors[event.eventType] ?? AppColors.neutralPillText;
    final dateLabel = event.isMultiDay
        ? '${DateFormat('MMM d').format(event.startDate)} – ${DateFormat('MMM d').format(event.endDate)}'
        : DateFormat('EEEE, MMM d').format(event.startDate);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted2),
                ),
                if (event.description != null && event.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.description!,
                    style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TypePill(label: calendarEventTypeLabels[event.eventType] ?? event.eventType, color: color),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilters ? Icons.filter_alt_off_outlined : Icons.calendar_month_outlined,
              size: 28,
              color: const Color(0xFFD8B8B4),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters ? 'No matching events' : 'No calendar events yet',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
            ),
            const SizedBox(height: 2),
            Text(
              hasFilters ? 'Try a different search or type' : 'Events will appear here once added',
              style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              "Couldn't load the calendar",
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
