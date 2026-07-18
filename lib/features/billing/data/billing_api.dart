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
