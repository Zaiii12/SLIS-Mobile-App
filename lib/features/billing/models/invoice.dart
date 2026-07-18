/// Invoice models mirroring billing-service's `StudentInvoiceSerializer`
/// (`billing/serializers.py:160`) — same fully-nested shape on both the list
/// and detail endpoints, so one model/parse path covers both.
///
/// Money field encoding is NOT uniform: plain `ModelSerializer` fields that
/// pass a Django `DecimalField` straight through (item/discount/installment/
/// payment `amount`/`amount_paid`) are serialized by DRF as JSON **strings**
/// (e.g. `"2500.00"`), while the `SerializerMethodField` totals on the
/// invoice itself (`total_items`, `net_amount`, `balance`, etc. — computed
/// via `sum()` over Decimals) come back as JSON **numbers**. Confirmed by
/// hitting the real endpoint directly. [_parseAmount] accepts either so a
/// server-side serializer tweak in either direction doesn't silently throw
/// a type-cast error inside a try/catch and surface as a generic "couldn't
/// load" with no visible cause.
library;

num _parseAmount(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

class EnrollmentDetail {
  const EnrollmentDetail({
    required this.enrollmentId,
    required this.schoolYear,
    required this.gradeLevel,
    required this.section,
    required this.schoolLevel,
    required this.studentName,
    required this.lrn,
  });

  factory EnrollmentDetail.fromJson(Map<String, dynamic> json) {
    return EnrollmentDetail(
      enrollmentId: json['enrollment_id'].toString(),
      schoolYear: json['school_year'] as String? ?? '',
      gradeLevel: json['grade_level'] as String? ?? '',
      section: json['section'] as String? ?? '',
      schoolLevel: json['school_level'] as String? ?? '',
      studentName: json['student_name'] as String? ?? '',
      lrn: json['lrn'] as String? ?? '',
    );
  }

  final String enrollmentId;
  final String schoolYear;
  final String gradeLevel;
  final String section;
  final String schoolLevel;
  final String studentName;
  final String lrn;

  /// Two-letter initials for the list/detail avatar.
  String get initials {
    final parts = studentName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty);
    final letters = parts.take(2).map((p) => p[0]).join().toUpperCase();
    return letters.isEmpty ? '?' : letters;
  }
}

class FeeItem {
  const FeeItem({required this.description, required this.amount});

  factory FeeItem.fromJson(Map<String, dynamic> json) {
    return FeeItem(
      description: json['description'] as String? ?? '',
      amount: _parseAmount(json['amount']),
    );
  }

  final String description;
  final num amount;
}

class InvoiceDiscount {
  const InvoiceDiscount({required this.description, required this.amount});

  factory InvoiceDiscount.fromJson(Map<String, dynamic> json) {
    return InvoiceDiscount(
      description: json['description'] as String? ?? '',
      amount: _parseAmount(json['amount']),
    );
  }

  final String description;
  final num amount;
}

/// Installment `status`: pending | partially_paid | paid | overdue — overdue
/// is auto-flagged server-side on every read (`InvoiceInstallmentViewSet.
/// _flag_overdue()`), not computed client-side.
class Installment {
  const Installment({
    required this.sequence,
    required this.dueDate,
    required this.amount,
    required this.amountPaid,
    required this.status,
  });

  factory Installment.fromJson(Map<String, dynamic> json) {
    return Installment(
      sequence: json['sequence'] as int? ?? 0,
      dueDate: json['due_date'] as String? ?? '',
      amount: _parseAmount(json['amount']),
      amountPaid: _parseAmount(json['amount_paid']),
      status: json['status'] as String? ?? 'pending',
    );
  }

  final int sequence;
  final String dueDate;
  final num amount;
  final num amountPaid;
  final String status;
}

/// Payment `payment_method`: cash | bank_transfer | gcash | card | check | others.
class Payment {
  const Payment({
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentMethod,
    required this.referenceNumber,
  });

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      paymentDate: json['payment_date'] as String? ?? '',
      amountPaid: _parseAmount(json['amount_paid']),
      paymentMethod: json['payment_method'] as String? ?? '',
      referenceNumber: json['reference_number'] as String?,
    );
  }

  final String paymentDate;
  final num amountPaid;
  final String paymentMethod;
  final String? referenceNumber;
}

/// `status`: unpaid | partially_paid | paid | void.
/// `payment_plan`: monthly | quarterly | semi_annual | annual.
class Invoice {
  const Invoice({
    required this.invoiceId,
    required this.enrollmentId,
    required this.enrollmentDetail,
    required this.invoiceNo,
    required this.invoiceDate,
    required this.status,
    required this.paymentPlan,
    required this.dueDate,
    required this.items,
    required this.discounts,
    required this.installments,
    required this.payments,
    required this.totalItems,
    required this.totalDiscounts,
    required this.netAmount,
    required this.totalPaid,
    required this.balance,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    final enrollmentDetailJson =
        json['enrollment_detail'] as Map<String, dynamic>?;
    return Invoice(
      invoiceId: json['invoice_id'].toString(),
      enrollmentId: json['enrollment_id'].toString(),
      enrollmentDetail: enrollmentDetailJson != null
          ? EnrollmentDetail.fromJson(enrollmentDetailJson)
          : null,
      invoiceNo: json['invoice_no'] as String? ?? '',
      invoiceDate: json['invoice_date'] as String? ?? '',
      status: json['status'] as String? ?? 'unpaid',
      paymentPlan: json['payment_plan'] as String? ?? 'monthly',
      dueDate: json['due_date'] as String?,
      items: ((json['items'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(FeeItem.fromJson)
          .toList(),
      discounts: ((json['discounts'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(InvoiceDiscount.fromJson)
          .toList(),
      installments: ((json['installments'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(Installment.fromJson)
          .toList(),
      payments: ((json['payments'] as List?) ?? [])
          .cast<Map<String, dynamic>>()
          .map(Payment.fromJson)
          .toList(),
      totalItems: _parseAmount(json['total_items']),
      totalDiscounts: _parseAmount(json['total_discounts']),
      netAmount: _parseAmount(json['net_amount']),
      totalPaid: _parseAmount(json['total_paid']),
      balance: _parseAmount(json['balance']),
    );
  }

  final String invoiceId;
  final String enrollmentId;
  final EnrollmentDetail? enrollmentDetail;
  final String invoiceNo;
  final String invoiceDate;
  final String status;
  final String paymentPlan;
  final String? dueDate;
  final List<FeeItem> items;
  final List<InvoiceDiscount> discounts;
  final List<Installment> installments;
  final List<Payment> payments;
  final num totalItems;
  final num totalDiscounts;
  final num netAmount;
  final num totalPaid;
  final num balance;

  int get overdueInstallmentCount =>
      installments.where((i) => i.status == 'overdue').length;
}

/// Mirrors `StudentInvoiceViewSet.financial_summary`
/// (`billing/views.py:252`) — peso totals across non-void invoices,
/// optionally scoped to one `school_year`. Blocked for `guardian` role only
/// (403); every staff role including admin/super_admin can call it.
class FinancialSummary {
  const FinancialSummary({
    required this.grossBilled,
    required this.totalDiscounts,
    required this.netBilled,
    required this.totalCollected,
    required this.outstanding,
    required this.invoiceCount,
  });

  factory FinancialSummary.fromJson(Map<String, dynamic> json) {
    return FinancialSummary(
      grossBilled: _parseAmount(json['gross_billed']),
      totalDiscounts: _parseAmount(json['total_discounts']),
      netBilled: _parseAmount(json['net_billed']),
      totalCollected: _parseAmount(json['total_collected']),
      outstanding: _parseAmount(json['outstanding']),
      invoiceCount: json['invoice_count'] as int? ?? 0,
    );
  }

  final num grossBilled;
  final num totalDiscounts;
  final num netBilled;
  final num totalCollected;
  final num outstanding;
  final int invoiceCount;

  /// Percentage of net-billed amount actually collected, 0 when there's
  /// nothing billed yet (avoids a divide-by-zero NaN reaching the UI).
  int get collectedPercent {
    if (netBilled <= 0) return 0;
    return ((totalCollected / netBilled) * 100).round().clamp(0, 100);
  }
}

/// Mirrors `StudentPaymentSerializer` (`billing/serializers.py:122`) — the
/// standalone `/api/payments/` list, distinct from the [Payment] class
/// nested inside [Invoice.payments] (which has no `payment_id`/
/// `invoice_detail`, only what's needed inline on one invoice's detail
/// screen). `invoice_detail` is a raw-SQL join (billing → enrollments →
/// students) done per-row server-side, so `studentName` here comes for
/// free without an extra client call.
class PaymentRecord {
  const PaymentRecord({
    required this.paymentId,
    required this.invoiceId,
    required this.studentName,
    required this.invoiceNo,
    required this.paymentDate,
    required this.amountPaid,
    required this.paymentMethod,
    required this.referenceNumber,
    required this.notes,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    final detail = json['invoice_detail'] as Map<String, dynamic>?;
    return PaymentRecord(
      paymentId: json['payment_id'].toString(),
      invoiceId: json['invoice'].toString(),
      studentName: detail?['student_name'] as String? ?? 'Unknown student',
      invoiceNo: detail?['invoice_no'] as String? ?? '',
      paymentDate: json['payment_date'] as String? ?? '',
      amountPaid: _parseAmount(json['amount_paid']),
      paymentMethod: json['payment_method'] as String? ?? '',
      referenceNumber: json['reference_number'] as String?,
      notes: json['notes'] as String?,
    );
  }

  final String paymentId;
  final String invoiceId;
  final String studentName;
  final String invoiceNo;
  final String paymentDate;
  final num amountPaid;
  final String paymentMethod;
  final String? referenceNumber;
  final String? notes;
}
