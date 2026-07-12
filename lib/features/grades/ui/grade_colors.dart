import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Grade badge colors per the design's grade-color table. [grade] is null
/// for "ungraded" (no score entries / not yet computed).
Color gradeBackground(double? grade) {
  if (grade == null) return const Color(0xFFF9F4F4);
  if (grade >= 90) return AppColors.infoBlueBg;
  if (grade >= 75) return AppColors.successBg2;
  if (grade > 0) return AppColors.dangerBg2;
  return const Color(0xFFF9F4F4);
}

Color gradeForeground(double? grade) {
  if (grade == null) return AppColors.textMuted1;
  if (grade >= 90) return AppColors.infoBlueIcon;
  if (grade >= 75) return AppColors.successText2;
  if (grade > 0) return AppColors.dangerText;
  return AppColors.textMuted1;
}
