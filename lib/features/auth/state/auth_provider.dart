import 'package:flutter/foundation.dart';

import '../../../core/auth/roles.dart';
import '../../advisory/state/advisory_provider.dart';
import '../data/auth_repository.dart';
import '../models/user.dart';

enum AuthStatus { unknown, authenticating, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository authRepository,
    required AdvisoryProvider advisoryProvider,
  })  : _authRepository = authRepository,
        _advisoryProvider = advisoryProvider;

  final AuthRepository _authRepository;
  final AdvisoryProvider _advisoryProvider;

  AuthStatus _status = AuthStatus.unknown;
  User? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  User? get user => _user;
  String? get errorMessage => _errorMessage;

  /// Validates any stored token on app launch via a refresh call, so a
  /// stale/expired token (e.g. left over from a prior install) doesn't
  /// route straight to the dashboard. Also re-fetches the user profile via
  /// `GET /api/auth/users/<id>/` so `_user.role` reflects any server-side
  /// change made since the last login (see RBAC handoff, Blocker 2).
  Future<void> tryRestoreSession() async {
    User? restoredUser;
    try {
      restoredUser = await _authRepository
          .restoreSession()
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      restoredUser = null;
    }
    _user = restoredUser;
    _status = restoredUser != null ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();
    if (restoredUser != null) _loadAdvisoryFor(restoredUser);
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
      _loadAdvisoryFor(user);
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
    _advisoryProvider.clear();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Kicks off (without awaiting) the shared advisory fetch for roles that
  /// have Attendance/Grades access. Teacher requests are scoped to their
  /// own sections; staff roles get every section school-wide.
  void _loadAdvisoryFor(User user) {
    if (!hasAnyRole(user.role, gradeRoles)) return;
    final teacherUserId = user.role == roleTeacher ? int.tryParse(user.id) : null;
    _advisoryProvider.load(teacherUserId: teacherUserId);
  }
}
