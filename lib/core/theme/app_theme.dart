import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Color tokens lifted from the ASIA admin-portal design language.
class AppColors {
  AppColors._();

  static const primary = Color(0xFFE03131);
  static const primaryPressed = Color(0xFFC92A2A);

  static const canvasBg = Color(0xFFF6F1EE);
  static const dashboardBg = Color(0xFFFDF8F6);
  static const loginBg = Color(0xFFFFF8F6);

  static const cardWhite = Color(0xFFFFFFFF);
  static const cardBorder = Color(0xFFF5EAEA);
  static const loginCardBorder = Color(0xFFFDE2DE);

  static const inputBorder = Color(0xFFF0CECA);
  static const inputBg = Color(0xFFFFFBFB);

  static const headingDark = Color(0xFF1A0A0A);
  static const headingDark2 = Color(0xFF1A1A1A);
  static const textMuted1 = Color(0xFF7A5050);
  static const textMuted2 = Color(0xFFA0756E);
  static const textMuted3 = Color(0xFFB09090);
  static const textMuted4 = Color(0xFFB49190);
  static const labelUppercase1 = Color(0xFF6B4040);
  static const labelUppercase2 = Color(0xFFA07878);
  static const iconMuted = Color(0xFFCCA9A4);

  static const successBg = Color(0xFFEAF3DE);
  static const successBg2 = Color(0xFFE8F5E0);
  static const successText = Color(0xFF3B6D11);
  static const successText2 = Color(0xFF2E6B0D);
  static const successFill = Color(0xFF22C55E);

  static const warningBg = Color(0xFFFDF5E8);
  static const warningText = Color(0xFFD97706);
  static const warningText2 = Color(0xFFA16207);

  static const dangerBg = Color(0xFFFCEBEB);
  static const dangerBg2 = Color(0xFFFDE8E8);
  static const dangerText = Color(0xFFA32D2D);

  static const neutralPillBg = Color(0xFFF1EFE8);
  static const neutralPillText = Color(0xFF5F5E5A);

  static const infoBlueBg = Color(0xFFE3F0FD);
  static const infoBlueIcon = Color(0xFF1455A0);
  static const infoPurpleBg = Color(0xFFF0E8FD);
  static const infoPurpleIcon = Color(0xFF7C3AED);

  static const avatarGradientStart = Color(0xFFFDE8E8);
  static const avatarGradientEnd = Color(0xFFFCA5A5);

  static const rowDivider = Color(0xFFF9F0F0);

  static const logoBadgeBorder = Color(0xFFFFDDDD);
  static const logoBadgeShadow = Color(0x1EE03131); // rgba(224,49,49,0.12)
}

class AppSpacing {
  AppSpacing._();

  static const dashboardScreenPadding = 16.0;
  static const loginScreenPadding = 24.0;
  static const statCardPadding = 14.0;
  static const loginCardPadding = 22.0;
  static const interCardGap = 14.0;
  static const statGridGap = 10.0;
}

class AppRadii {
  AppRadii._();

  static const pill = 50.0;
  static const dashboardCard = 14.0;
  static const loginCard = 20.0;
  static const input = 10.0;
  static const iconChipSmall = 7.0;
  static const iconChipLarge = 9.0;
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.cardWhite,
      ),
      scaffoldBackgroundColor: AppColors.canvasBg,
      fontFamily: GoogleFonts.dmSans().fontFamily,
    );

    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.cardWhite,
        foregroundColor: AppColors.headingDark,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          padding: const EdgeInsets.symmetric(vertical: 13),
          textStyle: GoogleFonts.dmSans(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
