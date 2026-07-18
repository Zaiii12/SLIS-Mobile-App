import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../billing/data/enrollment_repository.dart';
import '../models/grade_overview_row.dart';
import '../models/grading_template.dart' show schoolLevelToJson;
import 'grade_colors.dart';
import 'grade_summary_screen.dart';

enum _LoadStatus { loading, loaded, error }

const _kAllSchoolLevels = 'all';
const _kAllGradeLevels = 'all';

const _gradeLevelsByLevel = {
  SchoolLevel.nursery: ['Nursery'],
  SchoolLevel.kindergarten: ['Kindergarten'],
  SchoolLevel.elementary: ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
  SchoolLevel.juniorHighschool: ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'],
  SchoolLevel.seniorHighschool: ['Grade 11', 'Grade 12'],
};

/// Registrar-facing read-only Grade Overview tab: cascading School Level →
/// Grade Level filter + search over enrolled students, each row showing a
/// computed average/passed/failed across every subject and grading period
/// recorded so far. Mirrors ASIA web's `GradesPage.jsx` `OverviewTab`.
/// Tapping a row opens [GradeSummaryScreen] for the per-subject breakdown —
/// there is no "Entry"/edit affordance anywhere in this flow, since
/// registrar has read-only access to grades (`IsAdvisoryTeacherOrStaff`'s
/// `GRADE_READ_ROLES` includes registrar for GET only).
class GradeOverviewScreen extends StatefulWidget {
  const GradeOverviewScreen({super.key, required this.repository});

  final EnrollmentRepository repository;

  @override
  State<GradeOverviewScreen> createState() => _GradeOverviewScreenState();
}

class _GradeOverviewScreenState extends State<GradeOverviewScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  String _schoolLevel = _kAllSchoolLevels;
  String _gradeLevel = _kAllGradeLevels;
  _LoadStatus _status = _LoadStatus.loading;
  List<GradeOverviewRow> _rows = const [];

  /// Grade levels within [_schoolLevel], or every grade level across all
  /// school levels (in level order) when "All School Levels" is selected —
  /// matches `monitoring_screen.dart`'s `_availableGradeLevels` behavior.
  List<String> get _availableGradeLevels {
    if (_schoolLevel == _kAllSchoolLevels) {
      return [for (final level in SchoolLevel.values) ...?_gradeLevelsByLevel[level]];
    }
    final level = SchoolLevel.values.firstWhere((l) => schoolLevelToJson(l) == _schoolLevel);
    return _gradeLevelsByLevel[level] ?? const [];
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final rows = await widget.repository.fetchGradeOverviewRoster(
        schoolLevel: _schoolLevel == _kAllSchoolLevels ? null : _schoolLevel,
        gradeLevel: _gradeLevel == _kAllGradeLevels ? null : _gradeLevel,
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _rows = rows;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  void _setSchoolLevel(String value) {
    setState(() {
      _schoolLevel = value;
      _gradeLevel = _kAllGradeLevels;
    });
    _load();
  }

  void _setGradeLevel(String value) {
    setState(() => _gradeLevel = value);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              controller: _searchController,
              onChanged: _onSearchChanged,
              schoolLevel: _schoolLevel,
              gradeLevel: _gradeLevel,
              availableGradeLevels: _availableGradeLevels,
              onSchoolLevelChanged: _setSchoolLevel,
              onGradeLevelChanged: _setGradeLevel,
            ),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return _ErrorState(onRetry: _load);
      case _LoadStatus.loaded:
        if (_rows.isEmpty) return const _EmptyState();
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.rowDivider),
          itemBuilder: (context, index) => _OverviewRow(
            row: _rows[index],
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => GradeSummaryScreen(row: _rows[index])),
            ),
          ),
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onChanged,
    required this.schoolLevel,
    required this.gradeLevel,
    required this.availableGradeLevels,
    required this.onSchoolLevelChanged,
    required this.onGradeLevelChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String schoolLevel;
  final String gradeLevel;
  final List<String> availableGradeLevels;
  final ValueChanged<String> onSchoolLevelChanged;
  final ValueChanged<String> onGradeLevelChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      decoration: const BoxDecoration(
        color: AppColors.cardWhite,
        border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Grade Overview',
            style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingDark),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF2D1A1A)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search student name or LRN',
              hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.iconMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.iconMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown(
                  allLabel: 'All School Levels',
                  allValue: _kAllSchoolLevels,
                  value: schoolLevel,
                  items: [
                    for (final level in SchoolLevel.values)
                      (value: schoolLevelToJson(level), label: level.label),
                  ],
                  onChanged: onSchoolLevelChanged,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown(
                  allLabel: 'All Grade Levels',
                  allValue: _kAllGradeLevels,
                  value: gradeLevel,
                  items: [
                    for (final grade in availableGradeLevels) (value: grade, label: grade),
                  ],
                  onChanged: onGradeLevelChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A dropdown filter over `(value, label)` pairs, with an implicit "All ..."
/// option (whichever sentinel [allValue] is) prepended so it's always
/// selectable regardless of what's currently loaded. Copied from
/// `monitoring_screen.dart`'s `_FilterDropdown` — same widget, same
/// behavior, kept local since it's private there.
class _FilterDropdown extends StatelessWidget {
  const _FilterDropdown({
    required this.allLabel,
    required this.allValue,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String allLabel;
  final String allValue;
  final String value;
  final List<({String value, String label})> items;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted2),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
          items: [
            DropdownMenuItem(value: allValue, child: Text(allLabel, overflow: TextOverflow.ellipsis)),
            for (final item in items)
              DropdownMenuItem(value: item.value, child: Text(item.label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.row, required this.onTap});

  final GradeOverviewRow row;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF3F2)),
              child: Center(
                child: Text(
                  row.initials,
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.studentName,
                    style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${row.gradeLevel} - ${row.section} · ${row.passed}P/${row.failed}F of ${row.total}',
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: gradeBackground(row.average),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                row.average?.toStringAsFixed(2) ?? 'No grades',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: gradeForeground(row.average),
                ),
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              'No students found',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
            ),
            const SizedBox(height: 2),
            Text(
              'Try a different name, LRN, or filter',
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
              "Couldn't load grades",
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
