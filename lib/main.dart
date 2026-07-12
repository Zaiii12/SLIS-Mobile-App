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
import 'features/auth/ui/splash_screen.dart';
import 'features/dashboard/data/dashboard_api.dart';
import 'features/dashboard/data/dashboard_repository.dart';
import 'features/grades/data/grades_api.dart';
import 'features/grades/data/grades_repository.dart';
import 'features/students/data/students_api.dart';
import 'features/students/data/students_repository.dart';

void main() {
  final tokenStorage = TokenStorage();

  // AuthRepository is constructed after DioClientFactory but the factory's
  // interceptor needs a refresh callback that depends on AuthRepository —
  // resolved via a late-bound closure to break the cycle without a DI
  // framework.
  late final AuthRepository authRepository;
  final dioClientFactory = DioClientFactory(
    tokenStorage: tokenStorage,
    onUnauthorized: () => authRepository.refreshAccessToken(),
  );
  authRepository = AuthRepository(
    authApi: AuthApi(dioClientFactory.identity),
    tokenStorage: tokenStorage,
  );

  final dashboardRepository = DashboardRepository(
    DashboardApi(
      studentClient: dioClientFactory.student,
      enrollmentClient: dioClientFactory.enrollment,
    ),
  );

  final advisoryProvider = AdvisoryProvider(
    advisoryApi: AdvisoryApi(dioClientFactory.enrollment),
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

  runApp(
    SlisMobileApp(
      authRepository: authRepository,
      dashboardRepository: dashboardRepository,
      advisoryProvider: advisoryProvider,
      studentsRepository: studentsRepository,
      attendanceRepository: attendanceRepository,
      gradesRepository: gradesRepository,
    ),
  );
}

class SlisMobileApp extends StatelessWidget {
  const SlisMobileApp({
    super.key,
    required this.authRepository,
    required this.dashboardRepository,
    required this.advisoryProvider,
    required this.studentsRepository,
    required this.attendanceRepository,
    required this.gradesRepository,
  });

  final AuthRepository authRepository;
  final DashboardRepository dashboardRepository;
  final AdvisoryProvider advisoryProvider;
  final StudentsRepository studentsRepository;
  final AttendanceRepository attendanceRepository;
  final GradesRepository gradesRepository;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: advisoryProvider),
        ChangeNotifierProvider(
          create: (_) => AuthProvider(
            authRepository: authRepository,
            advisoryProvider: advisoryProvider,
          ),
        ),
        Provider.value(value: dashboardRepository),
        Provider.value(value: studentsRepository),
        Provider.value(value: attendanceRepository),
        Provider.value(value: gradesRepository),
      ],
      child: MaterialApp(
        title: 'ASIA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
