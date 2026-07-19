import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../data/billing_repository.dart';
import '../models/invoice.dart';
import 'billing_format.dart';

/// Search-and-pick sheet for the "Record Payment" quick action on
/// [FinancialStatsScreen] — that screen only has a payments feed (no
/// balance), so recording a payment from there needs an invoice picked first.
/// Reuses the same `status=unpaid` + search endpoint as
/// [UnpaidInvoicesListScreen] (`BillingRepository.fetchUnpaidInvoices`).
///
/// Pops with the selected [Invoice] (`null` if dismissed) so the caller can
/// chain straight into `RecordPaymentSheet`.
class PickUnpaidInvoiceSheet extends StatefulWidget {
  const PickUnpaidInvoiceSheet({super.key, required this.repository});

  final BillingRepository repository;

  @override
  State<PickUnpaidInvoiceSheet> createState() => _PickUnpaidInvoiceSheetState();
}

enum _LoadStatus { loading, loaded, error }

class _PickUnpaidInvoiceSheetState extends State<PickUnpaidInvoiceSheet> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  _LoadStatus _status = _LoadStatus.loading;
  List<Invoice> _invoices = const [];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() => _status = _LoadStatus.loading);
    try {
      final result = await widget.repository.fetchUnpaidInvoices(
        search: _searchController.text.trim(),
        page: 1,
      );
      if (!mounted) return;
      setState(() {
        _invoices = result.invoices;
        _status = _LoadStatus.loaded;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _status = _LoadStatus.error);
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.cardWhite,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
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
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.inputBg,
                      borderRadius: BorderRadius.circular(AppRadii.input),
                      border: Border.all(color: AppColors.inputBorder, width: 1.5),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      style: GoogleFonts.dmSans(fontSize: 12.5, color: AppColors.headingDark),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: false,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        hintText: 'Search student or invoice no.',
                        hintStyle: GoogleFonts.dmSans(
                          fontSize: 12.5,
                          color: AppColors.textMuted3,
                        ),
                        prefixIcon: const Icon(
                          Icons.search,
                          size: 18,
                          color: AppColors.textMuted3,
                        ),
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(child: _buildBody(scrollController)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(ScrollController scrollController) {
    switch (_status) {
      case _LoadStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case _LoadStatus.error:
        return Center(
          child: TextButton(
            onPressed: _search,
            child: Text(
              'Retry',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
        );
      case _LoadStatus.loaded:
        if (_invoices.isEmpty) {
          return Center(
            child: Text(
              'No unpaid invoices found',
              style: GoogleFonts.dmSans(fontSize: 13, color: AppColors.textMuted1),
            ),
          );
        }
        return ListView.separated(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          itemCount: _invoices.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final invoice = _invoices[index];
            return _InvoiceOption(
              invoice: invoice,
              onTap: () => Navigator.of(context).pop(invoice),
            );
          },
        );
    }
  }
}

class _InvoiceOption extends StatelessWidget {
  const _InvoiceOption({required this.invoice, required this.onTap});

  final Invoice invoice;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final studentName = invoice.enrollmentDetail?.studentName ?? 'Unknown student';
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    studentName,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.headingDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    invoice.invoiceNo,
                    style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              formatPeso(invoice.balance),
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.dangerText,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 14, color: Color(0xFFD0B0B0)),
          ],
        ),
      ),
    );
  }
}
