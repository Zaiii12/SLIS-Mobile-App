import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/enrollment_repository.dart';
import '../models/pending_enrollment.dart';
import 'billing_format.dart';

/// Full breakdown of one pending enrollment application — read-only, no
/// approve/reject action (that workflow stays on the web admin portal, per
/// the original design brief). Application type + previous school are
/// resolved lazily here (not on the list) via two extra calls — see
/// EnrollmentRepository.resolveApplicationType.
class PendingEnrollmentDetailScreen extends StatefulWidget {
  const PendingEnrollmentDetailScreen({
    super.key,
    required this.enrollment,
    required this.repository,
  });

  final PendingEnrollment enrollment;
  final EnrollmentRepository repository;

  @override
  State<PendingEnrollmentDetailScreen> createState() =>
      _PendingEnrollmentDetailScreenState();
}

class _PendingEnrollmentDetailScreenState
    extends State<PendingEnrollmentDetailScreen> {
  late Future<PendingEnrollment> _resolvedFuture;

  @override
  void initState() {
    super.initState();
    _resolvedFuture = widget.repository
        .resolveApplicationType(widget.enrollment)
        .catchError((_) => widget.enrollment);
  }

  @override
  Widget build(BuildContext context) {
    final base = widget.enrollment;

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          base.studentName,
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFFDF3F2),
                ),
                child: Center(
                  child: Text(
                    base.initials,
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
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
                      base.studentName,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headingDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      base.lrn.isNotEmpty ? 'LRN ${base.lrn}' : 'New student',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        color: AppColors.textMuted3,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.neutralPillBg,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.neutralPillText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          _InfoCard(
            title: 'Application',
            child: FutureBuilder<PendingEnrollment>(
              future: _resolvedFuture,
              builder: (context, snapshot) {
                final resolved = snapshot.data;
                final loading =
                    snapshot.connectionState != ConnectionState.done;
                return Column(
                  children: [
                    _InfoRow(
                      'Application Type',
                      loading ? null : (resolved?.applicationType ?? 'Unknown'),
                    ),
                    _InfoRow(
                      'School Level',
                      formatSchoolLevel(base.schoolLevel),
                    ),
                    _InfoRow('Grade Level', base.gradeLevel),
                    _InfoRow(
                      'Section',
                      base.section.isNotEmpty ? base.section : '—',
                    ),
                    _InfoRow('School Year', base.schoolYear),
                    if (!loading && resolved?.previousSchoolName != null)
                      _InfoRow(
                        'Previous School',
                        resolved!.previousSchoolName!,
                      ),
                    if (!loading && resolved?.previousSchoolAddress != null)
                      _InfoRow(
                        'Previous School Address',
                        resolved!.previousSchoolAddress!,
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          _InfoCard(
            title: 'Student',
            child: Column(
              children: [
                _InfoRow('Full Name', base.studentName),
                _InfoRow('LRN', base.lrn.isNotEmpty ? base.lrn : '—'),
                _InfoRow('Student Number', base.studentNumber ?? '—'),
                _InfoRow(
                  'Sex',
                  base.sex.isNotEmpty ? _titleCase(base.sex) : '—',
                ),
                _InfoRow('Birth Date', formatInvoiceDate(base.birthDate)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _titleCase(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.textMuted3,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: value == null
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    value!,
                    textAlign: TextAlign.right,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.child});

  final String title;
  final Widget child;

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
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ],
      ),
    );
  }
}
