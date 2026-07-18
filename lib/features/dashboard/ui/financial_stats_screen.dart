import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../billing/data/billing_repository.dart';
import '../../billing/models/invoice.dart';
import '../../billing/ui/billing_format.dart';
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

/// Admin/super_admin-only financial stats quickview: aggregate summary
/// (`GET /api/invoices/financial-summary/`) plus the real payments feed
/// (`GET /api/payments/`, `StudentPaymentViewSet`, `billing/views.py:470`,
/// gated to `BILLING_ROLES`). View-only — no drill-through to invoice
/// detail, no write actions (recording a payment stays on the website).
class FinancialStatsScreen extends StatefulWidget {
  const FinancialStatsScreen({super.key, required this.repository});

  final BillingRepository repository;

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

  @override
  void initState() {
    super.initState();
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
      final summary = await widget.repository.fetchFinancialSummary();
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
      debugPrint(
        'BillingRepository.fetchPayments failed: $error\n$stackTrace',
      );
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

  @override
  Widget build(BuildContext context) {
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
          IconButton(
            icon: const Icon(Icons.refresh, size: 20, color: AppColors.textMuted3),
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
              padding: const EdgeInsets.all(AppSpacing.dashboardScreenPadding),
              sliver: SliverToBoxAdapter(child: _buildSummary()),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.dashboardScreenPadding),
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
        return _ErrorState(onRetry: _loadSummary, message: "Couldn't load financial stats");
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
          child: _ErrorState(onRetry: _loadPayments, message: "Couldn't load payments"),
        );
      case _LoadStatus.loaded:
        if (_payments.isEmpty) {
          return const SliverToBoxAdapter(child: _EmptyPaymentsState());
        }
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.dashboardScreenPadding),
          sliver: SliverList.separated(
            itemCount: _payments.length + (_hasMore ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index >= _payments.length) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                );
              }
              return _PaymentRow(payment: _payments[index]);
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
                    title: Text(entry.value, style: GoogleFonts.dmSans(fontSize: 13)),
                    trailing: entry.key == value
                        ? const Icon(Icons.check, size: 18, color: AppColors.primary)
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
          border: value.isEmpty ? Border.all(color: AppColors.cardBorder) : null,
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
  const _PaymentRow({required this.payment});

  final PaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(payment.paymentDate);
    return Container(
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
              child: Icon(Icons.payments_outlined, size: 15, color: AppColors.primary),
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
                  style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
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
                style: GoogleFonts.dmSans(fontSize: 10.5, color: AppColors.textMuted3),
              ),
            ],
          ),
        ],
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
            const Icon(Icons.payments_outlined, size: 28, color: Color(0xFFD8B8B4)),
            const SizedBox(height: 8),
            Text(
              'No payments found',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
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
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textMuted1),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
