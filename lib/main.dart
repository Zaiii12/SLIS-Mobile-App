import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/network/dio_client_factory.dart';
import 'core/storage/token_storage.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_api.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/state/auth_provider.dart';
import 'features/auth/ui/splash_screen.dart';

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

  runApp(SlisMobileApp(authRepository: authRepository));
}

class SlisMobileApp extends StatelessWidget {
  const SlisMobileApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider(authRepository: authRepository),
      child: MaterialApp(
        title: 'ASIA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const SplashScreen(),
      ),
    );
  }
}
