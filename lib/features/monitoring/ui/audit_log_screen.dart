import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../data/audit_log_repository.dart';
import '../models/audit_log_entry.dart';

const _roleOptions = {
  'all': 'All roles',
  'super_admin': 'Super Admin',
  'admin': 'Admin',
  'registrar': 'Registrar',
  'teacher': 'Teacher',
  'accounting': 'Accounting',
  'guardian': 'Guardian',
};

const _statusOptions = {
  '': 'All statuses',
  'success': 'Success',
  'failed': 'Failure',
};

const _orderingOptions = {
  '-occurred_at': 'Newest first',
  'occurred_at': 'Oldest first',
  'user_role': 'Role (A-Z)',
  '-user_role': 'Role (Z-A)',
  'module': 'Module (A-Z)',
  '-module': 'Module (Z-A)',
  'status': 'Status (A-Z)',
  '-status': 'Status (Z-A)',
};

enum _LoadStatus { loading, loaded, error }

/// Admin/super_admin-only filterable audit log viewer, backed by
/// identity-service's `GET /api/audit-logs/` (`AuditLogListView`,
/// `accounts/views.py:363`) — already gated server-side to `ADMIN_ROLES`.
/// Every filter here (role/module/status/date/time_from/time_to/ordering)
/// is sent server-side; there is no client-only filtering fallback since the
/// log is potentially large and paginated at 20/page.
class AuditLogScreen extends StatefulWidget {
  const AuditLogScreen({super.key, required this.repository});

  final AuditLogRepository repository;

  @override
  State<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends State<AuditLogScreen> {
  final _moduleController = TextEditingController();
  final _scrollController = ScrollController();

  String _role = 'all';
  String _status = '';
  DateTime? _date;
  TimeOfDay? _timeFrom;
  TimeOfDay? _timeTo;
  String _ordering = '-occurred_at';

  _LoadStatus _loadStatus = _LoadStatus.loading;
  List<AuditLogEntry> _entries = const [];
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _moduleController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadStatus != _LoadStatus.loaded || !_hasMore || _loadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  String? _formatTimeOfDay(TimeOfDay? time) {
    if (time == null) return null;
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
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
      final result = await widget.repository.fetchAuditLogs(
        role: _role == 'all' ? null : _role,
        module: _moduleController.text.trim(),
        status: _status,
        date: _date,
        timeFrom: _formatTimeOfDay(_timeFrom),
        timeTo: _formatTimeOfDay(_timeTo),
        ordering: _ordering,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _entries = result.entries;
        _page = 1;
        _hasMore = result.hasMore;
        _loadStatus = _LoadStatus.loaded;
        _refreshing = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('AuditLogRepository.fetchAuditLogs failed: $error\n$stackTrace');
      setState(() {
        _loadStatus = _LoadStatus.error;
        _refreshing = false;
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await widget.repository.fetchAuditLogs(
        role: _role == 'all' ? null : _role,
        module: _moduleController.text.trim(),
        status: _status,
        date: _date,
        timeFrom: _formatTimeOfDay(_timeFrom),
        timeTo: _formatTimeOfDay(_timeTo),
        ordering: _ordering,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _entries = [..._entries, ...result.entries];
        _page = nextPage;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await _showDatePickerSheet(context, initialDate: _date);
    if (picked == null) return;
    setState(() => _date = picked);
    _load();
  }

  Future<void> _pickTime({required bool isFrom}) async {
    final picked = await _showTimePickerSheet(
      context,
      title: isFrom ? 'From time' : 'To time',
      initialTime: (isFrom ? _timeFrom : _timeTo) ?? TimeOfDay.now(),
    );
    if (picked == null) return;
    setState(() {
      if (isFrom) {
        _timeFrom = picked;
      } else {
        _timeTo = picked;
      }
    });
    _load();
  }

  void _clearFilters() {
    setState(() {
      _role = 'all';
      _status = '';
      _date = null;
      _timeFrom = null;
      _timeTo = null;
      _ordering = '-occurred_at';
      _moduleController.clear();
    });
    _load();
  }

  bool get _hasActiveFilters =>
      _role != 'all' ||
      _status.isNotEmpty ||
      _date != null ||
      _timeFrom != null ||
      _timeTo != null ||
      _moduleController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Audit Monitoring',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
        actions: [
          IconButton(
            icon: _refreshing
                ? const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(
                    Icons.refresh,
                    size: 20,
                    color: AppColors.textMuted3,
                  ),
            onPressed: _refreshing ? null : () => _load(isRefresh: true),
          ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(
            role: _role,
            onRoleChanged: (v) {
              setState(() => _role = v);
              _load();
            },
            status: _status,
            onStatusChanged: (v) {
              setState(() => _status = v);
              _load();
            },
            moduleController: _moduleController,
            onModuleSubmitted: (_) => _load(),
            date: _date,
            onPickDate: _pickDate,
            onClearDate: () {
              setState(() => _date = null);
              _load();
            },
            timeFrom: _timeFrom,
            timeTo: _timeTo,
            onPickTimeFrom: () => _pickTime(isFrom: true),
            onPickTimeTo: () => _pickTime(isFrom: false),
            onClearTimeFrom: () {
              setState(() => _timeFrom = null);
              _load();
            },
            onClearTimeTo: () {
              setState(() => _timeTo = null);
              _load();
            },
            ordering: _ordering,
            onOrderingChanged: (v) {
              setState(() => _ordering = v);
              _load();
            },
            hasActiveFilters: _hasActiveFilters,
            onClearFilters: _clearFilters,
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.cardWhite,
            child: Text(
              '${_entries.length} entries loaded',
              style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted2),
            ),
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
        if (_entries.isEmpty) {
          return _EmptyState(hasFilters: _hasActiveFilters);
        }
        return RefreshIndicator(
          onRefresh: () => _load(isRefresh: true),
          child: ListView.separated(
            controller: _scrollController,
            padding: EdgeInsets.zero,
            itemCount: _entries.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.rowDivider),
            itemBuilder: (context, index) {
              if (index >= _entries.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              return _AuditLogRow(entry: _entries[index]);
            },
          ),
        );
    }
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.role,
    required this.onRoleChanged,
    required this.status,
    required this.onStatusChanged,
    required this.moduleController,
    required this.onModuleSubmitted,
    required this.date,
    required this.onPickDate,
    required this.onClearDate,
    required this.timeFrom,
    required this.timeTo,
    required this.onPickTimeFrom,
    required this.onPickTimeTo,
    required this.onClearTimeFrom,
    required this.onClearTimeTo,
    required this.ordering,
    required this.onOrderingChanged,
    required this.hasActiveFilters,
    required this.onClearFilters,
  });

  final String role;
  final ValueChanged<String> onRoleChanged;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final TextEditingController moduleController;
  final ValueChanged<String> onModuleSubmitted;
  final DateTime? date;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;
  final TimeOfDay? timeFrom;
  final TimeOfDay? timeTo;
  final VoidCallback onPickTimeFrom;
  final VoidCallback onPickTimeTo;
  final VoidCallback onClearTimeFrom;
  final VoidCallback onClearTimeTo;
  final String ordering;
  final ValueChanged<String> onOrderingChanged;
  final bool hasActiveFilters;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.cardWhite,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: moduleController,
                  onSubmitted: onModuleSubmitted,
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: const Color(0xFF2D1A1A)),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Filter by module',
                    hintStyle: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.iconMuted),
                    prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.iconMuted),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              if (hasActiveFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onClearFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: Size.zero,
                  ),
                  child: Text(
                    'Clear',
                    style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _DropdownChip(
                  label: _roleOptions[role] ?? role,
                  active: role != 'all',
                  onTap: () async {
                    final picked = await _showOptionPicker(context, 'Role', _roleOptions, role);
                    if (picked != null) onRoleChanged(picked);
                  },
                ),
                const SizedBox(width: 8),
                _DropdownChip(
                  label: status.isEmpty ? _statusOptions['']! : _statusOptions[status] ?? status,
                  active: status.isNotEmpty,
                  onTap: () async {
                    final picked = await _showOptionPicker(context, 'Status', _statusOptions, status);
                    if (picked != null) onStatusChanged(picked);
                  },
                ),
                const SizedBox(width: 8),
                _DropdownChip(
                  label: date == null ? 'Date' : DateFormat('MMM d, yyyy').format(date!),
                  active: date != null,
                  onTap: onPickDate,
                  onClear: date != null ? onClearDate : null,
                ),
                const SizedBox(width: 8),
                _DropdownChip(
                  label: timeFrom == null ? 'From' : timeFrom!.format(context),
                  active: timeFrom != null,
                  onTap: onPickTimeFrom,
                  onClear: timeFrom != null ? onClearTimeFrom : null,
                ),
                const SizedBox(width: 8),
                _DropdownChip(
                  label: timeTo == null ? 'To' : timeTo!.format(context),
                  active: timeTo != null,
                  onTap: onPickTimeTo,
                  onClear: timeTo != null ? onClearTimeTo : null,
                ),
                const SizedBox(width: 8),
                _DropdownChip(
                  label: _orderingOptions[ordering] ?? 'Sort',
                  active: ordering != '-occurred_at',
                  icon: Icons.swap_vert,
                  onTap: () async {
                    final picked = await _showOptionPicker(context, 'Sort by', _orderingOptions, ordering);
                    if (picked != null) onOrderingChanged(picked);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<String?> _showOptionPicker(
    BuildContext context,
    String title,
    Map<String, String> options,
    String current,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                title,
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingDark),
              ),
            ),
            for (final entry in options.entries)
              ListTile(
                dense: true,
                title: Text(entry.value, style: GoogleFonts.dmSans(fontSize: 13)),
                trailing: entry.key == current
                    ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(context).pop(entry.key),
              ),
          ],
        ),
      ),
    );
  }
}

/// White bottom-sheet calendar picker, replacing Flutter's native
/// `showDatePicker` — Material 3's default dialog tints its header/selected
/// day using `ColorScheme.fromSeed(seedColor: AppColors.primary)`
/// (`AppTheme.light`), which reads as a washed-out red background. Wrapping
/// `CalendarDatePicker` in the same white `showModalBottomSheet` shell used
/// for Role/Status/Sort keeps every filter control visually consistent.
Future<DateTime?> _showDatePickerSheet(
  BuildContext context, {
  DateTime? initialDate,
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.cardWhite,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select date',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted3),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: AppColors.cardWhite,
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: AppColors.headingDark,
              ),
            ),
            child: CalendarDatePicker(
              initialDate: initialDate ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              onDateChanged: (picked) => Navigator.of(context).pop(picked),
            ),
          ),
        ],
      ),
    ),
  );
}

final _hours = List<int>.generate(24, (h) => h);
const _minutes = [0, 15, 30, 45];

/// White bottom-sheet hour/minute picker, replacing Flutter's native
/// `showTimePicker` for the same reason as [_showDatePickerSheet] — the
/// default clock dialog tints itself with the app's red seed color.
Future<TimeOfDay?> _showTimePickerSheet(
  BuildContext context, {
  required String title,
  required TimeOfDay initialTime,
}) {
  var hour = initialTime.hour;
  var minute = _minutes.reduce(
    (a, b) => (initialTime.minute - a).abs() < (initialTime.minute - b).abs() ? a : b,
  );

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    backgroundColor: AppColors.cardWhite,
    builder: (context) => SafeArea(
      child: StatefulBuilder(
        builder: (context, setSheetState) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted3),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              SizedBox(
                height: 180,
                child: Row(
                  children: [
                    Expanded(
                      child: ListWheelScrollView(
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        controller: FixedExtentScrollController(initialItem: hour),
                        onSelectedItemChanged: (i) => setSheetState(() => hour = i),
                        children: [
                          for (final h in _hours)
                            Center(
                              child: Text(
                                h.toString().padLeft(2, '0'),
                                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Text(':', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.headingDark)),
                    Expanded(
                      child: ListWheelScrollView(
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        physics: const FixedExtentScrollPhysics(),
                        controller: FixedExtentScrollController(initialItem: _minutes.indexOf(minute)),
                        onSelectedItemChanged: (i) => setSheetState(() => minute = _minutes[i]),
                        children: [
                          for (final m in _minutes)
                            Center(
                              child: Text(
                                m.toString().padLeft(2, '0'),
                                style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(TimeOfDay(hour: hour, minute: minute)),
                    child: const Text('Set time'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _DropdownChip extends StatelessWidget {
  const _DropdownChip({
    required this.label,
    required this.active,
    required this.onTap,
    this.icon = Icons.arrow_drop_down,
    this.onClear,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final IconData icon;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.neutralPillBg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: active ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : AppColors.textMuted1,
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(Icons.close, size: 13, color: active ? Colors.white : AppColors.textMuted1),
              ),
            ] else ...[
              Icon(icon, size: 15, color: active ? Colors.white : AppColors.textMuted1),
            ],
          ],
        ),
      ),
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final occurred = DateTime.tryParse(entry.occurredAt);
    final isSuccess = entry.status == 'success';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSuccess ? AppColors.successFill : AppColors.dangerText,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.action,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                ),
                const SizedBox(height: 2),
                if (entry.details.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      entry.details,
                      style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted2),
                    ),
                  ),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _MetaPill(text: entry.userName),
                    _MetaPill(text: entry.userRole),
                    _MetaPill(text: entry.module),
                    if (entry.ipAddress != null && entry.ipAddress!.isNotEmpty)
                      _MetaPill(text: entry.ipAddress!),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                occurred != null ? DateFormat('MMM d, h:mm a').format(occurred) : '—',
                style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
              ),
              const SizedBox(height: 4),
              Text(
                entry.status,
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: isSuccess ? AppColors.successText : AppColors.dangerText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.neutralPillBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: GoogleFonts.dmSans(fontSize: 10, color: AppColors.neutralPillText),
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
              hasFilters ? Icons.filter_alt_off_outlined : Icons.history,
              size: 28,
              color: const Color(0xFFD8B8B4),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilters ? 'No matching audit entries' : 'No audit entries yet',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
            ),
            const SizedBox(height: 2),
            Text(
              hasFilters ? 'Try different filters' : 'Activity will appear here as it happens',
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
              "Couldn't load audit logs",
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
