import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

/// Placeholder destination for bottom-nav tabs that haven't been designed
/// yet (Students, Attendance, Forms, More).
class StubScreen extends StatelessWidget {
  const StubScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          'Coming soon',
          style: GoogleFonts.dmSans(fontSize: 14, color: AppColors.textMuted3),
        ),
      ),
    );
  }
}
