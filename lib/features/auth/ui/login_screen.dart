import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../state/auth_provider.dart';
import '../../advisory/data/advisory_api.dart';
import '../../attendance/data/attendance_repository.dart';
import '../../billing/data/billing_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../grades/data/grades_repository.dart';
import '../../monitoring/data/audit_log_repository.dart';
import '../../monitoring/data/teachers_repository.dart';
import '../../shell/ui/app_shell.dart';
import '../../students/data/students_repository.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _identifierFocus = FocusNode();
  final _passwordFocus = FocusNode();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _identifierFocus.addListener(() => setState(() {}));
    _passwordFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    _identifierFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      identifier: _identifierController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      final dashboardRepository = context.read<DashboardRepository>();
      final studentsRepository = context.read<StudentsRepository>();
      final attendanceRepository = context.read<AttendanceRepository>();
      final gradesRepository = context.read<GradesRepository>();
      final teachersRepository = context.read<TeachersRepository>();
      final advisoryApi = context.read<AdvisoryApi>();
      final billingRepository = context.read<BillingRepository>();
      final auditLogRepository = context.read<AuditLogRepository>();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => AppShell(
            dashboardRepository: dashboardRepository,
            studentsRepository: studentsRepository,
            attendanceRepository: attendanceRepository,
            gradesRepository: gradesRepository,
            teachersRepository: teachersRepository,
            advisoryApi: advisoryApi,
            billingRepository: billingRepository,
            auditLogRepository: auditLogRepository,
          ),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final isLoading = authProvider.status == AuthStatus.authenticating;

    return Scaffold(
      backgroundColor: AppColors.loginBg,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -40,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0x14E03131),
                        Color(0x00E03131),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 26, 28, 28),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 30,
                          height: 30,
                          child: Image.asset(
                            'assets/logo.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          width: 1.5,
                          height: 14,
                          color: AppColors.inputBorder,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'SOUTH LAKES INTEGRATED SCHOOL',
                          style: GoogleFonts.dmSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: AppColors.labelUppercase1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    Text(
                      'Sign in to continue',
                      style: GoogleFonts.dmSans(
                        fontSize: 31,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.6,
                        height: 1.15,
                        color: AppColors.headingDark2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use your school email or username.',
                      style: GoogleFonts.dmSans(
                        fontSize: 13.5,
                        color: AppColors.textMuted2,
                      ),
                    ),
                    const SizedBox(height: 38),
                    _FieldLabel('EMAIL OR USERNAME'),
                    const SizedBox(height: 9),
                    _UnderlineField(
                      controller: _identifierController,
                      focusNode: _identifierFocus,
                      keyboardType: TextInputType.emailAddress,
                      hintText: 'e.g. juan@email.com',
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 28),
                    _FieldLabel('PASSWORD'),
                    const SizedBox(height: 9),
                    _UnderlineField(
                      controller: _passwordController,
                      focusNode: _passwordFocus,
                      obscureText: _obscurePassword,
                      hintText: '••••••••',
                      suffix: GestureDetector(
                        onTap: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                        child: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 16,
                          color: AppColors.iconMuted,
                        ),
                      ),
                      validator: (value) =>
                          (value == null || value.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                    const SizedBox(height: 26),
                    if (authProvider.errorMessage != null) ...[
                      Text(
                        authProvider.errorMessage!,
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          color: AppColors.dangerText,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: GestureDetector(
                        onTap: isLoading ? null : _submit,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppColors.primary,
                                AppColors.primaryPressed,
                              ],
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x52E03131),
                                blurRadius: 18,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (isLoading) ...[
                                const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                isLoading ? 'Signing in…' : 'Sign in',
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnderlineField extends StatelessWidget {
  const _UnderlineField({
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.suffix,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final String? Function(String?) validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    final focused = focusNode.hasFocus;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.ease,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: focused ? AppColors.primary : AppColors.inputBorder,
            width: focused ? 2.5 : 1.5,
          ),
        ),
      ),
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: GoogleFonts.dmSans(
          fontSize: 15,
          color: const Color(0xFF2D1A1A),
        ),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          hintText: hintText,
          hintStyle: GoogleFonts.dmSans(
            fontSize: 15,
            color: AppColors.iconMuted,
          ),
          suffixIcon: suffix == null
              ? null
              : Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: suffix,
                ),
          suffixIconConstraints: const BoxConstraints(
            minWidth: 24,
            minHeight: 24,
          ),
        ),
        validator: validator,
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.labelUppercase1,
      ),
    );
  }
}
