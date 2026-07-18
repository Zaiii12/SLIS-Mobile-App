import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/data/advisory_api.dart';
import '../../advisory/models/section_advisory.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../../grades/data/grades_repository.dart';
import '../../grades/models/grading_template.dart' show schoolLevelToJson;
import '../../grades/models/subject.dart';
import '../data/teachers_repository.dart';
import '../models/teacher.dart';
import 'monitoring_sections_screen.dart';

enum _LoadStatus { loading, loaded, error }

/// "All" sentinel values for the School Level / Grade Level filter
/// dropdowns, distinct from any real `school_level`/`grade_level` string.
const _kAllSchoolLevels = 'all';
const _kAllGradeLevels = 'all';

/// Orders grade-level labels like "Grade 2"/"Grade 10" numerically by the
/// leading number (falls back to plain string comparison for non-numeric
/// labels like "Kindergarten"/"Nursery", which don't currently appear here
/// since [_subjects] only ever covers Elementary/JHS/SHS).
int _compareGradeLevels(String a, String b) {
  final numA = int.tryParse(RegExp(r'\d+').firstMatch(a)?.group(0) ?? '');
  final numB = int.tryParse(RegExp(r'\d+').firstMatch(b)?.group(0) ?? '');
  if (numA != null && numB != null) return numA.compareTo(numB);
  if (numA != null) return -1;
  if (numB != null) return 1;
  return a.compareTo(b);
}

/// Admin/super_admin-only tab (see [ShellTab.monitoring]): browse
/// teacher → section → attendance/grades, replacing the separate
/// Attendance/Grades tabs for these roles. `GET /api/auth/users/` (backing
/// [TeachersRepository]) is gated server-side to admin/super_admin only —
/// registrar is deliberately NOT in this tab's audience (see
/// `accounts/audit.py`'s `ADMIN_ROLES`), so registrar keeps the existing
/// Attendance/Grades tabs instead.
class MonitoringScreen extends StatefulWidget {
  const MonitoringScreen({
    super.key,
    required this.teachersRepository,
    required this.advisoryApi,
    required this.attendanceRepository,
    required this.gradesRepository,
  });

  final TeachersRepository teachersRepository;
  final AdvisoryApi advisoryApi;
  final AttendanceRepository attendanceRepository;
  final GradesRepository gradesRepository;

  @override
  State<MonitoringScreen> createState() => _MonitoringScreenState();
}

class _MonitoringScreenState extends State<MonitoringScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<Teacher> _teachers = const [];

  /// Every section school-wide (staff-mode `fetchSectionAdvisories()` with
  /// no `teacherUserId`), fetched once alongside the teacher list so each
  /// teacher can be matched against the levels/grades they actually teach.
  List<SectionAdvisory> _advisories = const [];

  /// The full curriculum, unfiltered by any teacher's assignments — drives
  /// the School Level / Grade Level filter *options*, so every grade the
  /// school teaches shows up even if no teacher currently has an advisory
  /// for it yet (selecting one just yields an empty teacher list, same as
  /// any other filter with no matches).
  List<Subject> _subjects = const [];

  final _searchController = TextEditingController();
  String _query = '';
  String _schoolLevel = _kAllSchoolLevels;
  String _gradeLevel = _kAllGradeLevels;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final results = await Future.wait([
        widget.teachersRepository.fetchTeachers(),
        widget.advisoryApi.fetchSectionAdvisories(),
        widget.gradesRepository.fetchAllSubjects(),
      ]);
      final teachers = results[0] as List<Teacher>;
      teachers.sort((a, b) => a.name.compareTo(b.name));
      if (!mounted) return;
      setState(() {
        _teachers = teachers;
        _advisories = results[1] as List<SectionAdvisory>;
        _subjects = results[2] as List<Subject>;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  /// Distinct school levels the curriculum actually covers (per [_subjects]),
  /// in enum order — independent of which levels currently have a teacher
  /// advisory, so e.g. Elementary still shows up even if no elementary
  /// teacher has been assigned an advisory yet.
  List<SchoolLevel> get _availableSchoolLevels {
    final present = _subjects.map((s) => s.schoolLevel).toSet();
    return SchoolLevel.values.where(present.contains).toList();
  }

  /// Distinct grade levels taught at [_schoolLevel] (or across every level
  /// if "All" is selected), sorted numerically (`Grade 2` before `Grade 10`)
  /// rather than lexicographically — plain string sort would otherwise
  /// order "Grade 10" ahead of "Grade 2".
  List<String> get _availableGradeLevels {
    final matching = _schoolLevel == _kAllSchoolLevels
        ? _subjects
        : _subjects.where((s) => schoolLevelToJson(s.schoolLevel) == _schoolLevel);
    final grades = matching.map((s) => s.gradeLevel).toSet().toList();
    grades.sort(_compareGradeLevels);
    return grades;
  }

  void _setSchoolLevel(String value) {
    setState(() {
      _schoolLevel = value;
      _gradeLevel = _kAllGradeLevels;
    });
  }

  void _setGradeLevel(String value) => setState(() => _gradeLevel = value);

  /// True if [teacher] has at least one section matching the current
  /// School Level / Grade Level filters (both "All" by default).
  bool _matchesLevelFilters(Teacher teacher) {
    if (_schoolLevel == _kAllSchoolLevels && _gradeLevel == _kAllGradeLevels) return true;
    return _advisories.any((a) {
      if (a.teacherUserId != teacher.userId) return false;
      if (_schoolLevel != _kAllSchoolLevels && schoolLevelToJson(a.schoolLevel) != _schoolLevel) return false;
      if (_gradeLevel != _kAllGradeLevels && a.gradeLevel != _gradeLevel) return false;
      return true;
    });
  }

  bool _matchesQuery(Teacher teacher) {
    if (_query.isEmpty) return true;
    return teacher.name.toLowerCase().contains(_query) || teacher.email.toLowerCase().contains(_query);
  }

  List<Teacher> get _filteredTeachers =>
      _teachers.where((t) => _matchesQuery(t) && _matchesLevelFilters(t)).toList();

  void _openTeacher(Teacher teacher) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonitoringSectionsScreen(
          teacher: teacher,
          advisoryApi: widget.advisoryApi,
          attendanceRepository: widget.attendanceRepository,
          gradesRepository: widget.gradesRepository,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Monitoring',
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          children: [
            _SearchField(controller: _searchController),
            const SizedBox(height: 8),
            if (_status == _LoadStatus.loaded) ...[
              Row(
                children: [
                  Expanded(
                    child: _FilterDropdown(
                      allLabel: 'All School Levels',
                      allValue: _kAllSchoolLevels,
                      value: _schoolLevel,
                      items: [
                        for (final level in _availableSchoolLevels)
                          (value: schoolLevelToJson(level), label: level.label),
                      ],
                      onChanged: _setSchoolLevel,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterDropdown(
                      allLabel: 'All Grade Levels',
                      allValue: _kAllGradeLevels,
                      value: _gradeLevel,
                      items: [
                        for (final grade in _availableGradeLevels) (value: grade, label: grade),
                      ],
                      onChanged: _setGradeLevel,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Text(
              'TEACHERS',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted2,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            _buildBody(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const LoadingSkeletonCard(height: 200);
      case _LoadStatus.error:
        return NetworkErrorState(onRetry: _load);
      case _LoadStatus.loaded:
        if (_teachers.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Center(
              child: Text(
                'No teacher accounts found',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
              ),
            ),
          );
        }
        final filtered = _filteredTeachers;
        if (filtered.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Center(
              child: Text(
                'No teachers match this filter',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < filtered.length; i++)
                _TeacherRow(
                  teacher: filtered[i],
                  showDivider: i != filtered.length - 1,
                  onTap: () => _openTeacher(filtered[i]),
                ),
            ],
          ),
        );
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Search teachers by name or email',
          hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted2),
          prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.textMuted2),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close, size: 16, color: AppColors.textMuted2),
                  onPressed: controller.clear,
                ),
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }
}

/// A dropdown filter over `(value, label)` pairs, with an implicit "All ..."
/// option (whichever sentinel [allValue] is) prepended so it's always
/// selectable regardless of what's currently loaded.
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

class _TeacherRow extends StatelessWidget {
  const _TeacherRow({required this.teacher, required this.showDivider, required this.onTap});

  final Teacher teacher;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: showDivider ? const Border(bottom: BorderSide(color: AppColors.rowDivider)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF3F2)),
              child: Center(
                child: Text(
                  teacher.name.isEmpty ? '?' : teacher.name[0].toUpperCase(),
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    teacher.name,
                    style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    teacher.email,
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}
