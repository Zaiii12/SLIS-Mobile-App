import '../models/guardian_contact.dart';
import '../models/invoice.dart';
import 'billing_api.dart';

/// Thin pass-through over [BillingApi], matching the Dashboard/Students
/// repository pattern.
class BillingRepository {
  BillingRepository(this._api);

  final BillingApi _api;

  Future<InvoicesPage> fetchUnpaidInvoices({String? search, int page = 1}) {
    return _api.fetchInvoices(status: 'unpaid', search: search, page: page);
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
