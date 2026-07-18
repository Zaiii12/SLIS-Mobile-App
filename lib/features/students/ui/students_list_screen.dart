import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../billing/data/enrollment_repository.dart';
import '../../grades/models/grading_template.dart' show schoolLevelToJson;
import '../data/students_repository.dart';
import '../models/student.dart';
import 'student_detail_screen.dart';
import 'student_status_pill.dart';

// Level-based filter chips (Elementary/JHS/SHS) from the design mock were
// dropped originally — the real /api/students/ response has no level field
// (it lives on the enrollment record in enrollment-service, not the student
// record). School Level/Grade Level below restore that filter by resolving
// matching student ids from enrollment-service first (same
// `fetchEnrollments(schoolLevel:, gradeLevel:)` call the registrar's
// Enrollments tab uses), then intersecting with the student-service page —
// see `_load`'s doc comment for why this can't be a single server-side call.
// Status/sex/ordering are real, confirmed filters on `/api/students/` itself
// (StudentViewSet in student-service's students/views.py), matching ASIA
// web's Students page.

const _kAllSchoolLevels = 'all';
const _kAllGradeLevels = 'all';

const _gradeLevelsByLevel = {
  SchoolLevel.nursery: ['Nursery'],
  SchoolLevel.kindergarten: ['Kindergarten'],
  SchoolLevel.elementary: ['Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'],
  SchoolLevel.juniorHighschool: ['Grade 7', 'Grade 8', 'Grade 9', 'Grade 10'],
  SchoolLevel.seniorHighschool: ['Grade 11', 'Grade 12'],
};

enum _SexFilter { all, male, female }

extension on _SexFilter {
  String get label {
    switch (this) {
      case _SexFilter.all:
        return 'All sexes';
      case _SexFilter.male:
        return 'Male';
      case _SexFilter.female:
        return 'Female';
    }
  }

  String? get apiValue {
    switch (this) {
      case _SexFilter.male:
        return 'male';
      case _SexFilter.female:
        return 'female';
      case _SexFilter.all:
        return null;
    }
  }
}

enum _SortOption { newest, oldest, nameAZ, nameZA, youngestFirst, youngestLast }

extension on _SortOption {
  String get label {
    switch (this) {
      case _SortOption.newest:
        return 'Newest first';
      case _SortOption.oldest:
        return 'Oldest first';
      case _SortOption.nameAZ:
        return 'Name A → Z';
      case _SortOption.nameZA:
        return 'Name Z → A';
      case _SortOption.youngestFirst:
        return 'Youngest first';
      case _SortOption.youngestLast:
        return 'Youngest last';
    }
  }

  /// `ordering_fields` confirmed in `StudentViewSet`: student_id,
  /// student_number, last_name, birth_date, status.
  String get apiValue {
    switch (this) {
      case _SortOption.newest:
        return '-student_id';
      case _SortOption.oldest:
        return 'student_id';
      case _SortOption.nameAZ:
        return 'last_name';
      case _SortOption.nameZA:
        return '-last_name';
      case _SortOption.youngestFirst:
        return '-birth_date';
      case _SortOption.youngestLast:
        return 'birth_date';
    }
  }
}

enum _LoadStatus { loading, loaded, error }

/// Students tab: search + Status/Sex/Sort/School Level/Grade Level filter
/// dropdowns + list. Teacher role is read-only (no write actions exist in
/// this UI regardless of role — the RBAC handoff documents no student write
/// endpoints yet).
class StudentsListScreen extends StatefulWidget {
  const StudentsListScreen({
    super.key,
    required this.repository,
    required this.enrollmentRepository,
  });

  final StudentsRepository repository;
  final EnrollmentRepository enrollmentRepository;

  @override
  State<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends State<StudentsListScreen> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  StudentStatus? _statusFilter;
  _SexFilter _sexFilter = _SexFilter.all;
  _SortOption _sort = _SortOption.newest;
  String _schoolLevel = _kAllSchoolLevels;
  String _gradeLevel = _kAllGradeLevels;
  _LoadStatus _status = _LoadStatus.loading;
  List<Student> _students = const [];
  Timer? _debounce;

  // Student-service paginates at 20/page (see StudentsApi) — without this,
  // only the first page would ever be shown with no way to reach the rest.
  // Once a school/grade level filter is active, pagination is approximate:
  // each page is fetched normally, then filtered down to the enrollment-
  // matched id set, so a "page" can render fewer than 20 rows. Acceptable
  // at the current data scale (matches the tradeoff `EnrollmentsListScreen`
  // already makes by fetching everything unpaginated when filtered).
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  List<String> get _availableGradeLevels {
    if (_schoolLevel == _kAllSchoolLevels) {
      return [for (final level in SchoolLevel.values) ...?_gradeLevelsByLevel[level]];
    }
    final level = SchoolLevel.values.firstWhere((l) => schoolLevelToJson(l) == _schoolLevel);
    return _gradeLevelsByLevel[level] ?? const [];
  }

  bool get _levelFilterActive => _schoolLevel != _kAllSchoolLevels || _gradeLevel != _kAllGradeLevels;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_status != _LoadStatus.loaded || !_hasMore || _loadingMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  /// Resolves the set of student ids enrolled at the selected school/grade
  /// level, via `EnrollmentApi.fetchEnrollments` (`page_size: 500` under the
  /// hood — the same unpaginated-fetch tradeoff the registrar's Enrollments
  /// tab already makes). Returns null when no level filter is active, so
  /// callers can skip the intersection entirely.
  Future<Set<String>?> _resolveLevelFilteredStudentIds() async {
    if (!_levelFilterActive) return null;
    final enrollments = await widget.enrollmentRepository.fetchEnrollments(
      schoolLevel: _schoolLevel == _kAllSchoolLevels ? null : _schoolLevel,
      gradeLevel: _gradeLevel == _kAllGradeLevels ? null : _gradeLevel,
    );
    return enrollments.map((e) => e.studentId).toSet();
  }

  /// Fetches student-service pages one at a time, filtering each down to
  /// [allowedIds] (when a level filter is active), until at least one
  /// matching page has been gathered or pages run out. A plain
  /// student-service page can come back with zero rows in the allowed set
  /// (e.g. a page of Grade 3 pupils when filtering for Grade 7), so a single
  /// fetch isn't enough — this keeps requesting subsequent pages until it
  /// finds matches or exhausts `hasMore`.
  Future<({List<Student> students, int lastPage, bool hasMore})> _fetchFilteredPage(
    int startPage,
    Set<String>? allowedIds,
  ) async {
    var page = startPage;
    while (true) {
      final result = await widget.repository.fetchStudents(
        search: _searchController.text.trim(),
        status: _statusFilter?.apiValue,
        sex: _sexFilter.apiValue,
        ordering: _sort.apiValue,
        page: page,
      );
      final filtered = allowedIds == null
          ? result.students
          : result.students.where((s) => allowedIds.contains(s.id)).toList();
      if (filtered.isNotEmpty || !result.hasMore) {
        return (students: filtered, lastPage: page, hasMore: result.hasMore);
      }
      page++;
    }
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final allowedIds = await _resolveLevelFilteredStudentIds();
      final result = await _fetchFilteredPage(1, allowedIds);
      if (!mounted) return;
      setState(() {
        _students = result.students;
        _page = result.lastPage;
        _hasMore = result.hasMore;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final allowedIds = await _resolveLevelFilteredStudentIds();
      final result = await _fetchFilteredPage(_page + 1, allowedIds);
      if (!mounted) return;
      setState(() {
        _students = [..._students, ...result.students];
        _page = result.lastPage;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _load);
  }

  void _onStatusSelected(StudentStatus? status) {
    setState(() => _statusFilter = status);
    _load();
  }

  void _onSexSelected(_SexFilter sex) {
    setState(() => _sexFilter = sex);
    _load();
  }

  void _onSortSelected(_SortOption sort) {
    setState(() => _sort = sort);
    _load();
  }

  void _onSchoolLevelSelected(String value) {
    setState(() {
      _schoolLevel = value;
      _gradeLevel = _kAllGradeLevels;
    });
    _load();
  }

  void _onGradeLevelSelected(String value) {
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
              statusFilter: _statusFilter,
              onStatusSelected: _onStatusSelected,
              sexFilter: _sexFilter,
              onSexSelected: _onSexSelected,
              schoolLevel: _schoolLevel,
              gradeLevel: _gradeLevel,
              availableGradeLevels: _availableGradeLevels,
              onSchoolLevelSelected: _onSchoolLevelSelected,
              onGradeLevelSelected: _onGradeLevelSelected,
              sort: _sort,
              onSortSelected: _onSortSelected,
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
        if (_students.isEmpty) return const _EmptyState();
        return ListView.separated(
          controller: _scrollController,
          padding: EdgeInsets.zero,
          itemCount: _students.length + (_hasMore ? 1 : 0),
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.rowDivider),
          itemBuilder: (context, index) {
            if (index >= _students.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            return _StudentRow(student: _students[index]);
          },
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.onChanged,
    required this.statusFilter,
    required this.onStatusSelected,
    required this.sexFilter,
    required this.onSexSelected,
    required this.sort,
    required this.onSortSelected,
    required this.schoolLevel,
    required this.gradeLevel,
    required this.availableGradeLevels,
    required this.onSchoolLevelSelected,
    required this.onGradeLevelSelected,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final StudentStatus? statusFilter;
  final ValueChanged<StudentStatus?> onStatusSelected;
  final _SexFilter sexFilter;
  final ValueChanged<_SexFilter> onSexSelected;
  final _SortOption sort;
  final ValueChanged<_SortOption> onSortSelected;
  final String schoolLevel;
  final String gradeLevel;
  final List<String> availableGradeLevels;
  final ValueChanged<String> onSchoolLevelSelected;
  final ValueChanged<String> onGradeLevelSelected;

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
            'Students',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.headingDark,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            onChanged: onChanged,
            style: GoogleFonts.dmSans(fontSize: 13, color: const Color(0xFF2D1A1A)),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search name or LRN',
              hintStyle: GoogleFonts.dmSans(fontSize: 13, color: AppColors.iconMuted),
              prefixIcon: const Icon(Icons.search, size: 18, color: AppColors.iconMuted),
              contentPadding: const EdgeInsets.symmetric(vertical: 9),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<StudentStatus?>(
                  icon: Icons.flag_outlined,
                  value: statusFilter,
                  label: statusFilter?.label ?? 'All statuses',
                  isActive: statusFilter != null,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All statuses')),
                    for (final s in StudentStatus.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: onStatusSelected,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<_SexFilter>(
                  icon: Icons.wc_outlined,
                  value: sexFilter,
                  label: sexFilter.label,
                  isActive: sexFilter != _SexFilter.all,
                  items: [
                    for (final s in _SexFilter.values)
                      DropdownMenuItem(value: s, child: Text(s.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) onSexSelected(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _FilterDropdown<String>(
                  icon: Icons.school_outlined,
                  value: schoolLevel,
                  label: schoolLevel == _kAllSchoolLevels
                      ? 'All levels'
                      : SchoolLevel.values
                            .firstWhere((l) => schoolLevelToJson(l) == schoolLevel)
                            .label,
                  isActive: schoolLevel != _kAllSchoolLevels,
                  items: [
                    const DropdownMenuItem(value: _kAllSchoolLevels, child: Text('All levels')),
                    for (final l in SchoolLevel.values)
                      DropdownMenuItem(value: schoolLevelToJson(l), child: Text(l.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) onSchoolLevelSelected(v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterDropdown<String>(
                  icon: Icons.grade_outlined,
                  value: gradeLevel,
                  label: gradeLevel == _kAllGradeLevels ? 'All grades' : gradeLevel,
                  isActive: gradeLevel != _kAllGradeLevels,
                  items: [
                    const DropdownMenuItem(value: _kAllGradeLevels, child: Text('All grades')),
                    for (final g in availableGradeLevels) DropdownMenuItem(value: g, child: Text(g)),
                  ],
                  onChanged: (v) {
                    if (v != null) onGradeLevelSelected(v);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _FilterDropdown<_SortOption>(
            icon: Icons.swap_vert,
            value: sort,
            label: sort.label,
            isActive: sort != _SortOption.newest,
            items: [
              for (final s in _SortOption.values) DropdownMenuItem(value: s, child: Text(s.label)),
            ],
            onChanged: (v) {
              if (v != null) onSortSelected(v);
            },
          ),
        ],
      ),
    );
  }
}

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.icon,
    required this.value,
    required this.label,
    required this.isActive,
    required this.items,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final T value;
  final String label;
  final bool isActive;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.primary : AppColors.textMuted1;
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFFFF0F0) : AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: isActive ? AppColors.primary : AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          isDense: true,
          icon: Icon(Icons.expand_more, size: 16, color: color),
          borderRadius: BorderRadius.circular(AppRadii.input),
          selectedItemBuilder: (context) {
            return [
              for (final _ in items)
                Row(
                  children: [
                    Icon(icon, size: 13, color: color),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w600, color: color),
                      ),
                    ),
                  ],
                ),
            ];
          },
          items: [
            for (final item in items)
              DropdownMenuItem<T>(
                value: item.value,
                child: DefaultTextStyle(
                  style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.headingDark),
                  child: item.child,
                ),
              ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => StudentDetailScreen(student: student)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFDF3F2),
              ),
              child: Center(
                child: Text(
                  student.initials,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    student.lrn,
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            StudentStatusPill(status: student.statusValue),
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
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Try a different name or LRN, or adjust filters',
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
              "Couldn't load students",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
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
