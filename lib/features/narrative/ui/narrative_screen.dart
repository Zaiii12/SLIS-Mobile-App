import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/models/section_advisory.dart';
import '../../advisory/state/advisory_provider.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../attendance/ui/widgets/attendance_empty_states.dart';
import '../../grades/models/grading_period.dart';
import '../data/narrative_repository.dart';
import '../models/narrative_category.dart';
import 'narrative_roster_screen.dart';
import 'widgets/category_period_sheet.dart';

enum _CategoriesStatus { loading, loaded, error }

/// Narrative Reports tab: section list, same source as Attendance
/// ([AdvisoryProvider], teacher's own sections only). Tapping a section
/// opens a category/grading-period picker, then the rating roster.
class NarrativeScreen extends StatefulWidget {
  const NarrativeScreen({
    super.key,
    required this.narrativeRepository,
    required this.attendanceRepository,
  });

  final NarrativeRepository narrativeRepository;
  final AttendanceRepository attendanceRepository;

  @override
  State<NarrativeScreen> createState() => _NarrativeScreenState();
}

class _NarrativeScreenState extends State<NarrativeScreen> {
  _CategoriesStatus _status = _CategoriesStatus.loading;
  List<NarrativeCategory> _categories = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _status = _CategoriesStatus.loading);
    try {
      final categories = await widget.narrativeRepository.fetchCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _status = _CategoriesStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _CategoriesStatus.error);
    }
  }

  Future<void> _openSection(SectionAdvisory section) async {
    if (_status != _CategoriesStatus.loaded) return;
    final picked = await showCategoryPeriodSheet(
      context: context,
      categories: _categories,
      schoolLevel: section.schoolLevel,
    );
    if (picked == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NarrativeRosterScreen(
          narrativeRepository: widget.narrativeRepository,
          attendanceRepository: widget.attendanceRepository,
          section: section,
          category: picked.category,
          gradingPeriod: picked.gradingPeriod.toJson(),
          gradingPeriodLabel: picked.gradingPeriod.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final advisory = context.watch<AdvisoryProvider>();

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Narrative Reports',
          style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.headingDark),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([_loadCategories(), advisory.load()]);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
          children: [
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

  Widget _buildSections(AdvisoryProvider advisory) {
    switch (advisory.status) {
      case AdvisoryStatus.initial:
      case AdvisoryStatus.loading:
        return const LoadingSkeletonCard(height: 200);
      case AdvisoryStatus.error:
        return NetworkErrorState(onRetry: () => advisory.load());
      case AdvisoryStatus.loaded:
        if (advisory.hasNoSectionsAssigned) return const NoSectionsAssignedState();
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
                  showDivider: i != advisory.advisories.length - 1,
                  onTap: () => _openSection(advisory.advisories[i]),
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
                color: AppColors.infoPurpleBg,
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: const Icon(Icons.edit_note_outlined, size: 16, color: AppColors.infoPurpleIcon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                section.displayName,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.headingDark),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}
