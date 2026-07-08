/// Base URLs for ASIA's 4 independent Django services.
///
/// There is no API gateway, so each service is reached directly on its own
/// host/port. Override per developer machine with:
///   flutter run \
///     --dart-define=IDENTITY_BASE_URL=http://`lan-ip`:8001 \
///     --dart-define=STUDENT_BASE_URL=http://`lan-ip`:8000 \
///     --dart-define=ENROLLMENT_BASE_URL=http://`lan-ip`:8003 \
///     --dart-define=BILLING_BASE_URL=http://`lan-ip`:8002
///
/// The localhost defaults only work from a simulator running on the same
/// machine as the backend; a physical device needs the LAN IP override.
class ApiConfig {
  ApiConfig._();

  static const identityBaseUrl = String.fromEnvironment(
    'IDENTITY_BASE_URL',
    defaultValue: 'http://localhost:8001',
  );

  static const studentBaseUrl = String.fromEnvironment(
    'STUDENT_BASE_URL',
    defaultValue: 'http://localhost:8000',
  );

  static const enrollmentBaseUrl = String.fromEnvironment(
    'ENROLLMENT_BASE_URL',
    defaultValue: 'http://localhost:8003',
  );

  static const billingBaseUrl = String.fromEnvironment(
    'BILLING_BASE_URL',
    defaultValue: 'http://localhost:8002',
  );
}
