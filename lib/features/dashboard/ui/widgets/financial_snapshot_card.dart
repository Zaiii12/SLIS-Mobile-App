import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';

/// Admin/accounting card with a blur toggle over the peso amounts, per the
/// design mock. Registrar is excluded — the backend's BILLING_ROLES
/// (super_admin/admin/accounting) never includes registrar. Financial data
/// is deferred per the handoff (Billing out of scope this sprint), so
/// figures are placeholders until a real endpoint exists.
class FinancialSnapshotCard extends StatefulWidget {
  const FinancialSnapshotCard({
    super.key,
    this.collectedPercent = 78,
    this.collectedAmount = '₱3.84M',
    this.outstandingAmount = '₱1.08M',
  });

  final int collectedPercent;
  final String collectedAmount;
  final String outstandingAmount;

  @override
  State<FinancialSnapshotCard> createState() => _FinancialSnapshotCardState();
}

class _FinancialSnapshotCardState extends State<FinancialSnapshotCard> {
  bool _blurred = true;

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
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Financial Snapshot',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.headingDark,
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => _blurred = !_blurred),
                  child: Icon(
                    _blurred ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    size: 16,
                    color: AppColors.textMuted2,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Collected',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    ),
                    Text(
                      '${widget.collectedPercent}%',
                      style: GoogleFonts.dmSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.successText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  child: LinearProgressIndicator(
                    value: widget.collectedPercent / 100,
                    minHeight: 6,
                    backgroundColor: AppColors.cardBorder,
                    valueColor: const AlwaysStoppedAnimation(AppColors.successFill),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _AmountChip(
                      amount: widget.collectedAmount,
                      label: 'Collected',
                      background: AppColors.successBg2,
                      textColor: AppColors.successText2,
                      blurred: _blurred,
                    ),
                    const SizedBox(width: 8),
                    _AmountChip(
                      amount: widget.outstandingAmount,
                      label: 'Outstanding',
                      background: AppColors.dangerBg2,
                      textColor: AppColors.dangerText,
                      blurred: _blurred,
                    ),
                  ],
                ),
                if (_blurred) ...[
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () => setState(() => _blurred = false),
                    child: Text(
                      'Tap to reveal amounts',
                      style: GoogleFonts.dmSans(fontSize: 11, color: AppColors.textMuted3),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AmountChip extends StatelessWidget {
  const _AmountChip({
    required this.amount,
    required this.label,
    required this.background,
    required this.textColor,
    required this.blurred,
  });

  final String amount;
  final String label;
  final Color background;
  final Color textColor;
  final bool blurred;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
        child: ClipRect(
          child: Column(
            children: [
              ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: blurred ? 6 : 0,
                  sigmaY: blurred ? 6 : 0,
                ),
                child: Text(
                  amount,
                  style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                ),
              ),
              Text(label, style: GoogleFonts.dmSans(fontSize: 10, color: textColor)),
            ],
          ),
        ),
      ),
    );
  }
}
