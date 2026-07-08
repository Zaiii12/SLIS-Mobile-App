import 'dart:io' show Platform;

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
/// The localhost defaults only work from the iOS simulator, which shares the
/// host Mac's network stack. The Android emulator runs its own virtual
/// network where "localhost" means the emulator itself, so it needs the
/// special 10.0.2.2 alias to reach the host machine instead. A physical
/// device needs the LAN IP override regardless of platform.
class ApiConfig {
  ApiConfig._();

  static String get _defaultHost =>
      Platform.isAndroid ? '10.0.2.2' : 'localhost';

  static String _resolve(String override, int port) =>
      override.isNotEmpty ? override : 'http://$_defaultHost:$port';

  static String get identityBaseUrl => _resolve(
    const String.fromEnvironment('IDENTITY_BASE_URL'),
    8001,
  );

  static String get studentBaseUrl => _resolve(
    const String.fromEnvironment('STUDENT_BASE_URL'),
    8000,
  );

  static String get enrollmentBaseUrl => _resolve(
    const String.fromEnvironment('ENROLLMENT_BASE_URL'),
    8003,
  );

  static String get billingBaseUrl => _resolve(
    const String.fromEnvironment('BILLING_BASE_URL'),
    8002,
  );
}
