import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/billing_repository.dart';
import '../data/enrollment_repository.dart';
import '../models/enrollment.dart';
import 'billing_format.dart';
import 'invoice_detail_screen.dart';

enum _LoadStatus { loading, loaded, error }

/// Two-step "quick record" flow for accounting/admin to generate an invoice
/// from mobile without needing the website: search-and-pick one *enrolled*
/// enrollment, choose a payment plan, submit. `POST /api/invoices/generate/`
/// is idempotent server-side (returns the existing invoice if one already
/// exists for that enrollment, never a duplicate — billing/services.py:319),
/// so this is safe to build without a "does this enrollment already have an
/// invoice" pre-check.
///
/// Search-only, no School Level/Grade Level/Status filters — unlike
/// `EnrollmentsListScreen` (registrar's full roster browser), this is a
/// "find one specific enrolled student fast" tool, so the filter chrome
/// would be pure overhead. Fixed to `enrollment_status=enrolled` since
/// generating an invoice for a pending/cancelled/completed enrollment
/// doesn't make sense.
class GenerateInvoiceScreen extends StatefulWidget {
  const GenerateInvoiceScreen({
    super.key,
    required this.enrollmentRepository,
    required this.billingRepository,
  });

  final EnrollmentRepository enrollmentRepository;
  final BillingRepository billingRepository;

  @override
  State<GenerateInvoiceScreen> createState() => _GenerateInvoiceScreenState();
}

class _GenerateInvoiceScreenState extends State<GenerateInvoiceScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  _LoadStatus _status = _LoadStatus.loading;
  List<Enrollment> _enrollments = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final enrollments = await widget.enrollmentRepository.fetchEnrollments(
        enrollmentStatus: 'enrolled',
        search: _searchController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _enrollments = enrollments;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _load);
  }

  Future<void> _selectEnrollment(Enrollment enrollment) async {
    final generated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _PaymentPlanScreen(
          enrollment: enrollment,
          repository: widget.billingRepository,
        ),
      ),
    );
    if (generated == true && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Generate Invoice',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: _SearchField(
              controller: _searchController,
              onChanged: _onSearchChanged,
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return _ErrorState(onRetry: _load);
      case _LoadStatus.loaded:
        if (_enrollments.isEmpty) return const _EmptyState();
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: _enrollments.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final enrollment = _enrollments[index];
            return _EnrollmentRow(
              enrollment: enrollment,
              onTap: () => _selectEnrollment(enrollment),
            );
          },
        );
    }
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.headingDark),
        decoration: InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          hintText: 'Search by name or LRN',
          hintStyle: GoogleFonts.dmSans(
            fontSize: 13,
            color: AppColors.textMuted3,
          ),
          prefixIcon: const Icon(
            Icons.search,
            size: 18,
            color: AppColors.textMuted3,
          ),
        ),
      ),
    );
  }
}

class _EnrollmentRow extends StatelessWidget {
  const _EnrollmentRow({required this.enrollment, required this.onTap});

  final Enrollment enrollment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFDF3F2),
              ),
              child: Center(
                child: Text(
                  enrollment.initials,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enrollment.studentName,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${enrollment.gradeLevel} - ${enrollment.section} · S.Y. ${enrollment.schoolYear}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 16, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}

class _PaymentPlanScreen extends StatefulWidget {
  const _PaymentPlanScreen({
    required this.enrollment,
    required this.repository,
  });

  final Enrollment enrollment;
  final BillingRepository repository;

  @override
  State<_PaymentPlanScreen> createState() => _PaymentPlanScreenState();
}

class _PaymentPlanScreenState extends State<_PaymentPlanScreen> {
  String? _paymentPlan;
  bool _saving = false;
  String? _error;

  Future<void> _submit() async {
    final paymentPlan = _paymentPlan;
    if (paymentPlan == null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final invoice = await widget.repository.generateInvoice(
        enrollmentId: widget.enrollment.enrollmentId,
        paymentPlan: paymentPlan,
      );
      if (!mounted) return;
      final result = await Navigator.of(context).pushReplacement<bool, void>(
        MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(
            invoice: invoice,
            repository: widget.repository,
          ),
        ),
      );
      if (!mounted) return;
      Navigator.of(context).pop(result ?? true);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            _extractErrorMessage(e.response?.data) ??
            "Couldn't generate the invoice. Check your connection and try again.";
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Something went wrong. Please try again.';
      });
    }
  }

  /// The backend raises plain `{"detail": "..."}` `ValueError` messages here
  /// (e.g. "No active fee schedule for X / Y") rather than DRF's field-keyed
  /// `ValidationError` shape used elsewhere — check `detail` first.
  String? _extractErrorMessage(dynamic data) {
    if (data is! Map) return null;
    final detail = data['detail'];
    if (detail is String) return detail;
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final enrollment = widget.enrollment;
    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          'Generate Invoice',
          style: GoogleFonts.dmSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            title: 'Student',
            child: Column(
              children: [
                _InfoRow('Name', enrollment.studentName),
                _InfoRow('LRN', enrollment.lrn),
                _InfoRow(
                  'Grade & Section',
                  '${enrollment.gradeLevel} - ${enrollment.section}',
                ),
                _InfoRow('School Year', enrollment.schoolYear),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          _Card(
            title: 'Payment Plan',
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: _PlanDropdown(
                value: _paymentPlan,
                onChanged: (v) => setState(() => _paymentPlan = v),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.interCardGap),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.dangerBg,
                borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
              ),
              child: Text(
                _error!,
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.dangerText,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.interCardGap),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (_saving || _paymentPlan == null) ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Generate Invoice'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanDropdown extends StatelessWidget {
  const _PlanDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String> onChanged;

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
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(
            'Select a plan',
            style: GoogleFonts.dmSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted2,
            ),
          ),
          icon: const Icon(
            Icons.expand_more,
            size: 16,
            color: AppColors.textMuted2,
          ),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.headingDark,
          ),
          items: [
            for (final plan in paymentPlans)
              DropdownMenuItem(
                value: plan,
                child: Text(formatPaymentPlan(plan)),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});

  final String title;
  final Widget child;

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.textMuted3,
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.dmSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.headingDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              'No enrolled students found',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Try a different name or LRN',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                color: AppColors.textMuted3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              "Couldn't load enrollments",
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.dmSans(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
