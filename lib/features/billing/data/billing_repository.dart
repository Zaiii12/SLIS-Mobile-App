import '../models/guardian_contact.dart';
import '../models/invoice.dart';
import 'billing_api.dart';

/// Thin pass-through over [BillingApi], matching the Dashboard/Students
/// repository pattern.
class BillingRepository {
  BillingRepository(this._api);

  final BillingApi _api;

  /// "Unpaid" here means "still has a balance owed" — `unpaid` AND
  /// `partially_paid` invoices, not just the literal `status="unpaid"` rows.
  /// `apply_payment()` (billing/services.py) flips an invoice's status to
  /// `partially_paid` the moment any payment less than the full balance is
  /// recorded, so treating `unpaid` alone as "outstanding" would silently
  /// drop every invoice the instant it received its first partial payment.
  /// `StudentInvoiceViewSet.filterset_fields` only does exact-match on
  /// `status` (plain django-filter `CharFilter`, no `in`/multi-value
  /// support), so this fetches both statuses as separate requests and merges
  /// them client-side rather than sending a comma-joined value the backend
  /// would silently match zero rows against.
  Future<InvoicesPage> fetchUnpaidInvoices({String? search, int page = 1}) async {
    final results = await Future.wait([
      _api.fetchInvoices(status: 'unpaid', search: search, page: page),
      _api.fetchInvoices(status: 'partially_paid', search: search, page: page),
    ]);
    final combined = [...results[0].invoices, ...results[1].invoices]
      ..sort((a, b) => (a.dueDate ?? '').compareTo(b.dueDate ?? ''));
    return InvoicesPage(
      invoices: combined,
      hasMore: results[0].hasMore || results[1].hasMore,
    );
  }

  Future<Invoice> fetchInvoiceDetail(String invoiceId) {
    return _api.fetchInvoiceDetail(invoiceId);
  }

  Future<GuardianContact?> fetchPrimaryGuardian(String lrn) {
    return _api.fetchPrimaryGuardian(lrn);
  }

  Future<FinancialSummary> fetchFinancialSummary({String? schoolYear}) {
    return _api.fetchFinancialSummary(schoolYear: schoolYear);
  }

  Future<String?> fetchCurrentSchoolYear() => _api.fetchCurrentSchoolYear();

  Future<PaymentsPage> fetchPayments({String? paymentMethod, int page = 1}) {
    return _api.fetchPayments(paymentMethod: paymentMethod, page: page);
  }

  Future<Invoice> recordPayment({
    required String invoiceId,
    required num amountPaid,
    required String paymentMethod,
    String? referenceNumber,
    String? notes,
  }) {
    return _api.recordPayment(
      invoiceId: invoiceId,
      amountPaid: amountPaid,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
      notes: notes,
    );
  }

  Future<Invoice> generateInvoice({
    required String enrollmentId,
    required String paymentPlan,
  }) {
    return _api.generateInvoice(
      enrollmentId: enrollmentId,
      paymentPlan: paymentPlan,
    );
  }

  Future<Invoice> updateInvoice({
    required String invoiceId,
    String? dueDate,
    String? paymentPlan,
  }) {
    return _api.updateInvoice(
      invoiceId: invoiceId,
      dueDate: dueDate,
      paymentPlan: paymentPlan,
    );
  }

  Future<PaymentRecord> updatePayment({
    required String paymentId,
    String? paymentMethod,
    String? referenceNumber,
    String? notes,
  }) {
    return _api.updatePayment(
      paymentId: paymentId,
      paymentMethod: paymentMethod,
      referenceNumber: referenceNumber,
      notes: notes,
    );
  }
}
