import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../advisory/models/section_advisory.dart';
import '../../../grades/models/grading_period.dart';
import '../../models/narrative_category.dart';

/// Bottom sheet to pick a category + grading period before opening the
/// roster. Grading period options come from [periodsForSchoolLevel], the
/// same helper Grades entry uses, so quarters/semesters match the section's
/// school level.
class CategoryPeriodResult {
  const CategoryPeriodResult({required this.category, required this.gradingPeriod});

  final NarrativeCategory category;
  final GradingPeriod gradingPeriod;
}

Future<CategoryPeriodResult?> showCategoryPeriodSheet({
  required BuildContext context,
  required List<NarrativeCategory> categories,
  required SchoolLevel schoolLevel,
}) {
  return showModalBottomSheet<CategoryPeriodResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CategoryPeriodSheet(categories: categories, schoolLevel: schoolLevel),
  );
}

class _CategoryPeriodSheet extends StatefulWidget {
  const _CategoryPeriodSheet({required this.categories, required this.schoolLevel});

  final List<NarrativeCategory> categories;
  final SchoolLevel schoolLevel;

  @override
  State<_CategoryPeriodSheet> createState() => _CategoryPeriodSheetState();
}

class _CategoryPeriodSheetState extends State<_CategoryPeriodSheet> {
  NarrativeCategory? _category;
  GradingPeriod? _period;

  @override
  void initState() {
    super.initState();
    if (widget.categories.isNotEmpty) _category = widget.categories.first;
    final periods = periodsForSchoolLevel(widget.schoolLevel);
    if (periods.isNotEmpty) _period = periods.first;
  }

  @override
  Widget build(BuildContext context) {
    final periods = periodsForSchoolLevel(widget.schoolLevel);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          decoration: const BoxDecoration(
            color: AppColors.cardWhite,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Rate a Category',
                    style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.headingDark),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted3),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (widget.categories.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No narrative categories have been set up yet. Ask an admin or registrar to add one.',
                    style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.textMuted3),
                  ),
                )
              else ...[
                Text('Category', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3)),
                const SizedBox(height: 6),
                _Dropdown<NarrativeCategory>(
                  value: _category,
                  items: widget.categories,
                  labelOf: (c) => c.name,
                  onChanged: (v) => setState(() => _category = v),
                ),
                const SizedBox(height: 14),
                Text('Grading Period', style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3)),
                const SizedBox(height: 6),
                _Dropdown<GradingPeriod>(
                  value: _period,
                  items: periods,
                  labelOf: (p) => p.label,
                  onChanged: (v) => setState(() => _period = v),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _category == null || _period == null
                        ? null
                        : () => Navigator.of(context).pop(
                              CategoryPeriodResult(category: _category!, gradingPeriod: _period!),
                            ),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({required this.value, required this.items, required this.labelOf, required this.onChanged});

  final T? value;
  final List<T> items;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;

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
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted2),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.headingDark),
          items: [for (final item in items) DropdownMenuItem(value: item, child: Text(labelOf(item)))],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}
