import 'package:dio/dio.dart';

import '../models/audit_log_entry.dart';

/// A single page of `/api/audit-logs/` results. identity-service paginates at
/// 20/page (`AuditLogPagination`, `accounts/views.py`) with standard DRF
/// `{count, next, previous, results}` shape.
class AuditLogPage {
  const AuditLogPage({required this.entries, required this.hasMore});

  final List<AuditLogEntry> entries;
  final bool hasMore;
}

/// Calls identity-service's `GET /api/auth/audit-logs/` (`AuditLogListView`,
/// `accounts/views.py:363`, mounted under `api/auth/` per
/// `identity_service/urls.py` + `accounts/urls.py` — same prefix as
/// `/api/auth/users/` in TeachersApi), gated server-side to
/// `admin`/`super_admin` (`ADMIN_ROLES` in `accounts/audit.py`) — callers
/// must be one of those roles or this 403s.
class AuditLogApi {
  AuditLogApi(this._identity);

  final Dio _identity;

  /// `ordering` must be one of `occurred_at`/`user_role`/`module`/`status`
  /// (either direction, `-` prefix for desc) — anything else is silently
  /// ignored server-side and falls back to `-occurred_at`.
  Future<AuditLogPage> fetchAuditLogs({
    String? role,
    String? module,
    String? status,
    DateTime? date,
    String? timeFrom,
    String? timeTo,
    String ordering = '-occurred_at',
    int page = 1,
  }) async {
    final response = await _identity.get(
      '/api/auth/audit-logs/',
      queryParameters: {
        if (role != null && role.isNotEmpty) 'role': role,
        if (module != null && module.isNotEmpty) 'module': module,
        if (status != null && status.isNotEmpty) 'status': status,
        if (date != null)
          'date':
              '${date.year.toString().padLeft(4, '0')}-'
              '${date.month.toString().padLeft(2, '0')}-'
              '${date.day.toString().padLeft(2, '0')}',
        if (timeFrom != null && timeFrom.isNotEmpty) 'time_from': timeFrom,
        if (timeTo != null && timeTo.isNotEmpty) 'time_to': timeTo,
        'ordering': ordering,
        'page': page,
      },
    );
    final data = response.data;
    final results = data is Map<String, dynamic>
        ? data['results'] as List?
        : data as List?;
    final hasMore = data is Map<String, dynamic> && data['next'] != null;
    return AuditLogPage(
      entries: (results ?? [])
          .cast<Map<String, dynamic>>()
          .map(AuditLogEntry.fromJson)
          .toList(),
      hasMore: hasMore,
    );
  }
}
