import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/models/roster_entry.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../data/narrative_repository.dart';
import '../models/narrative_category.dart';
import '../models/narrative_rating.dart';
import '../models/narrative_report.dart';

enum _LoadStatus { loading, loaded, error }

/// Roster view for one section/category/grading period: pre-populates
/// ratings from any existing `NarrativeReport` rows, then submits one
/// create-or-update call per changed student. Unlike attendance's single
/// bulk endpoint, narrative reports have no bulk-write action, so each rated
/// student is its own create/update call (existing reports are matched by
/// [NarrativeReport.reportId] via [NarrativeRepository.fetchReports], so an
/// already-rated student PATCHes instead of hitting the
/// enrollment+category+grading_period uniqueness constraint on POST).
class NarrativeRosterScreen extends StatefulWidget {
  const NarrativeRosterScreen({
    super.key,
    required this.narrativeRepository,
    required this.attendanceRepository,
    required this.section,
    required this.category,
    required this.gradingPeriod,
    required this.gradingPeriodLabel,
  });

  final NarrativeRepository narrativeRepository;
  final AttendanceRepository attendanceRepository;
  final SectionAdvisory section;
  final NarrativeCategory category;
  final String gradingPeriod;
  final String gradingPeriodLabel;

  @override
  State<NarrativeRosterScreen> createState() => _NarrativeRosterScreenState();
}

class _NarrativeRosterScreenState extends State<NarrativeRosterScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<RosterEntry> _roster = const [];
  final Map<int, NarrativeRating?> _ratings = {};
  final Map<int, int> _existingReportIds = {};
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final results = await Future.wait([
        widget.attendanceRepository.fetchRoster(widget.section),
        widget.narrativeRepository.fetchReports(
          categoryId: widget.category.id,
          gradingPeriod: widget.gradingPeriod,
        ),
      ]);
      final roster = results[0] as List<RosterEntry>;
      final reports = results[1] as List<NarrativeReport>;
      final reportByEnrollment = {for (final r in reports) r.enrollmentId: r};
      if (!mounted) return;
      setState(() {
        _roster = roster;
        _ratings
          ..clear()
          ..addAll({
            for (final entry in roster) entry.enrollmentId: reportByEnrollment[entry.enrollmentId]?.rating,
          });
        _existingReportIds
          ..clear()
          ..addAll({
            for (final entry in roster)
              if (reportByEnrollment[entry.enrollmentId] != null)
                entry.enrollmentId: reportByEnrollment[entry.enrollmentId]!.reportId,
          });
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  void _setRating(int enrollmentId, NarrativeRating rating) {
    setState(() => _ratings[enrollmentId] = rating);
  }

  int get _ratedCount => _ratings.values.where((r) => r != null).length;

  /// Sends each rated student as its own create-or-update call (see class
  /// doc comment) and tracks per-student success so a partial failure can be
  /// retried safely: a student whose call succeeded gets its
  /// [NarrativeReport.reportId] recorded in [_existingReportIds] immediately,
  /// so a retry PATCHes it instead of re-POSTing into the
  /// enrollment+category+grading_period uniqueness constraint.
  Future<void> _submit() async {
    setState(() => _submitting = true);
    var failureCount = 0;
    for (final entry in _roster) {
      final rating = _ratings[entry.enrollmentId];
      if (rating == null) continue;
      final existingId = _existingReportIds[entry.enrollmentId];
      try {
        if (existingId != null) {
          await widget.narrativeRepository.updateReport(reportId: existingId, rating: rating);
        } else {
          final created = await widget.narrativeRepository.createReport(
            enrollmentId: entry.enrollmentId,
            categoryId: widget.category.id,
            gradingPeriod: widget.gradingPeriod,
            rating: rating,
          );
          if (!mounted) return;
          setState(() => _existingReportIds[entry.enrollmentId] = created.reportId);
        }
      } catch (_) {
        failureCount++;
      }
    }
    if (!mounted) return;
    if (failureCount == 0) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _submitting = false);
    final savedCount = _ratedCount - failureCount;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$savedCount of $_ratedCount saved. Tap Submit to retry the rest.',
          style: GoogleFonts.dmSans(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.section.displayName,
              style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.headingDark),
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.category.name} · ${widget.gradingPeriodLabel}',
              style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: _status == _LoadStatus.loaded ? _buildSubmitBar() : null,
    );
  }

  Widget _buildBody() {
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
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Center(
                child: Text(
                  'No students enrolled in this section',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: _roster.length,
          separatorBuilder: (_, _) => const Divider(height: 1, color: AppColors.rowDivider),
          itemBuilder: (context, index) {
            final entry = _roster[index];
            return _NarrativeRow(
              entry: entry,
              rating: _ratings[entry.enrollmentId],
              onChanged: (rating) => _setRating(entry.enrollmentId, rating),
            );
          },
        );
    }
  }

  Widget _buildSubmitBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: ElevatedButton(
          onPressed: _submitting || _ratedCount == 0 ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)),
                )
              : Text('Submit Ratings ($_ratedCount rated)'),
        ),
      ),
    );
  }
}

class _NarrativeRow extends StatelessWidget {
  const _NarrativeRow({required this.entry, required this.rating, required this.onChanged});

  final RosterEntry entry;
  final NarrativeRating? rating;
  final ValueChanged<NarrativeRating> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFFDF3F2)),
                child: Center(
                  child: Text(
                    entry.initials,
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.studentName,
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final option in NarrativeRating.values) ...[
                Expanded(
                  child: _RatingChip(
                    label: option.label,
                    active: rating == option,
                    onTap: () => onChanged(option),
                  ),
                ),
                if (option != NarrativeRating.values.last) const SizedBox(width: 6),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? AppColors.primary : AppColors.cardBorder,
          borderRadius: BorderRadius.circular(7),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : AppColors.textMuted3,
          ),
        ),
      ),
    );
  }
}
