import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/billing_repository.dart';
import '../models/invoice.dart';
import 'billing_format.dart';

/// Quick "record a payment" bottom sheet for an invoice that still has a
/// balance — used as a shortcut from the unpaid invoices list so recording a
/// payment doesn't require opening the full [InvoiceDetailScreen] first.
/// Mirrors that screen's inline record-payment form field-for-field (amount
/// defaults to the full balance, method defaults to `cash`, reference/notes
/// optional) so behavior stays identical wherever payment is recorded from.
///
/// Pops with the updated [Invoice] on success (`null` if dismissed/cancelled)
/// so callers can refresh their list in place.
class RecordPaymentSheet extends StatefulWidget {
  const RecordPaymentSheet({
    super.key,
    required this.invoice,
    required this.repository,
  });

  final Invoice invoice;
  final BillingRepository repository;

  @override
  State<RecordPaymentSheet> createState() => _RecordPaymentSheetState();
}

class _RecordPaymentSheetState extends State<RecordPaymentSheet> {
  late final _amountController = TextEditingController(
    text: widget.invoice.balance.toStringAsFixed(2),
  );
  final _referenceController = TextEditingController();
  final _notesController = TextEditingController();
  String _paymentMethod = paymentMethods.first;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = num.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid payment amount.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.repository.recordPayment(
        invoiceId: widget.invoice.invoiceId,
        amountPaid: amount,
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
            "Couldn't record the payment. Check your connection and try again.";
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
    final invoice = widget.invoice;
    final studentName = invoice.enrollmentDetail?.studentName ?? invoice.invoiceNo;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    'Record Payment',
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
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '$studentName · ${invoice.invoiceNo} · '
                '${formatPeso(invoice.balance)} balance',
                style: GoogleFonts.dmSans(fontSize: 11.5, color: AppColors.textMuted3),
              ),
              const SizedBox(height: 16),
              _FieldLabel('Amount Paid'),
              _BoxedField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Payment Method'),
              _MethodDropdown(
                value: _paymentMethod,
                onChanged: (v) => setState(() => _paymentMethod = v),
              ),
              const SizedBox(height: 14),
              _FieldLabel('Reference Number (optional)'),
              _BoxedField(controller: _referenceController),
              const SizedBox(height: 14),
              _FieldLabel('Notes (optional)'),
              _BoxedField(controller: _notesController, maxLines: 3),
              if (_error != null) ...[
                const SizedBox(height: 14),
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
                      : const Text('Save Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

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

class _BoxedField extends StatelessWidget {
  const _BoxedField({required this.controller, this.keyboardType, this.maxLines = 1});

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

class _MethodDropdown extends StatelessWidget {
  const _MethodDropdown({required this.value, required this.onChanged});

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
          icon: const Icon(Icons.expand_more, size: 16, color: AppColors.textMuted2),
          borderRadius: BorderRadius.circular(AppRadii.input),
          style: GoogleFonts.dmSans(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: AppColors.headingDark,
          ),
          items: [
            for (final method in paymentMethods)
              DropdownMenuItem(value: method, child: Text(formatPaymentMethod(method))),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}
