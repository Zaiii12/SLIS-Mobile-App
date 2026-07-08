import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../state/auth_provider.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../dashboard/ui/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
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
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => DashboardScreen(repository: dashboardRepository),
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
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.loginScreenPadding,
              vertical: 44,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LogoBadge(),
                const SizedBox(height: 18),
                Text(
                  'Good to see you again',
                  style: GoogleFonts.dmSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w400,
                    color: AppColors.headingDark2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'South Lakes Integrated School',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: AppColors.textMuted2,
                  ),
                ),
                const SizedBox(height: 26),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.loginCardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.cardWhite,
                      borderRadius: BorderRadius.circular(AppRadii.loginCard),
                      border: Border.all(color: AppColors.loginCardBorder),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _FieldLabel('EMAIL OR NAME'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _identifierController,
                            keyboardType: TextInputType.emailAddress,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: const Color(0xFF2D1A1A),
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. juan@email.com',
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.iconMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.person_outline,
                                size: 18,
                                color: AppColors.iconMuted,
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            validator: (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          _FieldLabel('PASSWORD'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            style: GoogleFonts.dmSans(
                              fontSize: 14,
                              color: const Color(0xFF2D1A1A),
                            ),
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              hintStyle: GoogleFonts.dmSans(
                                fontSize: 14,
                                color: AppColors.iconMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: AppColors.iconMuted,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                  color: AppColors.iconMuted,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              contentPadding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            validator: (value) =>
                                (value == null || value.isEmpty) ? 'Required' : null,
                          ),
                          const SizedBox(height: 18),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Forgot password?',
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 18),
                          if (authProvider.errorMessage != null) ...[
                            Text(
                              authProvider.errorMessage!,
                              style: GoogleFonts.dmSans(
                                fontSize: 12.5,
                                color: AppColors.dangerText,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                          ],
                          ElevatedButton(
                            onPressed: isLoading ? null : _submit,
                            child: isLoading
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation(Colors.white),
                                    ),
                                  )
                                : const Text('Sign in'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: AppColors.textMuted4,
                    ),
                    children: [
                      const TextSpan(text: 'Need help? '),
                      TextSpan(
                        text: 'Contact your administrator',
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: AppColors.logoBadgeBorder, width: 2),
        boxShadow: const [
          BoxShadow(
            color: AppColors.logoBadgeShadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Image.asset('assets/logo.png', fit: BoxFit.contain),
        ),
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
