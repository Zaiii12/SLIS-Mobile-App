import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/enrollment_repository.dart';
import '../models/pending_enrollment.dart';
import 'billing_format.dart';
import 'pending_enrollment_detail_screen.dart';

enum _LoadStatus { loading, loaded, error }

/// Reminders-only view of pending enrollment applications, backed by real
/// data from `GET /api/enrollments/?enrollment_status=pending`
/// (enrollment-service) — no approve/reject action anywhere here,
/// intentionally; that workflow stays on the web admin portal. Tapping a row
/// pushes PendingEnrollmentDetailScreen (read-only), matching the Invoice
/// list→detail pattern.
class PendingEnrollmentScreen extends StatefulWidget {
  const PendingEnrollmentScreen({super.key, required this.repository});

  final EnrollmentRepository repository;

  @override
  State<PendingEnrollmentScreen> createState() =>
      _PendingEnrollmentScreenState();
}

class _PendingEnrollmentScreenState extends State<PendingEnrollmentScreen> {
  final _searchController = TextEditingController();
  String _search = '';
  String? _levelFilter;
  String? _yearFilter;
  _LoadStatus _status = _LoadStatus.loading;
  List<PendingEnrollment> _enrollments = const [];

  @override
  void initState() {
    super.initState();
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
      final result = await widget.repository.fetchPendingEnrollments();
      if (!mounted) return;
      setState(() {
        _enrollments = result;
        _status = _LoadStatus.loaded;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint(
        'EnrollmentRepository.fetchPendingEnrollments failed: $error\n$stackTrace',
      );
      setState(() => _status = _LoadStatus.error);
    }
  }

  List<PendingEnrollment> get _filtered {
    var list = _enrollments;
    if (_levelFilter != null) {
      list = list.where((e) => e.schoolLevel == _levelFilter).toList();
    }
    if (_yearFilter != null) {
      list = list.where((e) => e.schoolYear == _yearFilter).toList();
    }
    final term = _search.trim().toLowerCase();
    if (term.isNotEmpty) {
      list = list
          .where((e) => e.studentName.toLowerCase().contains(term))
          .toList();
    }
    // No submitted-date field exists on Enrollment (see PendingEnrollment doc
    // comment) — enrollment_id is monotonically increasing, so ascending id
    // approximates oldest-first within a school year, without inventing a
    // fake timestamp.
    return [...list]..sort((a, b) => a.enrollmentId.compareTo(b.enrollmentId));
  }

  /// Groups the filtered list by school year, most recent year first —
  /// mirrors the real ASIA web admin portal's enrollments view, which scopes
  /// to a persisted school-year selector (`EnrollmentsPage.jsx` +
  /// `SchoolYearContext`). Mobile has no equivalent year-switcher control
  /// yet, so grouping with section headers gives the same organization
  /// without adding one.
  List<MapEntry<String, List<PendingEnrollment>>> get _groupedByYear {
    final byYear = <String, List<PendingEnrollment>>{};
    for (final e in _filtered) {
      byYear.putIfAbsent(e.schoolYear, () => []).add(e);
    }
    final years = byYear.keys.toList()..sort((a, b) => b.compareTo(a));
    return [for (final y in years) MapEntry(y, byYear[y]!)];
  }

  List<String> get _levelsPresent =>
      _enrollments.map((e) => e.schoolLevel).toSet().toList();

  List<String> get _yearsPresent =>
      _enrollments.map((e) => e.schoolYear).toSet().toList()
        ..sort((a, b) => b.compareTo(a));

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Pending Enrollment',
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.cardWhite,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v),
                  style: GoogleFonts.dmSans(
                    fontSize: 12.5,
                    color: const Color(0xFF2D1A1A),
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search student name',
                    hintStyle: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      color: AppColors.iconMuted,
                    ),
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 18,
                      color: AppColors.iconMuted,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _LevelChip(
                        label: 'All',
                        selected: _levelFilter == null,
                        onTap: () => setState(() => _levelFilter = null),
                      ),
                      const SizedBox(width: 8),
                      for (final level in _levelsPresent) ...[
                        _LevelChip(
                          label: shortSchoolLevel(level),
                          selected: _levelFilter == level,
                          onTap: () => setState(() => _levelFilter = level),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
                if (_yearsPresent.length > 1) ...[
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _LevelChip(
                          label: 'All Years',
                          selected: _yearFilter == null,
                          onTap: () => setState(() => _yearFilter = null),
                        ),
                        const SizedBox(width: 8),
                        for (final year in _yearsPresent) ...[
                          _LevelChip(
                            label: 'S.Y. $year',
                            selected: _yearFilter == year,
                            onTap: () => setState(() => _yearFilter = year),
                          ),
                          const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.cardWhite,
            child: Text(
              '${filtered.length} of ${_enrollments.length} awaiting review',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: AppColors.textMuted2,
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.cardBorder),
          Expanded(child: _buildBody(filtered)),
        ],
      ),
    );
  }

  Widget _buildBody(List<PendingEnrollment> filtered) {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return _ErrorState(onRetry: _load);
      case _LoadStatus.loaded:
        if (filtered.isEmpty) {
          return _EmptyState(
            hasFilter:
                _search.trim().isNotEmpty ||
                _levelFilter != null ||
                _yearFilter != null,
          );
        }
        final groups = _groupedByYear;
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: groups.length,
            itemBuilder: (context, groupIndex) {
              final group = groups[groupIndex];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _YearHeader(schoolYear: group.key, count: group.value.length),
                  for (final e in group.value) ...[
                    _EnrollmentRow(
                      enrollment: e,
                      repository: widget.repository,
                    ),
                    const Divider(height: 1, color: AppColors.rowDivider),
                  ],
                ],
              );
            },
          ),
        );
    }
  }
}

class _YearHeader extends StatelessWidget {
  const _YearHeader({required this.schoolYear, required this.count});

  final String schoolYear;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      color: AppColors.dashboardBg,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'S.Y. $schoolYear',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.labelUppercase1,
            ),
          ),
          Text(
            '$count',
            style: GoogleFonts.dmSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.neutralPillBg,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: selected ? null : Border.all(color: AppColors.cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : AppColors.textMuted1,
          ),
        ),
      ),
    );
  }
}

class _EnrollmentRow extends StatelessWidget {
  const _EnrollmentRow({required this.enrollment, required this.repository});

  final PendingEnrollment enrollment;
  final EnrollmentRepository repository;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PendingEnrollmentDetailScreen(
            enrollment: enrollment,
            repository: repository,
          ),
        ),
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
                  enrollment.initials,
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
                    enrollment.studentName,
                    style: GoogleFonts.dmSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${enrollment.lrn.isNotEmpty ? 'LRN ${enrollment.lrn}' : 'New student'} · ${enrollment.gradeLevel} · ${enrollment.schoolYear}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.neutralPillBg,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                'Pending',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: AppColors.neutralPillText,
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
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasFilter ? Icons.search : Icons.assignment_outlined,
              size: 28,
              color: const Color(0xFFD8B8B4),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'No matching applications'
                  : 'No pending applications',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              hasFilter
                  ? 'Try a different name or filter'
                  : "Everything's reviewed for now",
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: AppColors.textMuted3,
              ),
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
              "Couldn't load applications",
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
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
