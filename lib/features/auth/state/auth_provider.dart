import 'package:flutter/foundation.dart';

import '../data/auth_repository.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;

  /// Checks for a stored token on app launch. Does not re-fetch the user
  /// profile (no confirmed `/me/` endpoint yet), so `_user` stays null after
  /// a restored session until the next successful login.
  Future<void> tryRestoreSession() async {
    final hasSession = await _authRepository.hasStoredSession();
    _status = hasSession ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<bool> login({required String identifier, required String password}) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authRepository.login(identifier: identifier, password: password);
      _user = user;
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      _errorMessage = 'Invalid credentials or unable to reach the server.';
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
