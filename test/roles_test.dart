import 'package:flutter_test/flutter_test.dart';
import 'package:slis_mobile/core/auth/roles.dart';

void main() {
  group('hasAnyRole', () {
    test('matches exact-case membership', () {
      expect(hasAnyRole(roleTeacher, gradeRoles), isTrue);
      expect(hasAnyRole(roleAccounting, gradeRoles), isFalse);
    });

    test('is case-insensitive', () {
      expect(hasAnyRole('TEACHER', gradeRoles), isTrue);
      expect(hasAnyRole('Super_Admin', staffAdmin), isTrue);
    });

    test('returns false for null role', () {
      expect(hasAnyRole(null, gradeRoles), isFalse);
    });

    test('returns false for unknown or guardian role', () {
      expect(hasAnyRole(roleGuardian, gradeRoles), isFalse);
      expect(hasAnyRole('bogus', gradeRoles), isFalse);
    });
  });

  test('role groups nest as expected', () {
    expect(staffAdmin, {roleSuperAdmin, roleAdmin});
    expect(academicStaff, {roleSuperAdmin, roleAdmin, roleRegistrar});
    expect(gradeRoles, {roleSuperAdmin, roleAdmin, roleRegistrar, roleTeacher});
    expect(billingRoles, {roleSuperAdmin, roleAdmin, roleAccounting});
  });
}
