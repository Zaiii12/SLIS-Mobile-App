import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';

final _pesoFormat = NumberFormat.currency(
  locale: 'en_PH',
  symbol: '₱',
  decimalDigits: 2,
);

String formatPeso(num amount) => _pesoFormat.format(amount);

String formatInvoiceDate(String? iso) {
  if (iso == null || iso.isEmpty) return '—';
  final date = DateTime.tryParse(iso);
  if (date == null) return iso;
  return DateFormat('MMM d, yyyy').format(date);
}

/// `school_level` choices as stored on enrollment-service's Enrollment model
/// (enrollments/models.py `SCHOOL_LEVEL_CHOICES`) — snake_case codes, not
/// display labels.
const _schoolLevelLabels = {
  'nursery': 'Nursery',
  'kindergarten': 'Kindergarten',
  'elementary': 'Elementary',
  'junior_highschool': 'Junior High School',
  'senior_highschool': 'Senior High School',
};

String formatSchoolLevel(String level) => _schoolLevelLabels[level] ?? level;

String shortSchoolLevel(String level) {
  switch (level) {
    case 'junior_highschool':
      return 'JHS';
    case 'senior_highschool':
      return 'SHS';
    default:
      return formatSchoolLevel(level);
  }
}

const _paymentPlanLabels = {
  'monthly': 'Monthly',
  'quarterly': 'Quarterly',
  'semi_annual': 'Semi-Annual',
  'annual': 'Annual',
};

String formatPaymentPlan(String plan) => _paymentPlanLabels[plan] ?? plan;

const _paymentMethodLabels = {
  'cash': 'Cash',
  'bank_transfer': 'Bank Transfer',
  'gcash': 'GCash',
  'card': 'Card',
  'check': 'Check',
  'others': 'Others',
};

String formatPaymentMethod(String method) =>
    _paymentMethodLabels[method] ?? method;

class StatusStyle {
  const StatusStyle(this.label, this.background, this.textColor);

  final String label;
  final Color background;
  final Color textColor;
}

const _invoiceStatusStyles = {
  'unpaid': StatusStyle('Unpaid', AppColors.dangerBg, AppColors.dangerText),
  'partially_paid': StatusStyle(
    'Partially Paid',
    AppColors.warningBg,
    AppColors.warningText2,
  ),
  'paid': StatusStyle('Paid', AppColors.successBg, AppColors.successText),
  'void': StatusStyle(
    'Void',
    AppColors.neutralPillBg,
    AppColors.neutralPillText,
  ),
};

StatusStyle invoiceStatusStyle(String status) =>
    _invoiceStatusStyles[status] ?? _invoiceStatusStyles['void']!;

const _installmentStatusStyles = {
  'pending': StatusStyle(
    'Pending',
    AppColors.neutralPillBg,
    AppColors.neutralPillText,
  ),
  'partially_paid': StatusStyle(
    'Partially Paid',
    AppColors.warningBg,
    AppColors.warningText2,
  ),
  'paid': StatusStyle('Paid', AppColors.successBg, AppColors.successText),
  'overdue': StatusStyle('Overdue', AppColors.dangerBg, AppColors.dangerText),
};

StatusStyle installmentStatusStyle(String status) =>
    _installmentStatusStyles[status] ?? _installmentStatusStyles['pending']!;

/// `enrollment_status` choices per enrollment-service's `Enrollment.
/// STATUS_CHOICES` (enrollments/models.py).
const _enrollmentStatusStyles = {
  'enrolled': StatusStyle('Enrolled', AppColors.successBg, AppColors.successText),
  'pending': StatusStyle('Pending', AppColors.warningBg, AppColors.warningText2),
  'cancelled': StatusStyle('Cancelled', AppColors.dangerBg, AppColors.dangerText),
  'completed': StatusStyle('Completed', AppColors.infoBlueBg, AppColors.infoBlueIcon),
  'transferred_out': StatusStyle(
    'Transferred Out',
    AppColors.neutralPillBg,
    AppColors.neutralPillText,
  ),
};

StatusStyle enrollmentStatusStyle(String status) =>
    _enrollmentStatusStyles[status] ?? _enrollmentStatusStyles['pending']!;

class DueMeta {
  const DueMeta(this.label, this.background, this.textColor, this.isOverdue);

  final String label;
  final Color background;
  final Color textColor;
  final bool isOverdue;
}

/// Due-date pill for the invoice list row: overdue (red) / due within 5 days
/// (amber) / due later (neutral). `today` is injectable for tests.
DueMeta dueMetaFor(String? isoDueDate, {DateTime? today}) {
  if (isoDueDate == null || isoDueDate.isEmpty) {
    return const DueMeta(
      'No due date',
      AppColors.neutralPillBg,
      AppColors.neutralPillText,
      false,
    );
  }
  final due = DateTime.tryParse(isoDueDate);
  if (due == null) {
    return const DueMeta(
      'No due date',
      AppColors.neutralPillBg,
      AppColors.neutralPillText,
      false,
    );
  }
  final now = today ?? DateTime.now();
  final todayDate = DateTime(now.year, now.month, now.day);
  final dueDate = DateTime(due.year, due.month, due.day);
  final days = dueDate.difference(todayDate).inDays;

  if (days < 0) {
    final n = -days;
    return DueMeta(
      '$n day${n == 1 ? '' : 's'} overdue',
      AppColors.dangerBg,
      AppColors.dangerText,
      true,
    );
  }
  if (days <= 5) {
    final label = days == 0
        ? 'Due today'
        : 'Due in $days day${days == 1 ? '' : 's'}';
    return DueMeta(label, AppColors.warningBg, AppColors.warningText2, false);
  }
  return DueMeta(
    'Due in $days days',
    AppColors.neutralPillBg,
    AppColors.neutralPillText,
    false,
  );
}
