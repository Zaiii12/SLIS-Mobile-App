import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart' show SchoolLevelLabel;
import '../data/grades_repository.dart';
import '../models/grade_overview_row.dart';
import '../models/graded_student.dart';
import '../models/grading_period.dart';
import '../models/subject.dart';
import 'grade_colors.dart';

enum _LoadStatus { loading, loaded, error }

/// Remark bands mirroring ASIA web's `SummaryTable` legend (`GradesPage.jsx`)
/// — DepEd's standard descriptor scale, distinct from [gradeBackground]'s
/// simpler pass/fail-oriented 3-tier badge used on the Overview roster.
class _RemarkBand {
  const _RemarkBand(this.label, this.min, this.color, this.bg);

  final String label;
  final double min;
  final Color color;
  final Color bg;
}

const _remarkBands = [
  _RemarkBand('Outstanding', 90, AppColors.infoBlueIcon, AppColors.infoBlueBg),
  _RemarkBand('Very Satisfactory', 85, Color(0xFF2E6B0D), Color(0xFFE8F5E0)),
  _RemarkBand('Satisfactory', 80, Color(0xFF2E6B0D), Color(0xFFEAF3DE)),
  _RemarkBand('Fairly Satisfactory', 75, Color(0xFF854F0B), Color(0xFFFAEEDA)),
  _RemarkBand('Failed', 0, AppColors.dangerText, AppColors.dangerBg2),
];

_RemarkBand _remarkFor(double grade) {
  for (final band in _remarkBands) {
    if (grade >= band.min) return band;
  }
  return _remarkBands.last;
}

/// Read-only per-student grade summary: subjects × grading periods matrix
/// with per-subject average, per-period average, and an overall General
/// Average with a DepEd-style remark — mirrors ASIA web's `SummaryTable`
/// (`GradesPage.jsx`). No edit affordance anywhere (registrar/this screen
/// never has write access to grades).
class GradeSummaryScreen extends StatefulWidget {
  const GradeSummaryScreen({super.key, required this.row});

  final GradeOverviewRow row;

  @override
  State<GradeSummaryScreen> createState() => _GradeSummaryScreenState();
}

class _GradeSummaryScreenState extends State<GradeSummaryScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<Subject> _subjects = const [];
  List<Grade> _grades = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final repository = context.read<GradesRepository>();
      final results = await Future.wait([
        repository.fetchSubjects(
          schoolLevel: widget.row.schoolLevel,
          gradeLevel: widget.row.gradeLevel,
          strand: widget.row.strand,
        ),
        repository.fetchGradesForEnrollment(widget.row.enrollmentId),
      ]);
      if (!mounted) return;
      setState(() {
        _subjects = results[0] as List<Subject>;
        _grades = results[1] as List<Grade>;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Grade Summary',
          style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.wifi_off, size: 28, color: Color(0xFFD8B8B4)),
                const SizedBox(height: 8),
                Text(
                  "Couldn't load grade summary",
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _load,
                  child: Text('Retry', style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
          ),
        );
      case _LoadStatus.loaded:
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 30),
          children: [
            _HeaderCard(row: widget.row, grades: _grades),
            const SizedBox(height: AppSpacing.interCardGap),
            _MatrixCard(row: widget.row, subjects: _subjects, grades: _grades),
            const SizedBox(height: AppSpacing.interCardGap),
            const _Legend(),
          ],
        );
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.row, required this.grades});

  final GradeOverviewRow row;
  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    final numeric = grades.map((g) => g.numericGrade).whereType<double>().toList();
    final overallAvg = numeric.isEmpty ? null : numeric.reduce((a, b) => a + b) / numeric.length;
    final band = overallAvg == null ? null : _remarkFor(overallAvg);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.studentName,
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.headingDark),
          ),
          const SizedBox(height: 3),
          Text(
            'LRN ${row.lrn} · ${row.gradeLevel} - ${row.section}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3),
          ),
          Text(
            'S.Y. ${row.schoolYear} · ${row.schoolLevel.label}${row.strand != null ? ' · ${row.strand}' : ''}',
            style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3),
          ),
          if (overallAvg != null) ...[
            const SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    'GENERAL AVERAGE',
                    style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textMuted3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: band!.bg,
                      borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
                    ),
                    child: Text(
                      overallAvg.toStringAsFixed(2),
                      style: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.w700, color: band.color),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    band.label,
                    style: GoogleFonts.dmSans(fontSize: 11.5, fontWeight: FontWeight.w700, color: band.color),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MatrixCard extends StatelessWidget {
  const _MatrixCard({required this.row, required this.subjects, required this.grades});

  final GradeOverviewRow row;
  final List<Subject> subjects;
  final List<Grade> grades;

  @override
  Widget build(BuildContext context) {
    final periods = periodsForSchoolLevel(row.schoolLevel);

    final gradeMap = <int, Map<String, double?>>{};
    for (final g in grades) {
      gradeMap.putIfAbsent(g.subjectId, () => {})[g.gradingPeriod] = g.numericGrade;
    }

    double? periodAverage(String period) {
      final values = subjects
          .map((s) => gradeMap[s.id]?[period])
          .whereType<double>()
          .toList();
      if (values.isEmpty) return null;
      return values.reduce((a, b) => a + b) / values.length;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: subjects.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No subjects found for this grade level.',
                  style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.textMuted3),
                ),
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.all(16),
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 44,
                dataRowMaxHeight: 52,
                columnSpacing: 20,
                headingTextStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted3),
                columns: [
                  const DataColumn(label: Text('Subject')),
                  for (final p in periods) DataColumn(label: Text(p.label), numeric: true),
                  const DataColumn(label: Text('Avg'), numeric: true),
                ],
                rows: [
                  for (final subject in subjects)
                    DataRow(
                      cells: [
                        DataCell(
                          Text(
                            subject.name,
                            style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                          ),
                        ),
                        for (final p in periods)
                          DataCell(_GradeCell(grade: gradeMap[subject.id]?[p.toJson()])),
                        DataCell(_SubjectAverageCell(
                          grades: periods.map((p) => gradeMap[subject.id]?[p.toJson()]).toList(),
                        )),
                      ],
                    ),
                  DataRow(
                    color: WidgetStateProperty.all(AppColors.dashboardBg),
                    cells: [
                      DataCell(
                        Text(
                          'Period Average',
                          style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                        ),
                      ),
                      for (final p in periods) DataCell(_GradeCell(grade: periodAverage(p.toJson()), bold: true)),
                      const DataCell(SizedBox.shrink()),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}

class _GradeCell extends StatelessWidget {
  const _GradeCell({required this.grade, this.bold = false});

  final double? grade;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    if (grade == null) {
      return Text('—', style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.textMuted3));
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: gradeBackground(grade),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        grade!.toStringAsFixed(2),
        style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          color: gradeForeground(grade),
        ),
      ),
    );
  }
}

class _SubjectAverageCell extends StatelessWidget {
  const _SubjectAverageCell({required this.grades});

  final List<double?> grades;

  @override
  Widget build(BuildContext context) {
    final values = grades.whereType<double>().toList();
    final avg = values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
    return _GradeCell(grade: avg, bold: true);
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: Wrap(
        spacing: 10,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            'Legend:',
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textMuted3),
          ),
          for (final band in _remarkBands)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(color: band.bg, borderRadius: BorderRadius.circular(AppRadii.pill)),
              child: Text(
                band.label,
                style: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700, color: band.color),
              ),
            ),
        ],
      ),
    );
  }
}
