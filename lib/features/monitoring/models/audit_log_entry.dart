/// Mirrors identity-service's `AuditLogSerializer` (`accounts/serializers.py:212`).
/// `action`/`details` are server-humanized (SerializerMethodFields), not raw
/// enum codes — safe to render directly.
class AuditLogEntry {
  const AuditLogEntry({
    required this.logId,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.action,
    required this.module,
    required this.occurredAt,
    required this.status,
    required this.details,
    required this.ipAddress,
    required this.metadata,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    return AuditLogEntry(
      logId: json['log_id'].toString(),
      userId: json['user_id']?.toString(),
      userName: json['user_name'] as String? ?? 'Unknown user',
      userRole: json['user_role'] as String? ?? 'unknown',
      action: json['action'] as String? ?? '',
      module: json['module'] as String? ?? '',
      occurredAt: json['occurred_at'] as String? ?? '',
      status: json['status'] as String? ?? 'success',
      details: json['details'] as String? ?? '',
      ipAddress: json['ip_address'] as String?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
  }

  final String logId;
  final String? userId;
  final String userName;
  final String userRole;
  final String action;
  final String module;
  final String occurredAt;
  final String status;
  final String details;
  final String? ipAddress;
  final Map<String, dynamic> metadata;
}
