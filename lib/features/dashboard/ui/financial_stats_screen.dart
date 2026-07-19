import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/data/enrollment_repository.dart';
import '../../billing/models/invoice.dart';
import '../../billing/ui/billing_format.dart';
import '../../billing/ui/generate_invoice_screen.dart';
import '../../billing/ui/pick_unpaid_invoice_sheet.dart';
import '../../billing/ui/record_payment_sheet.dart';
import '../../settings/state/school_year_provider.dart';
import '../../shell/ui/widgets/school_year_picker_chip.dart';
import 'widgets/financial_snapshot_card.dart';

enum _LoadStatus { loading, loaded, error }

const _paymentMethodOptions = {
  '': 'All methods',
  'cash': 'Cash',
  'bank_transfer': 'Bank Transfer',
  'gcash': 'GCash',
  'card': 'Card',
  'check': 'Check',
  'others': 'Others',
};

/// `BILLING_ROLES` (`super_admin`/`admin`/`accounting`) financial stats
/// quickview: aggregate summary (`GET /api/invoices/financial-summary/`)
/// plus the real payments feed (`GET /api/payments/`, `StudentPaymentViewSet`,
/// `billing/views.py:470`). Also the entry point for Generate Invoice — a
/// real write action (`POST /api/invoices/generate/`), since a role using
/// this screen may not have website access at all.
class FinancialStatsScreen extends StatefulWidget {
  const FinancialStatsScreen({
    super.key,
    required this.repository,
    required this.enrollmentRepository,
  });

  final BillingRepository repository;
  final EnrollmentRepository enrollmentRepository;

  @override
  State<FinancialStatsScreen> createState() => _FinancialStatsScreenState();
}

class _FinancialStatsScreenState extends State<FinancialStatsScreen> {
  final _scrollController = ScrollController();

  _LoadStatus _summaryStatus = _LoadStatus.loading;
  FinancialSummary? _summary;

  _LoadStatus _paymentsStatus = _LoadStatus.loading;
  List<PaymentRecord> _payments = const [];
  String _paymentMethod = '';
  int _page = 1;
  bool _hasMore = false;
  bool _loadingMore = false;

  String? _fetchedForYear;

  @override
  void initState() {
    super.initState();
    _fetchedForYear = context.read<SchoolYearProvider>().schoolYear;
    _loadSummary();
    _loadPayments();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_paymentsStatus != _LoadStatus.loaded || !_hasMore || _loadingMore) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMorePayments();
    }
  }

  Future<void> _loadSummary() async {
    setState(() => _summaryStatus = _LoadStatus.loading);
    try {
      final summary = await widget.repository.fetchFinancialSummary(
        schoolYear: context.read<SchoolYearProvider>().schoolYear,
      );
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _summaryStatus = _LoadStatus.loaded;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint(
        'BillingRepository.fetchFinancialSummary failed: $error\n$stackTrace',
      );
      setState(() => _summaryStatus = _LoadStatus.error);
    }
  }

  Future<void> _loadPayments() async {
    setState(() => _paymentsStatus = _LoadStatus.loading);
    try {
      final result = await widget.repository.fetchPayments(
        paymentMethod: _paymentMethod,
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _payments = result.payments;
        _page = 1;
        _hasMore = result.hasMore;
        _paymentsStatus = _LoadStatus.loaded;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      debugPrint('BillingRepository.fetchPayments failed: $error\n$stackTrace');
      setState(() => _paymentsStatus = _LoadStatus.error);
    }
  }

  Future<void> _loadMorePayments() async {
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = await widget.repository.fetchPayments(
        paymentMethod: _paymentMethod,
        page: nextPage,
      );
      if (!mounted) return;
      setState(() {
        _payments = [..._payments, ...result.payments];
        _page = nextPage;
        _hasMore = result.hasMore;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _refresh() async {
    await Future.wait([_loadSummary(), _loadPayments()]);
  }

  void _onMethodChanged(String method) {
    setState(() => _paymentMethod = method);
    _loadPayments();
  }

  Future<void> _editPayment(PaymentRecord payment) async {
    final updated = await showModalBottomSheet<PaymentRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _EditPaymentSheet(payment: payment, repository: widget.repository),
    );
    if (updated == null || !mounted) return;
    setState(() {
      _payments = [
        for (final p in _payments)
          if (p.paymentId == updated.paymentId) updated else p,
      ];
    });
  }

  Future<void> _openGenerateInvoice() async {
    final generated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GenerateInvoiceScreen(
          enrollmentRepository: widget.enrollmentRepository,
          billingRepository: widget.repository,
        ),
      ),
    );
    if (generated == true) _refresh();
  }

  /// Quick action: pick an unpaid invoice, then record a payment against it,
  /// without leaving this screen. Chains two sheets since this screen only
  /// has the payments feed loaded (no balances) — see
  /// `PickUnpaidInvoiceSheet`'s doc comment for why a picker is needed first.
  Future<void> _openRecordPayment() async {
    final invoice = await showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PickUnpaidInvoiceSheet(repository: widget.repository),
    );
    if (invoice == null || !mounted) return;
    final updated = await showModalBottomSheet<Invoice>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          RecordPaymentSheet(invoice: invoice, repository: widget.repository),
    );
    if (updated == null || !mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final schoolYear = context.watch<SchoolYearProvider>().schoolYear;
    if (schoolYear != _fetchedForYear) {
      _fetchedForYear = schoolYear;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _loadSummary();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Financial Stats',
          style: GoogleFonts.dmSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
        ),
        actions: [
          const Center(child: SchoolYearPickerChip()),
          IconButton(
            icon: const Icon(
              Icons.refresh,
              size: 20,
              color: AppColors.textMuted3,
            ),
            onPressed: _refresh,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.dashboardScreenPadding,
                AppSpacing.dashboardScreenPadding,
                AppSpacing.dashboardScreenPadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: _QuickActionOption(
                        icon: Icons.payments_outlined,
                        label: 'Record Payment',
                        onTap: _openRecordPayment,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.statGridGap),
                    Expanded(
                      child: _QuickActionOption(
                        icon: Icons.add_circle_outline,
                        label: 'Generate Invoice',
                        onTap: _openGenerateInvoice,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
              sliver: SliverToBoxAdapter(child: _buildSummary()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.dashboardScreenPadding,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Payments',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.headingDark,
                      ),
                    ),
                    _MethodFilterChip(
                      value: _paymentMethod,
                      onChanged: _onMethodChanged,
                    ),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 8)),
            _buildPaymentsSliver(),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    switch (_summaryStatus) {
      case _LoadStatus.loading:
        return const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        );
      case _LoadStatus.error:
        return _ErrorState(
          onRetry: _loadSummary,
          message: "Couldn't load financial stats",
        );
      case _LoadStatus.loaded:
        final summary = _summary!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FinancialSnapshotCard(
              collectedPercent: summary.collectedPercent,
              collectedAmount: formatPeso(summary.totalCollected),
              outstandingAmount: formatPeso(summary.outstanding),
            ),
            const SizedBox(height: AppSpacing.interCardGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Gross Billed',
                    value: formatPeso(summary.grossBilled),
                  ),
                ),
                const SizedBox(width: AppSpacing.statGridGap),
                Expanded(
                  child: _StatTile(
                    label: 'Net Billed',
                    value: formatPeso(summary.netBilled),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.statGridGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _StatTile(
                    label: 'Total Discounts',
                    value: formatPeso(summary.totalDiscounts),
                  ),
                ),
                const SizedBox(width: AppSpacing.statGridGap),
                Expanded(
                  child: _StatTile(
                    label: 'Invoice Count',
                    value: '${summary.invoiceCount}',
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildPaymentsSliver() {
    switch (_paymentsStatus) {
      case _LoadStatus.loading:
        return const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator()),
          ),
        );
      case _LoadStatus.error:
        return SliverToBoxAdapter(
          child: _ErrorState(
            onRetry: _loadPayments,
            message: "Couldn't load payments",
          ),
        );
      case _LoadStatus.loaded:
        if (_payments.isEmpty) {
          return const SliverToBoxAdapter(child: _EmptyPaymentsState());
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.dashboardScreenPadding,
          ),
          sliver: SliverList.separated(
            itemCount: _payments.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= _payments.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              }
              return _PaymentRow(
                payment: _payments[index],
                onTap: () => _editPayment(_payments[index]),
              );
            },
          ),
        );
    }
  }
}

class _MethodFilterChip extends StatelessWidget {
  const _MethodFilterChip({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.pill),
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          builder: (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in _paymentMethodOptions.entries)
                  ListTile(
                    dense: true,
                    title: Text(
                      entry.value,
                      style: GoogleFonts.dmSans(fontSize: 13),
                    ),
                    trailing: entry.key == value
                        ? const Icon(
                            Icons.check,
                            size: 18,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(entry.key),
                  ),
              ],
            ),
          ),
        );
        if (picked != null) onChanged(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: value.isEmpty ? AppColors.neutralPillBg : AppColors.primary,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: value.isEmpty
              ? Border.all(color: AppColors.cardBorder)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _paymentMethodOptions[value] ?? 'All methods',
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: value.isEmpty ? AppColors.textMuted1 : Colors.white,
              ),
            ),
            Icon(
              Icons.arrow_drop_down,
              size: 15,
              color: value.isEmpty ? AppColors.textMuted1 : Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment, required this.onTap});

  final PaymentRecord payment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(payment.paymentDate);
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
              width: 34,
              height: 34,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFDF3F2),
              ),
              child: const Center(
                child: Icon(
                  Icons.payments_outlined,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.studentName,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${payment.invoiceNo} · ${formatPaymentMethod(payment.paymentMethod)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      color: AppColors.textMuted3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatPeso(payment.amountPaid),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  date != null ? DateFormat('MMM d, yyyy').format(date) : '—',
                  style: GoogleFonts.dmSans(
                    fontSize: 10.5,
                    color: AppColors.textMuted3,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}

/// Selectable option card for a top-level financial quick action (Record
/// Payment / Generate Invoice) — moved out of the app bar so both actions are
/// visible side by side without needing to discover an icon-only button.
class _QuickActionOption extends StatelessWidget {
  const _QuickActionOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.statCardPadding),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
              color: AppColors.labelUppercase2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.headingDark,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPaymentsState extends StatelessWidget {
  const _EmptyPaymentsState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.payments_outlined,
              size: 28,
              color: Color(0xFFD8B8B4),
            ),
            const SizedBox(height: 8),
            Text(
              'No payments found',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textMuted1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry, required this.message});

  final VoidCallback onRetry;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              message,
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

/// Cosmetic-only edit sheet for one already-recorded payment — [amountPaid]
/// and [paymentDate] are deliberately not editable here (see
/// `BillingApi.updatePayment`'s doc comment for why: this endpoint doesn't
/// re-run `apply_payment()`, so changing the amount would desync the
/// invoice's status/installments from the payment history). This is for
/// correcting how a payment was recorded — e.g. the wrong method was picked,
/// or a reference number/note needs fixing after the fact — not changing
/// what was actually paid.
class _EditPaymentSheet extends StatefulWidget {
  const _EditPaymentSheet({required this.payment, required this.repository});

  final PaymentRecord payment;
  final BillingRepository repository;

  @override
  State<_EditPaymentSheet> createState() => _EditPaymentSheetState();
}

class _EditPaymentSheetState extends State<_EditPaymentSheet> {
  late String _paymentMethod = widget.payment.paymentMethod;
  late final _referenceController = TextEditingController(
    text: widget.payment.referenceNumber ?? '',
  );
  late final _notesController = TextEditingController(
    text: widget.payment.notes ?? '',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.updatePayment(
        paymentId: widget.payment.paymentId,
        paymentMethod: _paymentMethod,
        referenceNumber: _referenceController.text.trim(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error =
            _extractErrorMessage(e.response?.data) ??
            "Couldn't save changes. Check your connection and try again.";
      });
    }
  }

  String? _extractErrorMessage(dynamic data) {
    if (data is! Map) return null;
    for (final value in data.values) {
      if (value is List && value.isNotEmpty) return value.first.toString();
      if (value is String) return value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
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
                    'Edit Payment',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.headingDark,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 18,
                      color: AppColors.textMuted3,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.payment.invoiceNo} · ${formatPeso(widget.payment.amountPaid)} paid'
                ' ${_formatDate(widget.payment.paymentDate)}',
                style: GoogleFonts.dmSans(
                  fontSize: 11.5,
                  color: AppColors.textMuted3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Payment Method',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textMuted3,
                ),
              ),
              const SizedBox(height: 6),
              _PlanDropdown(
                value: _paymentMethod,
                items: paymentMethods,
                labelOf: formatPaymentMethod,
                onChanged: (v) => setState(() => _paymentMethod = v),
              ),
              const SizedBox(height: 14),
              Text(
                'Reference Number',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textMuted3,
                ),
              ),
              const SizedBox(height: 6),
              _BoxedField(controller: _referenceController),
              const SizedBox(height: 14),
              Text(
                'Notes',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: AppColors.textMuted3,
                ),
              ),
              const SizedBox(height: 6),
              _BoxedField(controller: _notesController, maxLines: 3),
              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
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
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(String iso) {
    final date = DateTime.tryParse(iso);
    return date != null ? DateFormat('MMM d, yyyy').format(date) : iso;
  }
}

class _PlanDropdown extends StatelessWidget {
  const _PlanDropdown({
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  final String value;
  final List<String> items;
  final String Function(String) labelOf;
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
          value: items.contains(value) ? value : null,
          isExpanded: true,
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
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(labelOf(item))),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _BoxedField extends StatelessWidget {
  const _BoxedField({required this.controller, this.maxLines = 1});

  final TextEditingController controller;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.inputBg,
        borderRadius: BorderRadius.circular(AppRadii.input),
        border: Border.all(color: AppColors.inputBorder, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: GoogleFonts.dmSans(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: AppColors.headingDark,
        ),
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
