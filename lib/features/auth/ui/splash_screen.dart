import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/ui/dashboard_screen.dart';
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
        ? DashboardScreen(repository: context.read<DashboardRepository>())
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
