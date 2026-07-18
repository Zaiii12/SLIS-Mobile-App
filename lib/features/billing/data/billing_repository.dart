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
}
