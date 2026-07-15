/// Shared role-string constants and role-group sets, mirroring the web
/// admin-portal's `STAFF_ADMIN`/`ACADEMIC_STAFF`/`GRADE_ROLES`/`BILLING_ROLES`
/// convention (`frontend/admin-portal/src/App.jsx` in the ASIA repo) so the
/// same 5 backend roles aren't hand-rolled independently across the app.
library;

const roleSuperAdmin = 'super_admin';
const roleAdmin = 'admin';
const roleRegistrar = 'registrar';
const roleTeacher = 'teacher';
const roleAccounting = 'accounting';

/// Assignable in identity-service but denied by every permission check in
/// every other backend service — dead/unimplemented. Only useful for label
/// maps, never for gating logic.
const roleGuardian = 'guardian';

/// Mirrors the web app's `STAFF_ADMIN`.
const staffAdmin = {roleSuperAdmin, roleAdmin};

/// Mirrors the web app's `ACADEMIC_STAFF`.
const academicStaff = {roleSuperAdmin, roleAdmin, roleRegistrar};

/// Mirrors the web app's `GRADE_ROLES`.
const gradeRoles = {roleSuperAdmin, roleAdmin, roleRegistrar, roleTeacher};

/// Mirrors the web app's `BILLING_ROLES`.
const billingRoles = {roleSuperAdmin, roleAdmin, roleAccounting};

/// Case-insensitive membership check, matching the web app's `hasAnyRole()`
/// convention. Backend role checks are case-sensitive lowercase
/// snake_case, but this normalizes before comparing to avoid a class of
/// bugs the backend itself isn't fully consistent about.
bool hasAnyRole(String? role, Set<String> group) {
  if (role == null) return false;
  final normalized = role.toLowerCase();
  return group.any((r) => r.toLowerCase() == normalized);
}
