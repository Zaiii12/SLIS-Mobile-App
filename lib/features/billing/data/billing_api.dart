import 'package:dio/dio.dart';

import '../models/guardian_contact.dart';
import '../models/invoice.dart';

/// A single page of `/api/invoices/` results. billing-service paginates at
/// 20/page (`PageNumberPagination`, `PAGE_SIZE=20` in billing_service/
/// settings.py) with standard DRF `{count, next, previous, results}` shape —
/// same pattern as StudentsApi/StudentsPage.
class InvoicesPage {
  const InvoicesPage({required this.invoices, required this.hasMore});

  final List<Invoice> invoices;
  final bool hasMore;
}

/// A single page of `/api/payments/` results — same pagination shape as
/// [InvoicesPage].
class PaymentsPage {
  const PaymentsPage({required this.payments, required this.hasMore});

  final List<PaymentRecord> payments;
  final bool hasMore;
}

/// Calls billing-service's invoice endpoints and, for guardian contact info
/// on the detail screen, a cross-service lookup against student-service.
///
/// Sort-by-balance is intentionally NOT sent to the backend: `balance` is a
/// SerializerMethodField on StudentInvoiceSerializer (computed across 3
/// joined tables), not a DB column, and StudentInvoiceViewSet.ordering_fields
/// only allows invoice_id/invoice_date/due_date (billing/views.py:119).
/// Confirmed the real ASIA web admin portal (InvoicesPage.jsx) already sends
/// `ordering: "balance"` to the API and has shipped with this silently
/// no-op-ing (DRF drops unrecognized `ordering` values and falls back to the
/// view's default `-invoice_id`) — i.e. the web app's balance sort has never
/// actually worked. Don't repeat that bug here: balance "sort" is applied
/// client-side on whatever page is already loaded (see
/// BillingRepository/UnpaidInvoicesListScreen), which is correct within a
/// page but not across pages — acceptable for a due-soonest triage list.
class BillingApi {
  BillingApi({required Dio billingClient, required Dio studentClient})
    : _billing = billingClient,
      _student = studentClient;

  final Dio _billing;
  final Dio _student;

  Future<InvoicesPage> fetchInvoices({
    String status = 'unpaid',
    String? search,
    int page = 1,
  }) async {
    final response = await _billing.get(
      '/api/invoices/',
      queryParameters: {
        'status': status,
        'ordering': 'due_date',
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    final hasMore = data is Map<String, dynamic> && data['next'] != null;
    return InvoicesPage(
      invoices: (results ?? [])
          .cast<Map<String, dynamic>>()
          .map(Invoice.fromJson)
          .toList(),
      hasMore: hasMore,
    );
  }

  Future<Invoice> fetchInvoiceDetail(String invoiceId) async {
    final response = await _billing.get('/api/invoices/$invoiceId/');
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  Future<FinancialSummary> fetchFinancialSummary({String? schoolYear}) async {
    final response = await _billing.get(
      '/api/invoices/financial-summary/',
      queryParameters: {
        if (schoolYear != null && schoolYear.isNotEmpty)
          'school_year': schoolYear,
      },
    );
    return FinancialSummary.fromJson(response.data as Map<String, dynamic>);
  }

  /// `GET /api/school-settings/current/` — billing-service's `SchoolSetting`
  /// singleton (matches ASIA web admin's `getSchoolSettings`), used to seed
  /// the global school-year filter's default. Returns null (rather than
  /// throwing) only if the field itself is missing/blank; any request
  /// failure propagates for the caller to handle.
  Future<String?> fetchCurrentSchoolYear() async {
    final response = await _billing.get('/api/school-settings/current/');
    final data = response.data as Map<String, dynamic>;
    return (data['current_school_year'] as String?)?.trim();
  }

  /// `GET /api/payments/` — read access, gated to `BILLING_ROLES`
  /// (`super_admin`/`admin`/`accounting`, `billing/views.py:489`).
  Future<PaymentsPage> fetchPayments({
    String? paymentMethod,
    int page = 1,
  }) async {
    final response = await _billing.get(
      '/api/payments/',
      queryParameters: {
        if (paymentMethod != null && paymentMethod.isNotEmpty)
          'payment_method': paymentMethod,
        'ordering': '-payment_date',
        'page': page,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    final hasMore = data is Map<String, dynamic> && data['next'] != null;
    return PaymentsPage(
      payments: (results ?? [])
          .cast<Map<String, dynamic>>()
          .map(PaymentRecord.fromJson)
          .toList(),
      hasMore: hasMore,
    );
  }

  /// `POST /api/payments/` — records a payment against one invoice.
  /// `payment_date` must be sent here: `StudentPayment.payment_date` has no
  /// `null=True`/`blank=True` and is not in `StudentPaymentSerializer`'s
  /// `read_only_fields`, so DRF rejects the request at validation time with
  /// `{"payment_date": ["This field is required."]}` before
  /// `perform_create()` ever runs its own today's-date default — omitting it
  /// previously caused every payment submission to fail this way regardless
  /// of what the user filled in, since the missing field isn't shown on this
  /// form at all. Server-side `apply_payment()` distributes the amount across
  /// installments and flips the invoice's `status` automatically; it also
  /// guards against overpayment itself (400 with a peso-formatted message
  /// comparing `amount_paid` against the computed `balance`), so no
  /// client-side balance check is duplicated here. Gated to `BILLING_ROLES`
  /// server-side (`billing/views.py`).
  Future<Invoice> recordPayment({
    required String invoiceId,
    required num amountPaid,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    final now = DateTime.now();
    final paymentDate =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    await _billing.post(
      '/api/payments/',
      data: {
        'invoice': invoiceId,
        'payment_date': paymentDate,
        'amount_paid': amountPaid,
        'payment_method': paymentMethod,
        if (referenceNumber != null && referenceNumber.isNotEmpty)
          'reference_number': referenceNumber,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
      },
    );
    return fetchInvoiceDetail(invoiceId);
  }

  /// `PATCH /api/payments/{id}/` — restricted to [paymentMethod]/
  /// [referenceNumber]/[notes] only. `amount_paid`/`payment_date`/`invoice`
  /// are deliberately never sent from this client even though
  /// `StudentPaymentSerializer` would accept them: `perform_create()` is the
  /// only place that calls `apply_payment()` to distribute an amount across
  /// installments and recompute the invoice's status — a plain
  /// `ModelViewSet.partial_update()` on this endpoint does NOT re-run it, so
  /// editing `amount_paid` here would silently desync the invoice's
  /// `status`/installment `amount_paid` from the payment history. Treat this
  /// as "acknowledge/correct how a payment was recorded," not "change how
  /// much was paid." Delete is intentionally not exposed for the same
  /// reason — removing a payment doesn't reverse `apply_payment()` either.
  Future<PaymentRecord> updatePayment({
    required String paymentId,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) async {
    final response = await _billing.patch(
      '/api/payments/$paymentId/',
      data: {
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (referenceNumber != null) 'reference_number': referenceNumber,
        if (notes != null) 'notes': notes,
      },
    );
    return PaymentRecord.fromJson(response.data as Map<String, dynamic>);
  }

  /// `POST /api/invoices/generate/` — idempotent: if an invoice already
  /// exists for this enrollment (any non-void status), the server returns
  /// that existing invoice instead of creating a duplicate
  /// (`generate_invoice_for_enrollment`, billing/services.py:319), so a
  /// retried/double tap can't create two invoices for the same enrollment.
  /// All fee items/discounts/installments are computed server-side from the
  /// enrollment's fee schedule — nothing else to send from the client.
  Future<Invoice> generateInvoice({
    required String enrollmentId,
    required String paymentPlan,
  }) async {
    final response = await _billing.post(
      '/api/invoices/generate/',
      data: {'enrollment_id': enrollmentId, 'payment_plan': paymentPlan},
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  /// `PATCH /api/invoices/{id}/` — restricted to [dueDate]/[paymentPlan]
  /// only. `status` is deliberately never sent from this client: it's the
  /// only other writable field on `StudentInvoiceSerializer`, but there's no
  /// dedicated void action or payment-reversal logic backing a raw
  /// `status: void` write (confirmed in billing/views.py), so that path
  /// stays unsafe for a mobile quick-edit and is intentionally not exposed.
  Future<Invoice> updateInvoice({
    required String invoiceId,
    String? dueDate,
    String? paymentPlan,
  }) async {
    final response = await _billing.patch(
      '/api/invoices/$invoiceId/',
      data: {
        if (dueDate != null) 'due_date': dueDate,
        if (paymentPlan != null) 'payment_plan': paymentPlan,
      },
    );
    return Invoice.fromJson(response.data as Map<String, dynamic>);
  }

  /// Resolves the primary guardian contact for an invoice's student.
  ///
  /// billing-service's `enrollment_detail` (StudentInvoiceSerializer) doesn't
  /// expose `student_id` — only `enrollment_id` and `lrn` — so there's no
  /// direct student_id to call student-service's `/api/guardians/` with.
  /// Workaround: LRN is unique on the Student model (student-service/
  /// students/models.py), so resolve student_id via
  /// `/api/students/?search=<lrn>` first, then fetch guardians for that id.
  /// Two network calls; only used on the detail screen (never the list — no
  /// bulk student_id__in filter exists on GuardianViewSet, so doing this per
  /// row in a paginated list would be N+1).
  Future<GuardianContact?> fetchPrimaryGuardian(String lrn) async {
    if (lrn.isEmpty) return null;

    final studentResponse = await _student.get(
      '/api/students/',
      queryParameters: {'search': lrn, 'page_size': 1},
    );
    final studentData = studentResponse.data;
    final studentResults = studentData is Map<String, dynamic>
        ? studentData['results'] as List?
        : null;
    if (studentResults == null || studentResults.isEmpty) return null;
    final studentId =
        (studentResults.first as Map<String, dynamic>)['student_id'];
    if (studentId == null) return null;

    final guardianResponse = await _student.get(
      '/api/guardians/',
      queryParameters: {'student_id': studentId},
    );
    final guardianData = guardianResponse.data;
    final guardianResults = guardianData is Map<String, dynamic>
        ? guardianData['results'] as List?
        : null;
    if (guardianResults == null || guardianResults.isEmpty) return null;

    final contacts = guardianResults
        .cast<Map<String, dynamic>>()
        .map(GuardianContact.fromJson)
        .toList();
    return contacts.firstWhere(
      (c) => c.isPrimaryContact,
      orElse: () => contacts.first,
    );
  }
}
