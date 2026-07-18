import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

class AttentionItem {
  const AttentionItem({
    required this.icon,
    required this.title,
    required this.count,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;

  /// Null renders the row as an inert badge (no chevron affordance implied
  /// otherwise — currently every caller supplies one, but this keeps the
  /// widget safe if a future item has nowhere to navigate yet).
  final VoidCallback? onTap;
}

/// Admin/super_admin/registrar card surfacing action items with badge
/// counts (e.g. unpaid invoices, pending enrollment approvals), sourced from
/// live billing-service/enrollment-service endpoints via [DashboardData].
/// Registrar's item list excludes billing-related items (e.g. unpaid
/// invoices) since registrar isn't a BILLING_ROLES member on the backend.
class NeedsAttentionCard extends StatelessWidget {
  const NeedsAttentionCard({super.key, required this.items});

  final List<AttentionItem> items;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 4),
            child: Row(
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Needs Attention',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
              ],
            ),
          ),
          for (final item in items) _AttentionRow(item: item),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item});

  final AttentionItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.rowDivider)),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(AppRadii.iconChipLarge),
              ),
              child: Icon(item.icon, size: 14, color: AppColors.primary),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Tap to review',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted3,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
              child: Text(
                '${item.count}',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dangerText,
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
