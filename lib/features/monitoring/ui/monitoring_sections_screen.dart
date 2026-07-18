import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/data/advisory_api.dart';
import '../../advisory/models/section_advisory.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../../grades/data/grades_repository.dart';
import '../models/teacher.dart';
import 'monitoring_section_detail_screen.dart';

enum _LoadStatus { loading, loaded, error }

/// Display label for a section's strand, if any — e.g. "Grade 11 - STEM A".
String _sectionLabel(SectionAdvisory advisory) =>
    advisory.strand == null ? advisory.displayName : '${advisory.displayName} (${advisory.strand})';

/// Lists one teacher's [SectionAdvisory] rows, fetched via the same
/// `/api/section-advisories/?teacher_user_id=` call a teacher's own app
/// makes for themselves (see `AdvisoryApi`) — this screen just supplies a
/// specific [Teacher.userId] instead of the signed-in user's own id.
class MonitoringSectionsScreen extends StatefulWidget {
  const MonitoringSectionsScreen({
    super.key,
    required this.teacher,
    required this.advisoryApi,
    required this.attendanceRepository,
    required this.gradesRepository,
  });

  final Teacher teacher;
  final AdvisoryApi advisoryApi;
  final AttendanceRepository attendanceRepository;
  final GradesRepository gradesRepository;

  @override
  State<MonitoringSectionsScreen> createState() => _MonitoringSectionsScreenState();
}

class _MonitoringSectionsScreenState extends State<MonitoringSectionsScreen> {
  _LoadStatus _status = _LoadStatus.loading;
  List<SectionAdvisory> _sections = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final sections = await widget.advisoryApi.fetchSectionAdvisories(teacherUserId: widget.teacher.userId);
      if (!mounted) return;
      setState(() {
        _sections = sections;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  void _openSection(SectionAdvisory section) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MonitoringSectionDetailScreen(
          teacher: widget.teacher,
          section: section,
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
          widget.teacher.name,
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          children: [
            Text(
              'SECTIONS',
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
        if (_sections.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Center(
              child: Text(
                'This teacher has no sections assigned',
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
              for (var i = 0; i < _sections.length; i++)
                _SectionRow(
                  section: _sections[i],
                  showDivider: i != _sections.length - 1,
                  onTap: () => _openSection(_sections[i]),
                ),
            ],
          ),
        );
    }
  }
}

class _SectionRow extends StatelessWidget {
  const _SectionRow({required this.section, required this.showDivider, required this.onTap});

  final SectionAdvisory section;
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
              decoration: BoxDecoration(
                color: AppColors.dangerBg2,
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: const Icon(Icons.groups_outlined, size: 15, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _sectionLabel(section),
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}
