import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/billing_repository.dart';
import '../models/guardian_contact.dart';
import '../models/invoice.dart';
import 'billing_format.dart';

/// Full breakdown of one invoice. The `invoice` passed in already has the
/// complete nested shape (items/discounts/installments/payments) whether it
/// came from the list row or a direct fetch — StudentInvoiceSerializer
/// returns the same payload on list and detail (billing/serializers.py:160),
/// so no re-fetch is needed to render this screen.
///
/// Guardian contact is the one thing NOT on the invoice payload at all — it's
/// fetched separately (see BillingApi.fetchPrimaryGuardian) and shown only
/// here, never on the list, since there's no bulk lookup to avoid N+1.
class InvoiceDetailScreen extends StatefulWidget {
  const InvoiceDetailScreen({
    super.key,
    required this.invoice,
    required this.repository,
  });

  final Invoice invoice;
  final BillingRepository repository;

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Future<GuardianContact?> _guardianFuture;

  @override
  void initState() {
    super.initState();
    final lrn = widget.invoice.enrollmentDetail?.lrn ?? '';
    _guardianFuture = widget.repository
        .fetchPrimaryGuardian(lrn)
        .catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final invoice = widget.invoice;
    final enrollment = invoice.enrollmentDetail;
    final statusStyle = invoiceStatusStyle(invoice.status);

    return Scaffold(
      backgroundColor: AppColors.dashboardBg,
      appBar: AppBar(
        title: Text(
          invoice.invoiceNo,
          style: GoogleFonts.dmSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: AppColors.headingDark,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 30),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  enrollment?.studentName ?? 'Unknown student',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusStyle.background,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Text(
                  statusStyle.label,
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusStyle.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            'LRN ${enrollment?.lrn ?? '—'} · ${enrollment?.gradeLevel ?? ''} - ${enrollment?.section ?? ''}'
            ' · ${enrollment?.schoolLevel ?? ''}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: AppColors.textMuted3,
            ),
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          _InfoCard(
            title: 'Enrollment',
            rows: [
              _InfoRow('School Year', enrollment?.schoolYear ?? '—'),
              _InfoRow('Grade Level', enrollment?.gradeLevel ?? '—'),
              _InfoRow('Section', enrollment?.section ?? '—'),
              _InfoRow('School Level', enrollment?.schoolLevel ?? '—'),
            ],
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          _GuardianContactCard(future: _guardianFuture),
          const SizedBox(height: AppSpacing.interCardGap),
          _InfoCard(
            title: 'Billing',
            rows: [
              _InfoRow('Invoice Date', formatInvoiceDate(invoice.invoiceDate)),
              _InfoRow('Due Date', formatInvoiceDate(invoice.dueDate)),
              _InfoRow('Payment Plan', formatPaymentPlan(invoice.paymentPlan)),
            ],
          ),
          const SizedBox(height: AppSpacing.interCardGap),
          _FeeItemsCard(invoice: invoice),
          if (invoice.discounts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.interCardGap),
            _DiscountsCard(invoice: invoice),
          ],
          const SizedBox(height: AppSpacing.interCardGap),
          _InstallmentsCard(invoice: invoice),
          const SizedBox(height: AppSpacing.interCardGap),
          _PaymentsCard(invoice: invoice),
          const SizedBox(height: AppSpacing.interCardGap),
          _SummaryCallout(invoice: invoice),
        ],
      ),
    );
  }
}

class _GuardianContactCard extends StatelessWidget {
  const _GuardianContactCard({required this.future});

  final Future<GuardianContact?> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuardianContact?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _InfoCard(title: 'Contact', rows: [], loading: true);
        }
        final guardian = snapshot.data;
        if (guardian == null) {
          return const _InfoCard(
            title: 'Contact',
            rows: [_InfoRow('Guardian', 'Not available')],
          );
        }
        return _InfoCard(
          title: 'Contact',
          rows: [
            _InfoRow('Guardian', guardian.fullName),
            _InfoRow('Phone', guardian.mobileNumber ?? '—'),
            _InfoRow('Email', guardian.emailAddress ?? '—'),
          ],
        );
      },
    );
  }
}

class _FeeItemsCard extends StatelessWidget {
  const _FeeItemsCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Fee Items',
      child: Column(
        children: [
          for (final item in invoice.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      item.description,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: AppColors.headingDark,
                      ),
                    ),
                  ),
                  Text(
                    formatPeso(item.amount),
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Text(
                  'TOTAL ITEMS',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.labelUppercase1,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  formatPeso(invoice.totalItems),
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscountsCard extends StatelessWidget {
  const _DiscountsCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Discounts',
      child: Column(
        children: [
          for (final d in invoice.discounts)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      d.description,
                      style: GoogleFonts.dmSans(
                        fontSize: 12.5,
                        color: AppColors.headingDark,
                      ),
                    ),
                  ),
                  Text(
                    '-${formatPeso(d.amount)}',
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.successText2,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 11),
            child: Row(
              children: [
                Text(
                  'TOTAL DISCOUNTS',
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.labelUppercase1,
                    letterSpacing: 0.3,
                  ),
                ),
                const Spacer(),
                Text(
                  '-${formatPeso(invoice.totalDiscounts)}',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.successText2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstallmentsCard extends StatelessWidget {
  const _InstallmentsCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Installment Schedule',
      child: Column(
        children: [
          for (final ins in invoice.installments)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _installmentLabel(ins.sequence, invoice.paymentPlan),
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.headingDark,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Due ${formatInvoiceDate(ins.dueDate)}',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: AppColors.textMuted3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatPeso(ins.amount),
                        style: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.headingDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _StatusPill(
                        style: installmentStatusStyle(ins.status),
                        fontSize: 9.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _installmentLabel(int sequence, String plan) {
    if (plan == 'annual') return 'Full Payment';
    return '${_ordinal(sequence)} Installment';
  }

  String _ordinal(int n) {
    if (n == 1) return '1st';
    if (n == 2) return '2nd';
    if (n == 3) return '3rd';
    return '${n}th';
  }
}

class _PaymentsCard extends StatelessWidget {
  const _PaymentsCard({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: 'Payments',
      child: invoice.payments.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 22),
              child: Center(
                child: Text(
                  'No payments received yet',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: AppColors.textMuted3,
                  ),
                ),
              ),
            )
          : Column(
              children: [
                for (final p in invoice.payments)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatPaymentMethod(p.paymentMethod),
                                style: GoogleFonts.dmSans(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.headingDark,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${formatInvoiceDate(p.paymentDate)}'
                                '${p.referenceNumber != null ? ' · Ref ${p.referenceNumber}' : ''}',
                                style: GoogleFonts.dmSans(
                                  fontSize: 11,
                                  color: AppColors.textMuted3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          formatPeso(p.amountPaid),
                          style: GoogleFonts.dmSans(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.successText2,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

class _SummaryCallout extends StatelessWidget {
  const _SummaryCallout({required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(AppRadii.dashboardCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _summaryLine('Total Fees', formatPeso(invoice.totalItems)),
          _summaryLine(
            'Total Discounts',
            '-${formatPeso(invoice.totalDiscounts)}',
          ),
          _summaryLine('Net Amount', formatPeso(invoice.netAmount)),
          _summaryLine('Total Paid', formatPeso(invoice.totalPaid)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: Divider(height: 1, color: Color(0x26A32D2D)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Balance Due',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dangerText,
                ),
              ),
              Text(
                formatPeso(invoice.balance),
                style: GoogleFonts.dmSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.dangerText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              color: AppColors.textMuted1,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.dmSans(
              fontSize: 11.5,
              color: AppColors.textMuted1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.style, this.fontSize = 11});

  final StatusStyle style;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Text(
        style.label,
        style: GoogleFonts.dmSans(
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          color: style.textColor,
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    required this.rows,
    this.loading = false,
  });

  final String title;
  final List<_InfoRow> rows;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return _Card(
      title: title,
      child: loading
          ? const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Column(children: rows),
    );
  }
}
