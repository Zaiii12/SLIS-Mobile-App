import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

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
  late Invoice _invoice;
  bool _recordingPayment = false;
  bool _paymentSaving = false;
  String? _paymentError;
  bool _changed = false;

  final _amountController = TextEditingController();
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = paymentMethods.first;

  bool _editingInvoice = false;
  bool _invoiceSaving = false;
  String? _invoiceError;
  DateTime? _editDueDate;
  late String _editPaymentPlan = _invoice.paymentPlan;

  @override
  void initState() {
    super.initState();
    _invoice = widget.invoice;
    _editPaymentPlan = _invoice.paymentPlan;
    final lrn = _invoice.enrollmentDetail?.lrn ?? '';
    _guardianFuture = widget.repository
        .fetchPrimaryGuardian(lrn)
        .catchError((_) => null);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _startEditingInvoice() {
    setState(() {
      _editingInvoice = true;
      _invoiceError = null;
      _editDueDate = DateTime.tryParse(_invoice.dueDate ?? '');
      _editPaymentPlan = _invoice.paymentPlan;
    });
  }

  void _cancelEditingInvoice() {
    setState(() {
      _editingInvoice = false;
      _invoiceError = null;
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await _showDatePickerSheet(
      context,
      initialDate: _editDueDate,
    );
    if (picked != null) setState(() => _editDueDate = picked);
  }

  Future<void> _saveInvoice() async {
    setState(() {
      _invoiceSaving = true;
      _invoiceError = null;
    });
    try {
      final updated = await widget.repository.updateInvoice(
        invoiceId: _invoice.invoiceId,
        dueDate: _editDueDate != null
            ? DateFormat('yyyy-MM-dd').format(_editDueDate!)
            : null,
        paymentPlan: _editPaymentPlan,
      );
      if (!mounted) return;
      setState(() {
        _invoice = updated;
        _editingInvoice = false;
        _invoiceSaving = false;
        _changed = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _invoiceSaving = false;
        _invoiceError =
            _extractErrorMessage(e.response?.data) ??
            "Couldn't save changes. Check your connection and try again.";
      });
    }
  }

  void _startRecordingPayment() {
    setState(() {
      _recordingPayment = true;
      _paymentError = null;
      _amountController.text = _invoice.balance.toStringAsFixed(2);
      _referenceController.clear();
      _notesController.clear();
      _paymentMethod = paymentMethods.first;
    });
  }

  void _cancelRecordingPayment() {
    setState(() {
      _recordingPayment = false;
      _paymentError = null;
    });
  }

  Future<void> _submitPayment() async {
    final amount = num.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _paymentError = 'Enter a valid payment amount.');
      return;
    }
    setState(() {
      _paymentSaving = true;
      _paymentError = null;
    });
    try {
      final updated = await widget.repository.recordPayment(
        invoiceId: _invoice.invoiceId,
        amountPaid: amount,
        paymentMethod: _paymentMethod,
        referenceNumber: _referenceController.text.trim(),
        notes: _notesController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _invoice = updated;
        _recordingPayment = false;
        _paymentSaving = false;
        _changed = true;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _paymentSaving = false;
        _paymentError =
            _extractErrorMessage(e.response?.data) ??
            "Couldn't record the payment. Check your connection and try again.";
      });
    }
  }

  /// DRF `ValidationError` responses are `{"field": ["message"]}` or
  /// `{"non_field_errors": ["message"]}` — surfaced as-is (e.g. the
  /// server-side overpayment guard's peso-formatted message) rather than a
  /// generic failure message.
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
    final invoice = _invoice;
    final enrollment = invoice.enrollmentDetail;
    final statusStyle = invoiceStatusStyle(invoice.status);

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {},
      child: Scaffold(
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
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(_changed),
          ),
          actions: [
            if (!_editingInvoice && !_recordingPayment)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit due date / payment plan',
                onPressed: _startEditingInvoice,
              ),
            if (_editingInvoice)
              TextButton(
                onPressed: _invoiceSaving ? null : _cancelEditingInvoice,
                child: Text(
                  'Cancel',
                  style: GoogleFonts.dmSans(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted3,
                  ),
                ),
              ),
          ],
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
            if (_editingInvoice)
              _EditInvoiceForm(
                invoiceDate: formatInvoiceDate(invoice.invoiceDate),
                dueDate: _editDueDate,
                onPickDueDate: _pickDueDate,
                paymentPlan: _editPaymentPlan,
                onPaymentPlanChanged: (v) =>
                    setState(() => _editPaymentPlan = v),
              )
            else
              _InfoCard(
                title: 'Billing',
                rows: [
                  _InfoRow(
                    'Invoice Date',
                    formatInvoiceDate(invoice.invoiceDate),
                  ),
                  _InfoRow('Due Date', formatInvoiceDate(invoice.dueDate)),
                  _InfoRow(
                    'Payment Plan',
                    formatPaymentPlan(invoice.paymentPlan),
                  ),
                ],
              ),
            if (_invoiceError != null) ...[
              const SizedBox(height: AppSpacing.interCardGap),
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
                  _invoiceError!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            ],
            if (_editingInvoice) ...[
              const SizedBox(height: AppSpacing.interCardGap),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _invoiceSaving ? null : _saveInvoice,
                  child: _invoiceSaving
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
            if (_paymentError != null) ...[
              const SizedBox(height: AppSpacing.interCardGap),
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
                  _paymentError!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.dangerText,
                  ),
                ),
              ),
            ],
            if (_recordingPayment) ...[
              const SizedBox(height: AppSpacing.interCardGap),
              _RecordPaymentForm(
                amountController: _amountController,
                referenceController: _referenceController,
                notesController: _notesController,
                paymentMethod: _paymentMethod,
                onPaymentMethodChanged: (v) =>
                    setState(() => _paymentMethod = v),
              ),
              const SizedBox(height: AppSpacing.interCardGap),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _paymentSaving
                          ? null
                          : _cancelRecordingPayment,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _paymentSaving ? null : _submitPayment,
                      child: _paymentSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Payment'),
                    ),
                  ),
                ],
              ),
            ] else if (invoice.balance > 0) ...[
              const SizedBox(height: AppSpacing.interCardGap),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _startRecordingPayment,
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Record Payment'),
                ),
              ),
            ],
          ],
        ),
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

/// Invoice Date is display-only (server-set on generation, not writable per
/// `StudentInvoiceSerializer.read_only_fields`) — only Due Date and Payment
/// Plan are editable, matching `BillingApi.updateInvoice`'s deliberately
/// narrow PATCH body. `status` is never exposed here (see that method's doc
/// comment for why).
class _EditInvoiceForm extends StatelessWidget {
  const _EditInvoiceForm({
    required this.invoiceDate,
    required this.dueDate,
    required this.onPickDueDate,
    required this.paymentPlan,
    required this.onPaymentPlanChanged,
  });

  final String invoiceDate;
  final DateTime? dueDate;
  final VoidCallback onPickDueDate;
  final String paymentPlan;
  final ValueChanged<String> onPaymentPlanChanged;

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
              'Edit Billing',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PaymentFieldLabel('Invoice Date'),
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    invoiceDate,
                    style: GoogleFonts.dmSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted3,
                    ),
                  ),
                ),
                _PaymentFieldLabel('Due Date'),
                InkWell(
                  onTap: onPickDueDate,
                  borderRadius: BorderRadius.circular(AppRadii.input),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(AppRadii.input),
                      border: Border.all(
                        color: AppColors.inputBorder,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dueDate != null
                                ? DateFormat('MMM d, yyyy').format(dueDate!)
                                : 'Select a date',
                            style: GoogleFonts.dmSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: dueDate != null
                                  ? AppColors.headingDark
                                  : AppColors.textMuted3,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.calendar_today_outlined,
                          size: 15,
                          color: AppColors.textMuted2,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _PaymentFieldLabel('Payment Plan'),
                _PaymentMethodPlanDropdown(
                  value: paymentPlan,
                  onChanged: onPaymentPlanChanged,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentMethodPlanDropdown extends StatelessWidget {
  const _PaymentMethodPlanDropdown({
    required this.value,
    required this.onChanged,
  });

  final String value;
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
          value: paymentPlans.contains(value) ? value : null,
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

/// White bottom-sheet calendar picker for the invoice due date, matching the
/// same style fix `monitoring/ui/audit_log_screen.dart`'s private
/// `_showDatePickerSheet` uses (Material 3's default `showDatePicker` dialog
/// tints itself with the app's red seed color, which reads as washed-out).
/// Kept as its own copy rather than sharing that one since it's private to
/// that file and this screen's valid range is different — a due date is
/// future-dated, not a historical filter, so `lastDate` extends forward
/// instead of capping at `DateTime.now()`.
Future<DateTime?> _showDatePickerSheet(
  BuildContext context, {
  DateTime? initialDate,
}) {
  final now = DateTime.now();
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: AppColors.cardWhite,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select due date',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
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
          ),
          Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                surface: AppColors.cardWhite,
                primary: AppColors.primary,
                onPrimary: Colors.white,
                onSurface: AppColors.headingDark,
              ),
            ),
            child: CalendarDatePicker(
              initialDate: initialDate ?? now,
              firstDate: DateTime(2020),
              lastDate: DateTime(now.year + 2),
              onDateChanged: (picked) => Navigator.of(context).pop(picked),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Amount defaults to the current balance ([_InvoiceDetailScreenState.
/// _startRecordingPayment]) but is editable for partial payments. Method
/// defaults to `cash` — the most common in-person accounting scenario.
/// Reference/notes are optional, matching `StudentPayment`'s nullable
/// `reference_number`/`notes` fields.
class _RecordPaymentForm extends StatelessWidget {
  const _RecordPaymentForm({
    required this.amountController,
    required this.referenceController,
    required this.notesController,
    required this.paymentMethod,
    required this.onPaymentMethodChanged,
  });

  final TextEditingController amountController;
  final TextEditingController referenceController;
  final TextEditingController notesController;
  final String paymentMethod;
  final ValueChanged<String> onPaymentMethodChanged;

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
              'Record Payment',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.headingDark,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PaymentFieldLabel('Amount Paid'),
                _PaymentTextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 14),
                _PaymentFieldLabel('Payment Method'),
                _PaymentMethodDropdown(
                  value: paymentMethod,
                  onChanged: onPaymentMethodChanged,
                ),
                const SizedBox(height: 14),
                _PaymentFieldLabel('Reference Number (optional)'),
                _PaymentTextField(controller: referenceController),
                const SizedBox(height: 14),
                _PaymentFieldLabel('Notes (optional)'),
                _PaymentTextField(controller: notesController, maxLines: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentFieldLabel extends StatelessWidget {
  const _PaymentFieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        label,
        style: GoogleFonts.dmSans(fontSize: 12, color: AppColors.textMuted3),
      ),
    );
  }
}

class _PaymentTextField extends StatelessWidget {
  const _PaymentTextField({
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final TextInputType? keyboardType;
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
        keyboardType: keyboardType,
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
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}

class _PaymentMethodDropdown extends StatelessWidget {
  const _PaymentMethodDropdown({required this.value, required this.onChanged});

  final String value;
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
          value: paymentMethods.contains(value) ? value : null,
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
            for (final method in paymentMethods)
              DropdownMenuItem(
                value: method,
                child: Text(formatPaymentMethod(method)),
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
