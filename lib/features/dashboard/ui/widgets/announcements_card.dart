import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../models/dashboard_data.dart';

class AnnouncementsCard extends StatelessWidget {
  const AnnouncementsCard({super.key, required this.announcements});

  final List<Announcement> announcements;

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Announcements & Forms',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
                // "View all" is a stub per the design handoff — no detail
                // view has been designed yet.
                InkWell(
                  onTap: () {},
                  child: Text(
                    'View all',
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < announcements.length; i++)
            _AnnouncementRow(
              announcement: announcements[i],
              showDivider: i != announcements.length - 1,
            ),
        ],
      ),
    );
  }
}

class _AnnouncementRow extends StatelessWidget {
  const _AnnouncementRow({
    required this.announcement,
    required this.showDivider,
  });

  final Announcement announcement;
  final bool showDivider;

  ({IconData icon, Color background, Color iconColor}) get _visual {
    switch (announcement.category) {
      case AnnouncementCategory.enrollment:
        return (
          icon: Icons.school_outlined,
          background: AppColors.infoBlueBg,
          iconColor: AppColors.infoBlueIcon,
        );
      case AnnouncementCategory.form:
        return (
          icon: Icons.description_outlined,
          background: AppColors.infoPurpleBg,
          iconColor: AppColors.infoPurpleIcon,
        );
      case AnnouncementCategory.deadline:
        return (
          icon: Icons.calendar_today_outlined,
          background: AppColors.warningBg,
          iconColor: AppColors.warningText,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final visual = _visual;
    return InkWell(
      // Rows are tappable stubs — no detail view designed yet per the handoff.
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          border: showDivider
              ? const Border(bottom: BorderSide(color: AppColors.rowDivider))
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: visual.background,
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: Icon(visual.icon, size: 14, color: visual.iconColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    announcement.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    announcement.relativeTime,
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted3,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 13, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}
