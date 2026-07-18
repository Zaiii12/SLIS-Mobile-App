import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../advisory/data/advisory_api.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../billing/data/billing_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../grades/data/grades_repository.dart';
import '../../monitoring/data/audit_log_repository.dart';
import '../../monitoring/data/teachers_repository.dart';
import '../../shell/ui/app_shell.dart';
import '../../students/data/students_repository.dart';
import '../state/auth_provider.dart';
import 'login_screen.dart';

/// Checks for a restorable session on launch, then routes to Dashboard or
/// Login. Shown only for the brief duration of that check.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveSession());
  }

  Future<void> _resolveSession() async {
    final authProvider = context.read<AuthProvider>();
    await authProvider.tryRestoreSession();
    if (!mounted) return;

    final destination = authProvider.status == AuthStatus.authenticated
        ? AppShell(
            dashboardRepository: context.read<DashboardRepository>(),
            studentsRepository: context.read<StudentsRepository>(),
            attendanceRepository: context.read<AttendanceRepository>(),
            gradesRepository: context.read<GradesRepository>(),
            teachersRepository: context.read<TeachersRepository>(),
            advisoryApi: context.read<AdvisoryApi>(),
            billingRepository: context.read<BillingRepository>(),
            auditLogRepository: context.read<AuditLogRepository>(),
          )
        : const LoginScreen();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => destination),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.canvasBg,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
