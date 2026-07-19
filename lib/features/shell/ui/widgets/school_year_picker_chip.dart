import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../settings/state/school_year_provider.dart';

/// Pill button showing the global school year (see [SchoolYearProvider]),
/// tapping opens a bottom sheet to switch it — same pill + bottom-sheet
/// idiom as the event-type filter in `calendar_screen.dart` and the payment
/// method filter in `financial_stats_screen.dart`. Embedded in the AppBar of
/// every year-scoped screen (Dashboard, Financial Stats, Calendar) so a
/// change here is immediately visible and shared across all of them.
class SchoolYearPickerChip extends StatelessWidget {
  const SchoolYearPickerChip({super.key});

  Future<void> _showPicker(BuildContext context, SchoolYearProvider provider) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.cardWhite,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'School Year',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.headingDark,
                ),
              ),
            ),
            for (final year in provider.options)
              ListTile(
                dense: true,
                title: Text(year, style: GoogleFonts.dmSans(fontSize: 13)),
                trailing: year == provider.schoolYear
                    ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(year),
              ),
          ],
        ),
      ),
    );
    if (picked != null) provider.setSchoolYear(picked);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SchoolYearProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: () => _showPicker(context, provider),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.neutralPillBg,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                provider.schoolYear,
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted1,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down,
                size: 16,
                color: AppColors.textMuted1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
