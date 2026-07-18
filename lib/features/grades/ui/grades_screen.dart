import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/auth/roles.dart';
import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../advisory/state/advisory_provider.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../../auth/state/auth_provider.dart';
import '../data/grades_repository.dart';
import '../models/graded_student.dart';
import '../models/grading_period.dart';
import '../models/subject.dart';
import 'grade_colors.dart';
import 'grade_detail_screen.dart';

enum _LoadStatus { loading, loaded, error }

/// Display label for a section's strand, if any — e.g. "Grade 11 - STEM A".
String _sectionLabel(SectionAdvisory advisory) =>
    advisory.strand == null ? advisory.section : '${advisory.section} (${advisory.strand})';

/// Cascading School Level → Grade Level → Section filter over an already
/// -fetched [SectionAdvisory] list (staff roles get every section
/// school-wide from [AdvisoryProvider], per `advisory_api.dart`). Options at
/// each tier are the distinct values actually present among the sections
/// matching the tiers above it, so cycling never lands on an empty result.
class _SectionFilter {
  const _SectionFilter({required this.schoolLevel, required this.gradeLevel, required this.section});

  final SchoolLevel schoolLevel;
  final String gradeLevel;
  final String section;

  static List<SchoolLevel> levelsIn(List<SectionAdvisory> advisories) {
    final present = advisories.map((a) => a.schoolLevel).toSet();
    return SchoolLevel.values.where(present.contains).toList();
  }

  static List<String> gradeLevelsIn(List<SectionAdvisory> advisories, SchoolLevel level) {
    final grades = advisories.where((a) => a.schoolLevel == level).map((a) => a.gradeLevel).toSet().toList();
    grades.sort();
    return grades;
  }

  /// Section labels within [level] + [gradeLevel], sorted for stable
  /// cycling order (distinct because a grade level can repeat a section
  /// name across strands, e.g. two "A" sections in different SHS strands).
  static List<String> sectionsIn(List<SectionAdvisory> advisories, SchoolLevel level, String gradeLevel) {
    final sections = advisories
        .where((a) => a.schoolLevel == level && a.gradeLevel == gradeLevel)
        .map(_sectionLabel)
        .toSet()
        .toList();
    sections.sort();
    return sections;
  }

  /// Finds the single [SectionAdvisory] matching this filter. Returns null
  /// only if the advisory list changed out from under a stale selection
  /// (e.g. mid-refresh) — callers should treat that as "reset filter".
  static SectionAdvisory? resolve(List<SectionAdvisory> advisories, _SectionFilter filter) {
    for (final a in advisories) {
      if (a.schoolLevel == filter.schoolLevel &&
          a.gradeLevel == filter.gradeLevel &&
          _sectionLabel(a) == filter.section) {
        return a;
      }
    }
    return null;
  }

  /// The default filter for a freshly loaded advisory list: first school
  /// level, first grade level within it, first section within that.
  static _SectionFilter? initial(List<SectionAdvisory> advisories) {
    final levels = levelsIn(advisories);
    if (levels.isEmpty) return null;
    final level = levels.first;
    final grades = gradeLevelsIn(advisories, level);
    if (grades.isEmpty) return null;
    final grade = grades.first;
    final sections = sectionsIn(advisories, level, grade);
    if (sections.isEmpty) return null;
    return _SectionFilter(schoolLevel: level, gradeLevel: grade, section: sections.first);
  }
}

/// Grades tab: section/subject/period pickers + roster with final-grade
/// badges. Reuses [AdvisoryProvider] for the section list (same source as
/// Attendance, per the handoff, to avoid a second fetch of
/// `/api/section-advisories/`).
class GradesScreen extends StatefulWidget {
  const GradesScreen({super.key, required this.repository});

  final GradesRepository repository;

  @override
  State<GradesScreen> createState() => _GradesScreenState();
}

class _GradesScreenState extends State<GradesScreen> {
  List<Subject> _subjects = const [];
  int _sectionIndex = 0;
  int _subjectIndex = 0;
  GradingPeriod? _period;

  _LoadStatus _subjectsStatus = _LoadStatus.loading;
  _LoadStatus _rosterStatus = _LoadStatus.loading;
  List<GradedStudent> _roster = const [];

  bool _initializedFromAdvisory = false;

  /// The section (grade level + strand) subjects were last fetched for —
  /// subjects are scoped by grade level (and strand for SHS), not just
  /// school level, so cycling between e.g. two Grade 7 sections doesn't
  /// need a reload but cycling to Grade 8 does.
  SectionAdvisory? _subjectsLoadedForSection;

  /// Staff (registrar/admin/super_admin) get every section school-wide via
  /// [AdvisoryProvider], so a single cycle-through-everything picker (what
  /// teachers use, via [_sectionIndex]) doesn't scale — this drives a
  /// cascading School Level → Grade Level → Section picker instead. Null
  /// until the advisory list has loaded at least once.
  _SectionFilter? _staffFilter;

  /// Subjects are scoped by grade level (and strand for SHS) — see
  /// `Subject.fromJson`'s `grade_level`/`strand` fields — so they must be
  /// reloaded whenever the selected section's grade/strand differs from the
  /// last fetch (e.g. cycling from Grade 7 to Grade 8, or between strands).
  Future<void> _loadSubjectsIfNeeded(SectionAdvisory section) async {
    final loadedFor = _subjectsLoadedForSection;
    if (loadedFor != null &&
        loadedFor.schoolLevel == section.schoolLevel &&
        loadedFor.gradeLevel == section.gradeLevel &&
        loadedFor.strand == section.strand) {
      return;
    }
    setState(() => _subjectsStatus = _LoadStatus.loading);
    try {
      final subjects = await widget.repository.fetchSubjects(
        schoolLevel: section.schoolLevel,
        gradeLevel: section.gradeLevel,
        strand: section.strand,
      );
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _subjectIndex = 0;
        _subjectsLoadedForSection = section;
        _subjectsStatus = _LoadStatus.loaded;
      });
      _loadRoster();
    } catch (_) {
      if (!mounted) return;
      setState(() => _subjectsStatus = _LoadStatus.error);
    }
  }

  void _initPeriodIfNeeded(SectionAdvisory section) {
    final options = periodsForSchoolLevel(section.schoolLevel);
    if (_period == null || !options.contains(_period)) {
      _period = options.first;
    }
  }

  /// True for registrar/admin/super_admin, who get every section
  /// school-wide (see [AdvisoryProvider.load]) and so need the cascading
  /// filter rather than teacher's simple cycle-through-mine picker.
  bool _isStaffRole(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role;
    return hasAnyRole(role, academicStaff);
  }

  /// Resolves the currently selected section: staff use [_staffFilter]
  /// against the full school-wide list, teachers use [_sectionIndex]
  /// against their own (short) advisory list.
  SectionAdvisory? _selectedSection(List<SectionAdvisory> advisories, bool isStaff) {
    if (isStaff) {
      final filter = _staffFilter;
      if (filter == null) return null;
      return _SectionFilter.resolve(advisories, filter);
    }
    if (advisories.isEmpty) return null;
    return advisories[_sectionIndex.clamp(0, advisories.length - 1)];
  }

  Future<void> _loadRoster() async {
    final advisory = context.read<AdvisoryProvider>();
    final isStaff = _isStaffRole(context);
    final section = _selectedSection(advisory.advisories, isStaff);
    if (section == null) return;
    final loadedFor = _subjectsLoadedForSection;
    final subjectsCurrent = loadedFor != null &&
        loadedFor.schoolLevel == section.schoolLevel &&
        loadedFor.gradeLevel == section.gradeLevel &&
        loadedFor.strand == section.strand;
    if (!subjectsCurrent) {
      _loadSubjectsIfNeeded(section);
      return;
    }
    if (_subjects.isEmpty) return;
    final subject = _subjects[_subjectIndex.clamp(0, _subjects.length - 1)];
    _initPeriodIfNeeded(section);

    setState(() => _rosterStatus = _LoadStatus.loading);
    try {
      final roster = await widget.repository.fetchGradedRoster(
        section: section,
        subjectId: subject.id,
        period: _period!.toJson(),
      );
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _rosterStatus = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _rosterStatus = _LoadStatus.error);
    }
  }

  void _selectSectionIndex(int index) {
    setState(() => _sectionIndex = index);
    _loadRoster();
  }

  void _cycleSchoolLevel(List<SectionAdvisory> advisories) {
    final filter = _staffFilter;
    if (filter == null) return;
    final levels = _SectionFilter.levelsIn(advisories);
    final next = levels[(levels.indexOf(filter.schoolLevel) + 1) % levels.length];
    final grades = _SectionFilter.gradeLevelsIn(advisories, next);
    final grade = grades.first;
    final sections = _SectionFilter.sectionsIn(advisories, next, grade);
    setState(() {
      _staffFilter = _SectionFilter(schoolLevel: next, gradeLevel: grade, section: sections.first);
    });
    _loadRoster();
  }

  void _cycleGradeLevel(List<SectionAdvisory> advisories) {
    final filter = _staffFilter;
    if (filter == null) return;
    final grades = _SectionFilter.gradeLevelsIn(advisories, filter.schoolLevel);
    final next = grades[(grades.indexOf(filter.gradeLevel) + 1) % grades.length];
    final sections = _SectionFilter.sectionsIn(advisories, filter.schoolLevel, next);
    setState(() {
      _staffFilter = _SectionFilter(schoolLevel: filter.schoolLevel, gradeLevel: next, section: sections.first);
    });
    _loadRoster();
  }

  void _cycleStaffSection(List<SectionAdvisory> advisories) {
    final filter = _staffFilter;
    if (filter == null) return;
    final sections = _SectionFilter.sectionsIn(advisories, filter.schoolLevel, filter.gradeLevel);
    final next = sections[(sections.indexOf(filter.section) + 1) % sections.length];
    setState(() {
      _staffFilter = _SectionFilter(schoolLevel: filter.schoolLevel, gradeLevel: filter.gradeLevel, section: next);
    });
    _loadRoster();
  }

  void _selectSubjectIndex(int index) {
    setState(() => _subjectIndex = index);
    _loadRoster();
  }

  void _selectPeriod(GradingPeriod period) {
    setState(() => _period = period);
    _loadRoster();
  }

  Future<void> _openStudent(SectionAdvisory section, Subject subject, GradedStudent student) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GradeDetailScreen(
          repository: widget.repository,
          section: section,
          subject: subject,
          period: _period!,
          enrollmentId: student.enrollmentId,
          studentName: student.studentName,
        ),
      ),
    );
    if (saved == true) _loadRoster();
  }

  @override
  Widget build(BuildContext context) {
    final advisory = context.watch<AdvisoryProvider>();
    final isStaff = _isStaffRole(context);

    if (!_initializedFromAdvisory && advisory.status == AdvisoryStatus.loaded) {
      _initializedFromAdvisory = true;
      if (isStaff) {
        _staffFilter = _SectionFilter.initial(advisory.advisories);
      }
      final section = _selectedSection(advisory.advisories, isStaff);
      if (section != null) {
        _loadSubjectsIfNeeded(section);
      }
    }

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Grades',
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: _buildBody(advisory, isStaff),
    );
  }

  Widget _buildBody(AdvisoryProvider advisory, bool isStaff) {
    if (advisory.status == AdvisoryStatus.loading || advisory.status == AdvisoryStatus.initial) {
      return const Center(child: CircularProgressIndicator());
    }
    if (advisory.status == AdvisoryStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        child: NetworkErrorState(onRetry: () => advisory.load()),
      );
    }
    if (advisory.hasNoSectionsAssigned) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        child: NoSectionsAssignedState(),
      );
    }
    final sections = advisory.advisories;
    final section = _selectedSection(sections, isStaff);
    if (section == null) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        child: NoSectionsAssignedState(),
      );
    }

    if (_subjectsStatus == _LoadStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        child: NetworkErrorState(onRetry: () => _loadSubjectsIfNeeded(section)),
      );
    }
    if (_subjectsStatus == _LoadStatus.loading || _subjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final subject = _subjects[_subjectIndex.clamp(0, _subjects.length - 1)];
    final periods = periodsForSchoolLevel(section.schoolLevel);
    _period ??= periods.first;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
          ),
          child: Column(
            children: [
              if (isStaff) ...[
                _StaffSectionFilterRow(
                  filter: _staffFilter!,
                  onCycleSchoolLevel: () => _cycleSchoolLevel(sections),
                  onCycleGradeLevel: () => _cycleGradeLevel(sections),
                  onCycleSection: () => _cycleStaffSection(sections),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  if (!isStaff)
                    Expanded(
                      child: _IndexDropdown(
                        value: _sectionIndex.clamp(0, sections.length - 1),
                        items: [
                          for (var i = 0; i < sections.length; i++)
                            (value: i, label: sections[i].displayName),
                        ],
                        onChanged: _selectSectionIndex,
                      ),
                    ),
                  if (!isStaff) const SizedBox(width: 8),
                  Expanded(
                    child: _IndexDropdown(
                      value: _subjectIndex.clamp(0, _subjects.length - 1),
                      items: [
                        for (var i = 0; i < _subjects.length; i++)
                          (value: i, label: _subjects[i].name),
                      ],
                      onChanged: _selectSubjectIndex,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in periods) ...[
                      _PeriodChip(
                        label: p.label,
                        selected: p == _period,
                        onTap: () => _selectPeriod(p),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildRoster(section, subject)),
      ],
    );
  }

  Widget _buildRoster(SectionAdvisory section, Subject subject) {
    switch (_rosterStatus) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          child: NetworkErrorState(onRetry: _loadRoster),
        );
      case _LoadStatus.loaded:
        if (_roster.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: NoScoresEnteredState(),
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _roster.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.rowDivider),
          itemBuilder: (context, index) {
            final student = _roster[index];
            return _StudentRow(
              student: student,
              onTap: () => _openStudent(section, subject, student),
            );
          },
        );
    }
  }
}

/// Staff-only (registrar/admin/super_admin) cascading School Level → Grade
/// Level → Section row, replacing the teacher's single section
/// [_PickerField] since staff need to reach any of potentially dozens of
/// sections school-wide rather than cycling through 1-2 of their own.
class _StaffSectionFilterRow extends StatelessWidget {
  const _StaffSectionFilterRow({
    required this.filter,
    required this.onCycleSchoolLevel,
    required this.onCycleGradeLevel,
    required this.onCycleSection,
  });

  final _SectionFilter filter;
  final VoidCallback onCycleSchoolLevel;
  final VoidCallback onCycleGradeLevel;
  final VoidCallback onCycleSection;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PickerField(label: filter.schoolLevel.label, onTap: onCycleSchoolLevel),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PickerField(label: filter.gradeLevel, onTap: onCycleGradeLevel),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _PickerField(label: filter.section, onTap: onCycleSection),
        ),
      ],
    );
  }
}

/// A real dropdown (tap opens a menu, pick from a list) over `(index, label)`
/// pairs — same look and interaction as the admin Monitoring tab's
/// `_FilterDropdown` (`monitoring_screen.dart`), used here for the teacher's
/// Section and Subject pickers in place of the old tap-to-cycle
/// [_PickerField]. Keyed by list index rather than a string id since neither
/// [SectionAdvisory] nor [Subject] has a stable string value handy at this
/// call site the way Monitoring's school-level/grade-level strings do.
class _IndexDropdown extends StatelessWidget {
  const _IndexDropdown({required this.value, required this.items, required this.onChanged});

  final int value;
  final List<({int value, String label})> items;
  final ValueChanged<int> onChanged;

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
        child: DropdownButton<int>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted2),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
          items: [
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

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.input),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.inputBg,
          borderRadius: BorderRadius.circular(AppRadii.input),
          border: Border.all(color: AppColors.inputBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted2),
          ],
        ),
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({required this.label, required this.selected, required this.onTap});

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
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMuted1,
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.student, required this.onTap});

  final GradedStudent student;
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
              width: 36,
              height: 36,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF3F2)),
              child: Center(
                child: Text(
                  student.initials,
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                student.studentName,
                style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: gradeBackground(student.numericGrade),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                student.numericGrade?.toStringAsFixed(2) ?? 'Not graded',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: gradeForeground(student.numericGrade),
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
