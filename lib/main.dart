import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/dio_client_factory.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/advisory/data/advisory_api.dart';
import 'features/advisory/state/advisory_provider.dart';
import 'features/attendance/data/attendance_api.dart';
import 'features/attendance/data/attendance_repository.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_provider.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/splash_screen.dart';
import 'features/billing/data/billing_api.dart';
import 'features/billing/data/billing_repository.dart';
import 'features/billing/data/enrollment_api.dart';
import 'features/billing/data/enrollment_repository.dart';
import 'features/calendar/data/calendar_api.dart';
import 'features/calendar/data/calendar_repository.dart';
import 'features/dashboard/data/dashboard_api.dart';
import 'features/dashboard/data/dashboard_repository.dart';
import 'features/grades/data/grades_api.dart';
import 'features/grades/data/grades_repository.dart';
import 'features/monitoring/data/audit_log_api.dart';
import 'features/monitoring/data/audit_log_repository.dart';
import 'features/monitoring/data/teachers_api.dart';
import 'features/monitoring/data/teachers_repository.dart';
import 'features/narrative/data/narrative_api.dart';
import 'features/narrative/data/narrative_repository.dart';
import 'features/settings/data/school_year_store.dart';
import 'features/settings/state/school_year_provider.dart';
import 'features/staff/data/staff_api.dart';
import 'features/staff/data/staff_repository.dart';
import 'features/students/data/students_api.dart';
import 'features/students/data/students_repository.dart';

/// Lets code with no [BuildContext] (the Dio interceptor, running deep
/// inside a repository call) force navigation back to [LoginScreen] when a
/// session is invalidated server-side.
final navigatorKey = GlobalKey<NavigatorState>();

/// Catches otherwise-uncaught errors (both Flutter framework errors and
/// async errors outside the widget tree) so a bug surfaces as a logged
/// error instead of silently dropping the app back to the home screen.
void main() {
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    developer.log(
      'Uncaught Flutter error',
      name: 'slis_mobile',
      error: details.exception,
      stackTrace: details.stack,
    );
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    developer.log(
      'Uncaught platform error',
      name: 'slis_mobile',
      error: error,
      stackTrace: stack,
    );
    return true;
  };

  runZonedGuarded(_runApp, (error, stack) {
    developer.log(
      'Uncaught zone error',
      name: 'slis_mobile',
      error: error,
      stackTrace: stack,
    );
  });
}

void _runApp() {
  final tokenStorage = TokenStorage();

  // AuthRepository is constructed after DioClientFactory but the factory's
  // interceptor needs a refresh callback that depends on AuthRepository —
  // resolved via a late-bound closure to break the cycle without a DI
  // framework.
  late final AuthRepository authRepository;

  // The factory builds 4 independent Dio clients, each with its own
  // AuthInterceptor, so a single request storm hitting several services at
  // once could call this more than once — guard so only the first actually
  // navigates/clears state.
  var sessionExpiryHandled = false;
  void onSessionExpired() {
    if (sessionExpiryHandled) return;
    sessionExpiryHandled = true;

    Future<void> run() async {
      final context = navigatorKey.currentContext;
      if (context == null) return;
      await context.read<AuthProvider>().forceLogout();

      final navigator = navigatorKey.currentState;
      if (navigator == null) return;
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }

    run().whenComplete(() => sessionExpiryHandled = false);
  }

  final dioClientFactory = DioClientFactory(
    tokenStorage: tokenStorage,
    onUnauthorized: () => authRepository.refreshAccessToken(),
    onSessionExpired: onSessionExpired,
  );
  authRepository = AuthRepository(
    authApi: AuthApi(dioClientFactory.identity),
    tokenStorage: tokenStorage,
  );

  final dashboardRepository = DashboardRepository(
    DashboardApi(
      studentClient: dioClientFactory.student,
      enrollmentClient: dioClientFactory.enrollment,
      billingClient: dioClientFactory.billing,
    ),
  );

  final billingRepository = BillingRepository(
    BillingApi(
      billingClient: dioClientFactory.billing,
      studentClient: dioClientFactory.student,
    ),
  );

  final enrollmentRepository = EnrollmentRepository(
    EnrollmentApi(
      enrollmentClient: dioClientFactory.enrollment,
      studentClient: dioClientFactory.student,
    ),
  );

  final advisoryApi = AdvisoryApi(dioClientFactory.enrollment);
  final advisoryProvider = AdvisoryProvider(advisoryApi: advisoryApi);

  final teachersRepository = TeachersRepository(
    TeachersApi(dioClientFactory.identity),
  );

  final auditLogRepository = AuditLogRepository(
    AuditLogApi(dioClientFactory.identity),
  );

  final calendarRepository = CalendarRepository(
    CalendarApi(dioClientFactory.enrollment),
  );

  final studentsRepository = StudentsRepository(
    StudentsApi(dioClientFactory.student),
  );

  final attendanceRepository = AttendanceRepository(
    AttendanceApi(dioClientFactory.enrollment),
  );

  final gradesRepository = GradesRepository(
    GradesApi(dioClientFactory.enrollment),
  );

  final narrativeRepository = NarrativeRepository(
    NarrativeApi(dioClientFactory.enrollment),
  );

  final staffRepository = StaffRepository(
    StaffApi(dioClientFactory.identity),
  );

  final schoolYearProvider = SchoolYearProvider(
    billingRepository: billingRepository,
    store: SchoolYearStore(),
  );

  runApp(
    SlisMobileApp(
      authRepository: authRepository,
      dashboardRepository: dashboardRepository,
      billingRepository: billingRepository,
      enrollmentRepository: enrollmentRepository,
      advisoryProvider: advisoryProvider,
      advisoryApi: advisoryApi,
      studentsRepository: studentsRepository,
      attendanceRepository: attendanceRepository,
      gradesRepository: gradesRepository,
      teachersRepository: teachersRepository,
      auditLogRepository: auditLogRepository,
      calendarRepository: calendarRepository,
      narrativeRepository: narrativeRepository,
      staffRepository: staffRepository,
      schoolYearProvider: schoolYearProvider,
    ),
  );
}

class SlisMobileApp extends StatefulWidget {
  const SlisMobileApp({
    super.key,
    required this.authRepository,
    required this.dashboardRepository,
    required this.billingRepository,
    required this.enrollmentRepository,
    required this.advisoryProvider,
    required this.advisoryApi,
    required this.studentsRepository,
    required this.attendanceRepository,
    required this.gradesRepository,
    required this.teachersRepository,
    required this.auditLogRepository,
    required this.calendarRepository,
    required this.narrativeRepository,
    required this.staffRepository,
    required this.schoolYearProvider,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final BillingRepository billingRepository;
  final EnrollmentRepository enrollmentRepository;
  final AdvisoryProvider advisoryProvider;
  final AdvisoryApi advisoryApi;
  final StudentsRepository studentsRepository;
  final AttendanceRepository attendanceRepository;
  final GradesRepository gradesRepository;
  final TeachersRepository teachersRepository;
  final AuditLogRepository auditLogRepository;
  final CalendarRepository calendarRepository;
  final NarrativeRepository narrativeRepository;
  final StaffRepository staffRepository;
  final SchoolYearProvider schoolYearProvider;

  @override
  State<SlisMobileApp> createState() => _SlisMobileAppState();
}

/// Session invalidation is otherwise only discovered reactively — via a 401
/// on some real API call (see [AuthInterceptor]) — which never fires while
/// the user is idle on a tab that isn't making requests (`AppShell` keeps
/// all visited tabs alive in an `IndexedStack`, so merely sitting on one
/// triggers nothing further). Re-validating whenever the app comes back to
/// the foreground closes that gap: e.g. logging in elsewhere while this app
/// is backgrounded is now caught as soon as the user returns to it, instead
/// of only on the next unrelated request.
class _SlisMobileAppState extends State<SlisMobileApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    final authProvider = navigatorKey.currentContext?.read<AuthProvider>();
    if (authProvider == null || authProvider.status != AuthStatus.authenticated)
      return;

    unawaited(_revalidateSession());
  }

  Future<void> _revalidateSession() async {
    final newToken = await widget.authRepository.refreshAccessToken();
    if (newToken != null) return;

    // Refresh failed on resume — most likely this session was superseded by
    // a login elsewhere while the app was backgrounded. Route through the
    // same forced-logout path the 401 interceptor uses.
    final context = navigatorKey.currentContext;
    if (context == null) return;
    await context.read<AuthProvider>().forceLogout();

    final navigator = navigatorKey.currentState;
    navigator?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.advisoryProvider),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authRepository: widget.authRepository,
            advisoryProvider: widget.advisoryProvider,
          ),
        ),
        Provider.value(value: widget.dashboardRepository),
        Provider.value(value: widget.billingRepository),
        Provider.value(value: widget.enrollmentRepository),
        Provider.value(value: widget.advisoryApi),
        Provider.value(value: widget.studentsRepository),
        Provider.value(value: widget.attendanceRepository),
        Provider.value(value: widget.gradesRepository),
        Provider.value(value: widget.teachersRepository),
        Provider.value(value: widget.auditLogRepository),
        Provider.value(value: widget.calendarRepository),
        Provider.value(value: widget.narrativeRepository),
        Provider.value(value: widget.staffRepository),
        ChangeNotifierProvider.value(value: widget.schoolYearProvider),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'ASIA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
