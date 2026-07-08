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

  /// Validates any stored token on app launch via a refresh call, so a
  /// stale/expired token (e.g. left over from a prior install) doesn't
  /// route straight to the dashboard. Does not re-fetch the user profile
  /// (no confirmed `/me/` endpoint yet), so `_user` stays null after a
  /// restored session until the next successful login.
  Future<void> tryRestoreSession() async {
    bool restored = false;
    try {
      restored = await _authRepository
          .restoreSession()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      restored = false;
    }
    _status = restored ? AuthStatus.authenticated : AuthStatus.unauthenticated;
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
