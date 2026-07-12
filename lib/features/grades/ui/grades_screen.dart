import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../advisory/state/advisory_provider.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../data/grades_repository.dart';
import '../models/graded_student.dart';
import '../models/grading_period.dart';
import '../models/subject.dart';
import 'grade_colors.dart';
import 'grade_detail_screen.dart';

enum _LoadStatus { loading, loaded, error }

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

  @override
  void initState() {
    super.initState();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _subjectsStatus = _LoadStatus.loading);
    try {
      final subjects = await widget.repository.fetchSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
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

  Future<void> _loadRoster() async {
    final advisory = context.read<AdvisoryProvider>();
    if (advisory.advisories.isEmpty || _subjects.isEmpty) return;
    final section = advisory.advisories[_sectionIndex.clamp(0, advisory.advisories.length - 1)];
    final subject = _subjects[_subjectIndex.clamp(0, _subjects.length - 1)];
    _initPeriodIfNeeded(section);

    setState(() => _rosterStatus = _LoadStatus.loading);
    try {
      final roster = await widget.repository.fetchGradedRoster(
        sectionAdvisoryId: section.id,
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

  void _cycleSection(int sectionCount) {
    setState(() => _sectionIndex = (_sectionIndex + 1) % sectionCount);
    _loadRoster();
  }

  void _cycleSubject() {
    if (_subjects.isEmpty) return;
    setState(() => _subjectIndex = (_subjectIndex + 1) % _subjects.length);
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

    if (!_initializedFromAdvisory && advisory.status == AdvisoryStatus.loaded) {
      _initializedFromAdvisory = true;
      if (advisory.advisories.isNotEmpty && _subjects.isNotEmpty) _loadRoster();
    }

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Grades',
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: _buildBody(advisory),
    );
  }

  Widget _buildBody(AdvisoryProvider advisory) {
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
    if (_subjectsStatus == _LoadStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        child: NetworkErrorState(onRetry: _loadSubjects),
      );
    }
    if (_subjectsStatus == _LoadStatus.loading || _subjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final sections = advisory.advisories;
    final section = sections[_sectionIndex.clamp(0, sections.length - 1)];
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
              Row(
                children: [
                  Expanded(
                    child: _PickerField(
                      label: section.displayName,
                      onTap: () => _cycleSection(sections.length),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _PickerField(label: subject.name, onTap: _cycleSubject),
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
                color: gradeBackground(student.finalGrade),
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                student.finalGrade?.toStringAsFixed(2) ?? 'Not graded',
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: gradeForeground(student.finalGrade),
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
