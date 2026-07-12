import 'package:flutter_test/flutter_test.dart';

import 'package:slis_mobile/features/advisory/data/advisory_api.dart';
import 'package:slis_mobile/features/advisory/state/advisory_provider.dart';
import 'package:slis_mobile/features/auth/data/auth_api.dart';
import 'package:slis_mobile/features/auth/data/auth_repository.dart';
import 'package:slis_mobile/features/auth/state/auth_provider.dart';
import 'package:slis_mobile/features/auth/ui/login_screen.dart';
import 'package:slis_mobile/core/network/dio_client_factory.dart';
import 'package:slis_mobile/core/storage/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('login screen renders the design mock copy', (tester) async {
    final tokenStorage = TokenStorage();
    late final AuthRepository authRepository;
    final dioClientFactory = DioClientFactory(
      tokenStorage: tokenStorage,
      onUnauthorized: () => authRepository.refreshAccessToken(),
    );
    authRepository = AuthRepository(
      authApi: AuthApi(dioClientFactory.identity),
      tokenStorage: tokenStorage,
    );
    final advisoryProvider = AdvisoryProvider(
      advisoryApi: AdvisoryApi(dioClientFactory.enrollment),
    );

    // Renders LoginScreen directly (skipping SplashScreen, which reads
    // secure storage via a platform channel unavailable in widget tests).
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => AuthProvider(
          authRepository: authRepository,
          advisoryProvider: advisoryProvider,
        ),
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Good to see you again'), findsOneWidget);
    expect(find.text('South Lakes Integrated School'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
