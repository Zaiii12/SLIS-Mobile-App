import 'audit_log_api.dart';

/// Thin pass-through over [AuditLogApi], matching the Dashboard/Billing
/// repository pattern.
class AuditLogRepository {
  AuditLogRepository(this._api);

  final AuditLogApi _api;

  Future<AuditLogPage> fetchAuditLogs({
    String? role,
    String? module,
    String? status,
    DateTime? date,
    String? timeFrom,
    String? timeTo,
    String ordering = '-occurred_at',
    int page = 1,
  }) {
    return _api.fetchAuditLogs(
      role: role,
      module: module,
      status: status,
      date: date,
      timeFrom: timeFrom,
      timeTo: timeTo,
      ordering: ordering,
      page: page,
    );
  }
}
