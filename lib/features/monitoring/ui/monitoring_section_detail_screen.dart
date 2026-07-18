import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/attendance_status.dart';
import '../../attendance/models/roster_entry.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../../dashboard/models/dashboard_data.dart';
import '../../grades/data/grades_repository.dart';
import '../../grades/models/graded_student.dart';
import '../../grades/models/grading_period.dart';
import '../../grades/models/subject.dart';
import '../../grades/ui/grade_colors.dart';
import '../models/teacher.dart';

enum _Mode { attendance, grades }

enum _LoadStatus { loading, loaded, error }

/// Read-only admin view of one teacher's section: today's attendance marks
/// and the graded roster for a subject/period. Deliberately does not reuse
/// [AttendanceRosterScreen] (submits attendance) or `GradeDetailScreen`
/// (edits scores) — monitoring is oversight only, not a way to act on a
/// teacher's behalf.
class MonitoringSectionDetailScreen extends StatefulWidget {
  const MonitoringSectionDetailScreen({
    super.key,
    required this.teacher,
    required this.section,
    required this.attendanceRepository,
    required this.gradesRepository,
  });

  final Teacher teacher;
  final SectionAdvisory section;
  final AttendanceRepository attendanceRepository;
  final GradesRepository gradesRepository;

  @override
  State<MonitoringSectionDetailScreen> createState() => _MonitoringSectionDetailScreenState();
}

class _MonitoringSectionDetailScreenState extends State<MonitoringSectionDetailScreen> {
  _Mode _mode = _Mode.attendance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          widget.section.displayName,
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: _ModeToggle(
              mode: _mode,
              onChanged: (mode) => setState(() => _mode = mode),
            ),
          ),
          Expanded(
            child: _mode == _Mode.attendance
                ? _AttendancePane(section: widget.section, repository: widget.attendanceRepository)
                : _GradesPane(section: widget.section, repository: widget.gradesRepository),
          ),
        ],
      ),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.mode, required this.onChanged});

  final _Mode mode;
  final ValueChanged<_Mode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.neutralPillBg,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        children: [
          Expanded(child: _ModeButton(label: 'Attendance', selected: mode == _Mode.attendance, onTap: () => onChanged(_Mode.attendance))),
          Expanded(child: _ModeButton(label: 'Grades', selected: mode == _Mode.grades, onTap: () => onChanged(_Mode.grades))),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : AppColors.textMuted1,
          ),
        ),
      ),
    );
  }
}

/// Today's attendance marks for the section, read-only — no submit/edit
/// controls, since monitoring must not let admin act as the teacher.
class _AttendancePane extends StatefulWidget {
  const _AttendancePane({required this.section, required this.repository});

  final SectionAdvisory section;
  final AttendanceRepository repository;

  @override
  State<_AttendancePane> createState() => _AttendancePaneState();
}

class _AttendancePaneState extends State<_AttendancePane> {
  final _today = DateTime.now();
  _LoadStatus _status = _LoadStatus.loading;
  List<RosterEntry> _roster = const [];
  Map<int, AttendanceStatus> _marks = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final results = await Future.wait([
        widget.repository.fetchRoster(widget.section),
        widget.repository.fetchExisting(section: widget.section, date: _today),
      ]);
      if (!mounted) return;
      setState(() {
        _roster = results[0] as List<RosterEntry>;
        _marks = results[1] as Map<int, AttendanceStatus>;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  /// Derived client-side from [_roster]/[_marks] rather than
  /// `AttendanceRepository.fetchSummary` (backs the teacher-facing "Today's
  /// Summary" card), which has no section filter and returns a school-wide
  /// total — wrong for a single section's detail view. Unmarked students
  /// default to present, matching how the roster/marking screen treats them.
  AttendanceBreakdown get _summary {
    var present = 0, late = 0, absent = 0;
    for (final entry in _roster) {
      switch (_marks[entry.enrollmentId] ?? AttendanceStatus.present) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.absent:
          absent++;
      }
    }
    return AttendanceBreakdown(present: present, late: late, absent: absent);
  }

  @override
  Widget build(BuildContext context) {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return Padding(
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          child: NetworkErrorState(onRetry: _load),
        );
      case _LoadStatus.loaded:
        if (_roster.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No students enrolled')));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: _roster.length + 1,
          separatorBuilder: (_, index) => index == 0 ? const SizedBox(height: 4) : const Divider(height: 1, color: AppColors.rowDivider),
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _AttendanceSummaryCard(summary: _summary, date: _today),
              );
            }
            final entry = _roster[index - 1];
            final mark = _marks[entry.enrollmentId] ?? AttendanceStatus.present;
            return _AttendanceRow(entry: entry, status: mark);
          },
        );
    }
  }
}

/// Mirrors [AttendanceScreen]'s "Today's Summary" card (Present/Late/Absent
/// mini-stats + attendance-rate bar), scoped to one section instead of
/// every section the signed-in user can see.
class _AttendanceSummaryCard extends StatelessWidget {
  const _AttendanceSummaryCard({required this.summary, required this.date});

  final AttendanceBreakdown summary;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.cardBorder))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Summary",
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                ),
                Text(
                  DateFormat('MMMM d').format(date),
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  children: [
                    _MiniStat(
                      value: summary.present,
                      label: 'Present',
                      background: AppColors.successBg2,
                      textColor: AppColors.successText2,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      value: summary.late,
                      label: 'Late',
                      background: AppColors.warningBg,
                      textColor: AppColors.warningText,
                      labelColor: AppColors.warningText2,
                    ),
                    const SizedBox(width: 8),
                    _MiniStat(
                      value: summary.absent,
                      label: 'Absent',
                      background: AppColors.dangerBg2,
                      textColor: AppColors.dangerText,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Attendance rate', style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3)),
                    Text(
                      '${summary.ratePercent}%',
                      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.successText),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: summary.ratePercent / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.cardBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.successFill),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.value,
    required this.label,
    required this.background,
    required this.textColor,
    Color? labelColor,
  }) : labelColor = labelColor ?? textColor;

  final int value;
  final String label;
  final Color background;
  final Color textColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
        child: Column(
          children: [
            Text('$value', style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
            Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: labelColor)),
          ],
        ),
      ),
    );
  }
}

class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({required this.entry, required this.status});

  final RosterEntry entry;
  final AttendanceStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      AttendanceStatus.present => ('Present', AppColors.successText2),
      AttendanceStatus.late => ('Late', AppColors.warningText),
      AttendanceStatus.absent => ('Absent', AppColors.primary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF3F2)),
            child: Center(
              child: Text(
                entry.initials,
                style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.studentName,
              style: GoogleFonts.dmSans(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(AppRadii.pill)),
            child: Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

/// Graded roster for a subject/period, read-only — mirrors
/// [GradesScreen]'s single-section body (subject/period pickers + roster)
/// but for a section fixed by the admin's teacher/section drill-down rather
/// than the signed-in user's own advisory list, and with no tap-through to
/// [GradeDetailScreen] (that screen edits scores).
class _GradesPane extends StatefulWidget {
  const _GradesPane({required this.section, required this.repository});

  final SectionAdvisory section;
  final GradesRepository repository;

  @override
  State<_GradesPane> createState() => _GradesPaneState();
}

class _GradesPaneState extends State<_GradesPane> {
  _LoadStatus _subjectsStatus = _LoadStatus.loading;
  _LoadStatus _rosterStatus = _LoadStatus.loading;
  List<Subject> _subjects = const [];
  List<GradedStudent> _roster = const [];
  int _subjectIndex = 0;
  late GradingPeriod _period;

  @override
  void initState() {
    super.initState();
    _period = periodsForSchoolLevel(widget.section.schoolLevel).first;
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    setState(() => _subjectsStatus = _LoadStatus.loading);
    try {
      final subjects = await widget.repository.fetchSubjects(
        schoolLevel: widget.section.schoolLevel,
        gradeLevel: widget.section.gradeLevel,
        strand: widget.section.strand,
      );
      if (!mounted) return;
      setState(() {
        _subjects = subjects;
        _subjectIndex = 0;
        _subjectsStatus = _LoadStatus.loaded;
      });
      _loadRoster();
    } catch (_) {
      if (!mounted) return;
      setState(() => _subjectsStatus = _LoadStatus.error);
    }
  }

  Future<void> _loadRoster() async {
    if (_subjects.isEmpty) return;
    final subject = _subjects[_subjectIndex.clamp(0, _subjects.length - 1)];
    setState(() => _rosterStatus = _LoadStatus.loading);
    try {
      final roster = await widget.repository.fetchGradedRoster(
        section: widget.section,
        subjectId: subject.id,
        period: _period.toJson(),
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

  void _selectSubject(int index) {
    if (index == _subjectIndex || index < 0 || index >= _subjects.length) return;
    setState(() => _subjectIndex = index);
    _loadRoster();
  }

  void _selectPeriod(GradingPeriod period) {
    setState(() => _period = period);
    _loadRoster();
  }

  @override
  Widget build(BuildContext context) {
    if (_subjectsStatus == _LoadStatus.error) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
        child: NetworkErrorState(onRetry: _loadSubjects),
      );
    }
    if (_subjectsStatus == _LoadStatus.loading || _subjects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final periods = periodsForSchoolLevel(widget.section.schoolLevel);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Column(
            children: [
              _SubjectDropdownField(
                subjects: _subjects,
                selectedIndex: _subjectIndex.clamp(0, _subjects.length - 1),
                onChanged: _selectSubject,
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final p in periods) ...[
                      _PeriodChip(label: p.label, selected: p == _period, onTap: () => _selectPeriod(p)),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildRoster()),
      ],
    );
  }

  Widget _buildRoster() {
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
          return const Center(child: Padding(padding: EdgeInsets.all(24), child: NoScoresEnteredState()));
        }
        return ListView.separated(
          padding: EdgeInsets.zero,
          itemCount: _roster.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.rowDivider),
          itemBuilder: (context, index) => _GradeRow(student: _roster[index]),
        );
    }
  }
}

/// Real dropdown over the live [Subject] list for the section's school
/// level (fetched by [_GradesPaneState._loadSubjects]), replacing the old
/// tap-to-cycle picker — admin can jump straight to any subject instead of
/// tapping through them one at a time.
class _SubjectDropdownField extends StatelessWidget {
  const _SubjectDropdownField({
    required this.subjects,
    required this.selectedIndex,
    required this.onChanged,
  });

  final List<Subject> subjects;
  final int selectedIndex;
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
          value: selectedIndex,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted2),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
          items: [
            for (var i = 0; i < subjects.length; i++)
              DropdownMenuItem(
                value: i,
                child: Text(subjects[i].name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (index) {
            if (index != null) onChanged(index);
          },
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
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppColors.textMuted1),
        ),
      ),
    );
  }
}

class _GradeRow extends StatelessWidget {
  const _GradeRow({required this.student});

  final GradedStudent student;

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: gradeForeground(student.numericGrade)),
            ),
          ),
        ],
      ),
    );
  }
}
