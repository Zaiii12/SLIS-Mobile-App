import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../advisory/state/advisory_provider.dart';
import '../../dashboard/models/dashboard_data.dart';
import '../data/attendance_repository.dart';
import 'attendance_roster_screen.dart';
import 'widgets/attendance_empty_states.dart';

enum _SummaryStatus { loading, loaded, error }

/// Attendance tab: section list with today's summary + per-section Marked
/// badges. Tapping a section opens [AttendanceRosterScreen]. Teacher sees
/// own advisory sections only (via [AdvisoryProvider], scoped at fetch
/// time); staff sees all sections school-wide — same screen either way.
class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key, required this.repository});

  final AttendanceRepository repository;

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _today = DateTime.now();
  _SummaryStatus _status = _SummaryStatus.loading;
  AttendanceBreakdown? _summary;

  /// Section ids marked today, tracked client-side so the badge updates
  /// immediately after a successful submit without re-fetching everything.
  final Set<int> _markedSectionIds = {};

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    setState(() => _status = _SummaryStatus.loading);
    try {
      final summary = await widget.repository.fetchSummary(_today);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _status = _SummaryStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _SummaryStatus.error);
    }
  }

  Future<void> _openSection(SectionAdvisory section) async {
    final marked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AttendanceRosterScreen(
          repository: widget.repository,
          section: section,
          date: _today,
        ),
      ),
    );
    if (marked == true) {
      setState(() => _markedSectionIds.add(section.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final advisory = context.watch<AdvisoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Attendance',
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadSummary,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          children: [
            _buildSummaryCard(),
            const SizedBox(height: AppSpacing.interCardGap),
            Text(
              'SECTIONS',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: AppColors.labelUppercase2,
              ),
            ),
            const SizedBox(height: 8),
            _buildSections(advisory),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard() {
    if (_status == _SummaryStatus.error) {
      return NetworkErrorState(onRetry: _loadSummary);
    }
    if (_status == _SummaryStatus.loading || _summary == null) {
      return const LoadingSkeletonCard(height: 140);
    }
    final summary = _summary!;
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
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Today's Summary",
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
                Text(
                  DateFormat('MMMM d').format(_today),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    color: AppColors.textMuted3,
                  ),
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
                    Text(
                      'Attendance rate',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        color: AppColors.textMuted3,
                      ),
                    ),
                    Text(
                      '${summary.ratePercent}%',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successText,
                      ),
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
                    valueColor: const AlwaysStoppedAnimation(
                      AppColors.successFill,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSections(AdvisoryProvider advisory) {
    switch (advisory.status) {
      case AdvisoryStatus.initial:
      case AdvisoryStatus.loading:
        return const LoadingSkeletonCard(height: 200);
      case AdvisoryStatus.error:
        return NetworkErrorState(onRetry: () => advisory.load());
      case AdvisoryStatus.loaded:
        if (advisory.hasNoSectionsAssigned)
          return const NoSectionsAssignedState();
        return Container(
          decoration: BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
            border: Border.all(color: AppColors.cardBorder),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (var i = 0; i < advisory.advisories.length; i++)
                _SectionRow(
                  section: advisory.advisories[i],
                  marked: _markedSectionIds.contains(advisory.advisories[i].id),
                  showDivider: i != advisory.advisories.length - 1,
                  onTap: () => _openSection(advisory.advisories[i]),
                ),
            ],
          ),
        );
    }
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
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.dmSans(fontSize: 10, color: labelColor),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({
    required this.section,
    required this.marked,
    required this.showDivider,
    required this.onTap,
  });

  final SectionAdvisory section;
  final bool marked;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.rowDivider))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppColors.dangerBg2,
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: const Icon(
                Icons.groups_outlined,
                size: 15,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section.displayName,
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.headingDark,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                color: marked ? AppColors.successBg : AppColors.warningBg,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                marked ? 'Marked' : 'Not marked',
                style: GoogleFonts.dmSans(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: marked ? AppColors.successText : AppColors.warningText,
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
