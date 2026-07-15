# RBAC Gaps — Implementation Plan

Written 2026-07-15. Source: a full ground-truth pass comparing the ASIA Django
backend's enforced RBAC (`~/Documents/GitHub/ASIA`, commit `20610d2` "added rbac")
against this app's current state. Live login has been confirmed working for
`registrar`, `teacher`, and `accounting` test accounts as of 2026-07-15;
`admin`/`super_admin` have not been explicitly confirmed live yet.

Backend has 5 functioning roles: `super_admin`, `admin`, `registrar`, `teacher`,
`accounting`. A 6th role, `guardian`, is assignable in `identity-service` but is
denied by every permission check in every other service — it is dead/unimplemented
on the backend. **Do not build guardian-specific screens.** The app already
correctly collapses `guardian` into its generic "unknown role" default.

Suggested order: **#5 → #1 → #3 → #6 → #7 → (#2 or #4)**. #5 and #1 (#1 is
already done, see below) are prep/insurance work that make #3 cleaner to
implement. #3 is a correctness fix for a real bug in production behavior
today. #6 and #7 are small, self-contained tab/dashboard-content fixes found
in follow-up review passes (2026-07-15). #2 and #4 are net-new feature
builds — pick based on which role's gap matters more to unblock next.

**Status as of 2026-07-15: Gap 1 done, Gap 6 done, Gap 7 done.**

---

## Gap 1 — No shared role-group constants (refactor, low risk) — DONE

Confirmed done as of 2026-07-15 (found already implemented when re-checking
this file during Gap 6 follow-up work — not done in a session that updated
this plan doc, so it's recorded here after the fact). `lib/core/auth/roles.dart`
exists with the exact shape proposed below: role string constants
(`roleSuperAdmin`, `roleAdmin`, `roleRegistrar`, `roleTeacher`,
`roleAccounting`, `roleGuardian`), the 4 named role-group sets (`staffAdmin`,
`academicStaff`, `gradeRoles`, `billingRoles`), and a case-insensitive
`hasAnyRole(role, group)` helper. All 5 original call sites migrated:
`app_shell.dart:23` (`_visibleTabsForRole`, now just
`hasAnyRole(role, gradeRoles) ? ShellTab.values : [dashboard, more]`),
`dashboard_screen.dart:131,157-169` (stale-data gate + body dispatch switch,
now using the constants instead of string literals), `auth_provider.dart:80-81`
(advisory-fetch gate, now `hasAnyRole(user.role, gradeRoles)`), and
`more_screen.dart:11-16` (role-label map keys). Verified via grep — no
remaining hardcoded role-string literals at any of the original 5 sites.

**Problem:** the same 5 role strings are independently hand-rolled in 5 places
with no shared source of truth. The web admin-portal
(`frontend/admin-portal/src/App.jsx:43-46` in the ASIA repo) already defines
named role-group constants (`STAFF_ADMIN`, `ACADEMIC_STAFF`, `GRADE_ROLES`,
`BILLING_ROLES`) and a case-insensitive `hasAnyRole()` helper
(`utils/auth.js`) — this app should mirror that pattern. Backend role checks
are case-sensitive lowercase snake_case; normalize before comparing to avoid a
class of bugs the backend itself isn't fully consistent about.

**Current duplicated logic (exact code, as of 2026-07-15):**

1. `lib/features/shell/ui/app_shell.dart:22-34` — tab visibility:
   ```dart
   List<ShellTab> _visibleTabsForRole(String role) {
     switch (role) {
       case 'accounting':
         return [ShellTab.dashboard, ShellTab.more];
       case 'teacher':
       case 'registrar':
       case 'admin':
       case 'super_admin':
         return ShellTab.values;
       default:
         return [ShellTab.dashboard, ShellTab.more];
     }
   }
   ```
   Called at line 79: `final visibleTabs = _visibleTabsForRole(role);`, where
   `role` comes from line 78: `context.watch<AuthProvider>().user?.role ?? ''`.

2. `lib/features/dashboard/ui/dashboard_screen.dart:130` — stale-data banner gate:
   ```dart
   final showsLiveData = role != 'super_admin' && role != 'accounting';
   ```

3. `lib/features/dashboard/ui/dashboard_screen.dart:154-173` — dashboard body dispatch:
   ```dart
   Widget _buildBodyForRole(String role, DashboardData data, DateTime today) {
     switch (role) {
       case 'teacher':
         return _TeacherBody(...);
       case 'super_admin':
         return const _SuperAdminBody();
       case 'registrar':
         return _RegistrarBody(data: data, today: today);
       case 'admin':
         return _StaffBody(data: data, today: today);
       case 'accounting':
         return const _AccountingBody();
       default:
         return _StaffBody(data: data, today: today);
     }
   }
   ```

4. `lib/features/auth/state/auth_provider.dart:9-12,84-85` — advisory-fetch gate:
   ```dart
   const _rolesNeedingAdvisory = {'teacher', 'registrar', 'admin', 'super_admin'};
   ...
   void _loadAdvisoryFor(User user) {
     if (!_rolesNeedingAdvisory.contains(user.role)) return;
     final teacherUserId = user.role == 'teacher' ? int.tryParse(user.id) : null;
     _advisoryProvider.load(teacherUserId: teacherUserId);
   }
   ```

5. `lib/features/shell/ui/more_screen.dart:9-16,36` — display-label map (lower risk,
   include for completeness):
   ```dart
   const _roleLabels = {
     'teacher': 'Teacher',
     'registrar': 'Registrar',
     'admin': 'Admin',
     'super_admin': 'Super Admin',
     'accounting': 'Accounting',
     'guardian': 'Guardian',
   };
   ...
   final roleLabel = _roleLabels[user?.role] ?? user?.role ?? '';
   ```

**What to build:**

- New file `lib/core/auth/roles.dart` with:
  - String constants for the 5 role literals (`roleSuperAdmin`, `roleAdmin`,
    `roleRegistrar`, `roleTeacher`, `roleAccounting` — plus `roleGuardian` if
    useful for the label map, but never for gating logic).
  - Named `Set<String>` role groups mirroring the web app: `staffAdmin`
    (`super_admin`, `admin`), `academicStaff` (adds `registrar`), `gradeRoles`
    (adds `teacher`), `billingRoles` (`super_admin`, `admin`, `accounting`).
  - A `hasAnyRole(String? role, Set<String> group)` helper doing
    case-insensitive comparison (lowercase both sides before checking
    membership), matching the web app's `hasAnyRole()` convention.
- Replace all 5 call sites above to use the shared constants/helper instead of
  literal strings. This should be a behavior-preserving refactor — verify each
  replacement produces the identical role→outcome mapping as the code it
  replaces (e.g. `_visibleTabsForRole`'s `default` case, which covers unknown
  roles AND `guardian`, must still fall through to `[dashboard, more]`).
- Run existing tests + `flutter analyze` after, since this touches 5 files with
  no test coverage currently guarding this logic — consider adding a small
  unit test on the new `roles.dart` helper itself.

---

## Gap 2 — Narrative Reports feature (net-new, medium-large)

**Problem:** the backend has a fully built and enforced Narrative Reports
feature (`NarrativeReportViewSet` / `NarrativeCategoryViewSet` in
enrollment-service, gated by `IsAdvisoryTeacherOrStaff` /
`IsAdminRegistrarOrReadOnly` respectively — same advisory-scoping model as
Grades/Attendance) but the mobile app has **zero code for it**. Confirmed via
repo-wide case-insensitive grep for "narrative" across `lib/` — zero matches.
This is the clearest missing capability for the `teacher` role, which is
otherwise the app's primary/best-supported user.

**Backend shape to build against** (from `~/Documents/GitHub/ASIA`,
enrollment-service):
- `GET/POST /api/narrative-categories/` — `IsAdminRegistrarOrReadOnly` (any
  authenticated role reads; only admin/registrar/super_admin writes)
- `GET/POST/PATCH/DELETE /api/narrative-reports/` — `IsAdvisoryTeacherOrStaff`:
  super_admin/admin full read+write any student; registrar read-only any
  student; teacher read+write scoped to their own `SectionAdvisory` via
  `teacher_student_ids()` (empty set / fails closed if no advisory assigned);
  accounting fully denied even read.
- Confirm exact field names on the live `NarrativeReport`/`NarrativeCategory`
  serializers before writing model classes — do not assume from the
  Grade/ScoreEntry field-naming pattern, verify directly
  (`enrollment-service/grades/serializers.py` and `models.py`, or a live
  `GET` sample) the way prior sessions did for Grades (see project memory
  `asia_backend_ground_truth.md` for the verification pattern used previously
  — get a real sample response before finalizing field names).

**Existing pattern to follow** (Grades feature, structurally closest analog —
read these files directly before starting, don't rely on this summary):
```
lib/features/grades/
  data/
    grades_api.dart          # GradesApi — one Dio instance via constructor,
                              # one method per endpoint, shared _resultsOf()
                              # helper to unwrap DRF's {results: [...]} envelope
    grades_repository.dart   # GradesRepository — thin 1:1 pass-through over
                              # the API, no caching/state
  models/
    graded_student.dart      # roster row + raw record classes, fromJson
    grading_component.dart
    grading_period.dart
    grading_template.dart
    score_entry.dart
    subject.dart
  ui/
    grades_screen.dart       # roster list: StatefulWidget, context.watch on
                              # AdvisoryProvider for section list, own
                              # _LoadStatus enum (loading/loaded/error),
                              # ListView.separated of _StudentRow, navigates
                              # to detail screen on tap
    grade_detail_screen.dart # per-student detail: StatefulWidget taking
                              # repository + contextual IDs as ctor params,
                              # own _LoadStatus, Save/Compute actions call
                              # repository, Navigator.pop(true) on success
```

**What to build:**

- New directory `lib/features/narrative_reports/` mirroring the structure
  above:
  - `data/narrative_reports_api.dart` — Dio calls against
    `/api/narrative-reports/` and `/api/narrative-categories/` on the
    enrollment-service client (`dioClientFactory.enrollment`, already wired).
  - `data/narrative_reports_repository.dart` — thin pass-through wrapper,
    matching `grades_repository.dart`'s shape.
  - `models/` — `NarrativeReport` + `NarrativeCategory` model classes with
    `fromJson`, field names verified against a live API sample (see above).
  - `ui/narrative_reports_screen.dart` — roster list, same
    advisory-scoped-section pattern as `grades_screen.dart`.
  - `ui/narrative_report_detail_screen.dart` — per-student entry/edit screen,
    same shape as `grade_detail_screen.dart`.
- Wire DI in `lib/main.dart` following the exact pattern used for
  `GradesApi`/`GradesRepository` (see `main.dart:17-18,58-60,90,106`):
  construct API with `dioClientFactory.enrollment`, wrap in repository, pass
  to `SlisMobileApp`, register via `Provider.value(...)` in the root
  `MultiProvider`.
- Add a nav slot in `lib/features/shell/ui/app_shell.dart`: the `ShellTab`
  enum (line 16) is currently `{dashboard, students, attendance, grades,
  more}` — either add a new tab value (requires updating
  `_visibleTabsForRole`/Gap 1's new helper, `shell_bottom_nav_bar.dart`, and
  the `IndexedStack` construction), or surface Narrative Reports as a
  secondary destination reached from within the Grades tab / a student detail
  screen rather than a 6th bottom-nav slot — worth a product decision before
  building, since 6 bottom-nav items may be too many. Flag this choice to the
  user before committing to one.
- Apply the same role scoping as Grades: teacher gets read+write scoped to
  advisory; registrar gets read-only (see Gap 3 — build the write-guard in
  from the start here rather than retrofitting it, since Gap 3's fix is
  already known at build time for this new feature); accounting gets no
  access at all (should not even appear as a possibility, not just a
  disabled button, matching backend's full 403-even-on-read for this role).

---

## Gap 3 — Registrar write-guard on Attendance/Grades (correctness fix, small)

**Problem:** this is a real bug, not a missing feature. The backend enforces
`registrar` as read-only on grades/attendance (`IsAdvisoryTeacherOrStaff`
grants registrar `SAFE_METHODS` only; writes require `teacher`-within-advisory
or `admin`/`super_admin`). The mobile app currently has **no role check at
all** on these screens — a registrar sees the exact same live Save/Submit
buttons a teacher does, taps them, and only discovers the write is rejected
when the backend 403s, with no explanation shown. This should be fixed as a
correctness issue, independent of any new feature work.

**Confirmed: none of the 4 relevant screens currently import or read
`AuthProvider`.** Role is not threaded from `AppShell` into these widgets
today — `AppShell` reads `AuthProvider.user?.role` itself (line 78, for tab
visibility) but only passes `repository` into `AttendanceScreen`/`GradesScreen`
(`app_shell.dart:98,102`), not role. Since `AuthProvider` is registered
app-wide via `ChangeNotifierProvider` in the root `MultiProvider`
(`lib/main.dart:96-102`), the simplest fix is adding
`context.watch<AuthProvider>()` directly inside the 2 screens that actually
have write actions, rather than threading a new constructor param through 2
navigation levels.

**Exact write actions to gate:**

1. `lib/features/attendance/ui/attendance_roster_screen.dart`
   - Line 192: `ElevatedButton` inside `_buildSubmitBar()` (lines 188-204),
     `onPressed: _submitting ? null : _submit`, label `'Submit Attendance
     (${_marks.length} marked)'`. `_submit()` (lines 85-98) calls
     `widget.repository.submitBulk(...)`.
   - **Fix:** add `context.watch<AuthProvider>()` import + call, compute
     `final canEdit = hasAnyRole(role, gradeWriteRoles)` (using Gap 1's
     helper if built first — or inline check for `role == 'teacher' ||
     role == 'admin' || role == 'super_admin'` if Gap 1 isn't done yet),
     change `onPressed` to `(!canEdit || _submitting) ? null : _submit`.
   - Also add a visible reason, not just a disabled button — e.g. a small
     banner or `SnackBar`-on-tap-attempt explaining "Registrars can view
     attendance but not submit it." A silently-disabled button with no
     explanation is a UX dead-end, not a real fix.

2. `lib/features/grades/ui/grade_detail_screen.dart` — 3 separate write
   actions on this one screen:
   - Line 613: **Save Grade** `ElevatedButton` inside `_FinalGradeCard`
     (lines 542-705), wired at line 255 via `onSave: _computed?.remarks ==
     null ? null : _save`. `_save()` (lines 182-207) calls
     `widget.repository.saveGrade(...)`.
   - Line 422: per-component **Add/Save** button (label toggles based on
     `isEditing`), wired to `onAdd` → `_addOrUpdateEntry` (line 93), which
     POSTs/PATCHes score entries.
   - Line 528: **delete** icon button, `onTap: onDelete` → `_deleteEntry`
     (line 157), which DELETEs a score entry.
   - Line 600: **Compute** button — local-only calculation, no network
     write, does **not** need gating.
   - **Fix:** same pattern as above — `context.watch<AuthProvider>()`,
     compute `canEdit`, gate all 3 write actions (Save Grade, per-component
     Add/Save, delete) on it. Since this screen has 3 separate mutating
     actions, consider gating once at the top of `build()` (e.g. pass
     `canEdit` down to each sub-widget) rather than repeating the role check
     3 times inline.

3. `lib/features/attendance/ui/attendance_screen.dart` and
   `lib/features/grades/ui/grades_screen.dart` (the roster/list screens, not
   detail) — no Save/Submit buttons exist on these, they only navigate to the
   detail/roster screens above on row tap. No gating needed here directly,
   but optionally show a read-only visual indicator (e.g. a badge) at the
   list level so a registrar knows before drilling in that they're in
   view-only mode.

**Test after:** log in as the registrar test account (already confirmed
working live per 2026-07-15 testing) and verify Save/Submit controls are
disabled with a visible explanation, while the same screens remain fully
interactive for the teacher test account.

---

## Gap 4 — Billing feature for `accounting` role (net-new, medium)

**Problem:** `accounting` is correctly scoped at the tab level (Dashboard +
More only, matching backend), but the one thing that role exists to do —
billing — has no real implementation. The `FinancialSnapshotCard` shown on
that role's dashboard renders **hardcoded placeholder numbers**, not live
data:

`lib/features/dashboard/ui/widgets/financial_snapshot_card.dart`:
```dart
const FinancialSnapshotCard({
  super.key,
  this.collectedPercent = 78,
  this.collectedAmount = '₱3.84M',
  this.outstandingAmount = '₱1.08M',
});
```
Instantiated with **zero arguments** (pure defaults) at both call sites in
`lib/features/dashboard/ui/dashboard_screen.dart`: line 308 (inside
`_StaffBody`, shown to `admin`) and line 428 (inside `_AccountingBody`, shown
to `accounting`). No `DashboardData` field feeds it, unlike sibling widgets
like `AttendanceCard(attendance: data.attendance, ...)` on the same screen
which do receive live data. The file's own doc comment (lines 8-12)
acknowledges this: *"Financial data is deferred per the handoff (Billing out
of scope this sprint), so figures are placeholders until a real endpoint
exists."* An accounting user opening the app today sees numbers with no
relationship to reality, on the one screen that role mostly lives in.

**Backend shape to build against** (billing-service, gated by `HasRole` with
`BILLING_ROLES = {super_admin, admin, accounting}` — note this is an
all-or-nothing gate per endpoint, unlike the read/write split used elsewhere
in the backend):
- `/api/fee-schedules/`, `/api/fee-schedule-items/`
- `/api/discount-types/`
- `/api/invoices/`
- `/api/payments/`
- `/api/installments/` (read-only viewset)
- `/api/school-settings/` (+ `/current/`)

**Transport layer already exists and is idle** — confirm still true before
building: `lib/core/network/dio_client_factory.dart:31-34` builds all 4
service Dio clients including `billing` (via the same shared `_build()` used
for the other 3, with `AuthInterceptor` already attached), and
`lib/core/config/api_config.dart:42-45` already resolves `billingBaseUrl`
(`--dart-define=BILLING_BASE_URL`, defaulting to port 8002). Confirmed via
grep that `dioClientFactory.billing` is never referenced anywhere else in
`lib/` — it's fully wired and unused, so no new transport/DI-factory work is
needed, only feature code.

**Scope decision needed before building:** ASIA's own mobile brief
(`_review/mobile_app_brief.md` in the ASIA repo) explicitly scopes
accounting/cashier on mobile to a narrow "quick actions" set — record
payment, void invoice — reasoned as "urgent, can't-wait-until-desk" actions
only, not a full billing management UI (full fee-schedule configuration,
invoice generation, etc. stay web-only). Recommend confirming this scope with
the user before building, rather than porting the full web billing screen.

**Minimum viable slice (recommended starting point):**
- New `lib/features/billing/` directory: `data/billing_api.dart` +
  `billing_repository.dart` (following the `grades_api.dart`/
  `grades_repository.dart` pattern), `models/` for whatever summary shape
  the invoices/payments list endpoints actually return (verify field names
  against a live sample, don't assume).
- A summary/snapshot fetch method (e.g. total collected, total outstanding)
  wired into `DashboardRepository`/`DashboardData` the same way
  `AttendanceCard` already receives live data, replacing
  `FinancialSnapshotCard`'s hardcoded defaults with real numbers.
- Defer write actions (record payment, void invoice) to a follow-up slice
  once the read path is confirmed live and correct.

---

## Gap 5 — Dead code removal (trivial)

**File:** `lib/features/dashboard/ui/stub_screen.dart` (27 lines).

Defines `StubScreen extends StatelessWidget`, doc comment: *"Placeholder
destination for bottom-nav tabs that haven't been designed yet (Students,
Attendance, Forms, More)."* Predates the current `AppShell`
`IndexedStack`-based tab implementation.

Confirmed via `grep -rin "StubScreen" lib/` — exactly 2 matches, both inside
the file itself (its own class declaration and constructor). No other file
imports or references it.

**What to do:** delete the file. No other changes needed. Safe to bundle into
the same PR as Gap 1 (both are non-functional cleanup with no behavior
change) rather than doing as a standalone change.

---

## Gap 6 — `super_admin` dashboard is missing billing content it's entitled to (small) — DONE 2026-07-15

Fact-checked directly against the live ASIA repo before implementing:
`billing-service/billing/views.py:13` — `BILLING_ROLES = {"super_admin", "admin", "accounting"}`,
applied via `required_roles`/`HasRole` on all 6 billing viewsets (fee
schedules, fee-schedule-items, discount types, invoices, payments,
installments). Frontend mirror confirmed identical:
`frontend/admin-portal/src/App.jsx:47` — `BILLING_ROLES = ["super_admin",
"admin", "accounting"]`. `super_admin` has the exact same billing
entitlement as `admin` at the actual enforcement layer, not just in a
frontend convenience mirror — confirms the mismatch described below was real.
Implemented: added `FinancialSnapshotCard` to `_SuperAdminBody` in
`lib/features/dashboard/ui/dashboard_screen.dart`, placed after
`StaffOverviewCard` and before `NeedsAttentionCard` (matching `_StaffBody`'s
ordering). `flutter analyze` clean on the changed file. Not yet live-tested
against a running super_admin session — do that before considering this
fully verified end-to-end.

**Problem:** found in a follow-up dashboard-by-dashboard review (2026-07-15) of
`lib/features/dashboard/ui/dashboard_screen.dart`, comparing each role's actual
rendered body against the real backend permission matrix. Every other role's
dashboard body matches its backend scope exactly (see table below) — the one
exception is `super_admin`.

On the backend, `super_admin` and `admin` are **functionally identical** in
every permission class checked (`STAFF_FULL_WRITE_ROLES`, `BILLING_ROLES`,
`WRITE_ROLES_DEFAULT`, etc. — every set that includes one includes the other,
confirmed across `enrollment-service`, `student-service`, and
`billing-service`). There is no code path anywhere in the backend where
`super_admin` has *less* access than `admin`.

But in the mobile app, `_StaffBody` (used by `admin`, lines 265-316) includes
`FinancialSnapshotCard` (line 308), while `_SuperAdminBody` (lines 373-416)
does not reference it at all — `super_admin`'s dashboard shows System Health,
Teacher/Registrar-Admin counts, Staff Overview, and Pending Enrollment
Approvals, but zero financial content. Since `super_admin` is fully inside
`BILLING_ROLES` on the backend, this is a real scope mismatch, not a
deliberate restriction (contrast with `_RegistrarBody`, lines 318-322, which
has an explicit comment documenting *why* it excludes billing — no such
reasoning exists for `_SuperAdminBody`, it's just missing).

**What to build:**

- Add `FinancialSnapshotCard` to `_SuperAdminBody`
  (`dashboard_screen.dart:373-416`), matching how `_StaffBody` includes it.
  Placement: after `StaffOverviewCard` and before/after `NeedsAttentionCard`
  — match visual hierarchy to `_StaffBody`'s ordering (financial content
  sits after enrollment/attendance stats, before announcements) rather than
  inventing a new order.
- This card will render the same hardcoded placeholder figures
  (`₱3.84M`/`₱1.08M`) as it does for `admin`/`accounting` today — that's
  expected and already tracked as Gap 4. Don't scope live billing data into
  this fix; it's purely "give super_admin the same card reference admin
  already has."
- Note while doing this: `SystemHealthCard` and `StaffOverviewCard` (the two
  super_admin-only cards, `lib/features/dashboard/ui/widgets/
  system_health_card.dart` and `staff_overview_card.dart`) are **also**
  hardcoded-placeholder per their own doc comments ("No system-health
  endpoint exists per the handoff" / "No staffing endpoint exists per the
  handoff") — so after this fix, `super_admin`'s entire dashboard is
  placeholder data end-to-end, same as `admin`'s Financial Snapshot and
  `accounting`'s dashboard. This is consistent with the rest of the app's
  current state, not a new problem to solve here — just don't be surprised
  the numbers don't move after wiring the widget in.
- No role-check/gating logic changes needed — this is purely "reference an
  existing widget from one more body," not a permissions change.

---

## Gap 7 — Tab visibility is binary (all-5-or-2); Students should be open to every role — DONE 2026-07-15

Implemented: `_visibleTabsForRole` in `lib/features/shell/ui/app_shell.dart`
now returns Dashboard+Students+More for every role, adding Attendance+Grades
only for `hasAnyRole(role, gradeRoles)`. Doc comment above the function
updated to describe the new Dashboard+Students+More default instead of the
old Dashboard+More-only behavior. `flutter analyze` clean on the changed
file; `flutter test test/roles_test.dart` passes (unaffected, still exercises
`hasAnyRole`/role groups directly). Not yet live-tested against a running
`accounting` session — do that before considering this fully verified
end-to-end.

**Problem:** `_visibleTabsForRole` in `lib/features/shell/ui/app_shell.dart:22-25`
currently gates all 4 non-Dashboard/More tabs (Students, Attendance, Grades)
behind one check:
```dart
List<ShellTab> _visibleTabsForRole(String role) {
  if (hasAnyRole(role, gradeRoles)) return ShellTab.values;
  return [ShellTab.dashboard, ShellTab.more];
}
```
`gradeRoles = {super_admin, admin, registrar, teacher}` — so `accounting`
currently gets Dashboard+More only, same as an unrecognized role.

**Fact-checked against the live ASIA repo (2026-07-15):** this single gate is
too coarse. The backend does not treat Students the same as
Attendance/Grades:

- **Students** (`student-service/students/views.py`, and Subjects/Enrollments
  in enrollment-service) is gated by `IsAdminRegistrarOrReadOnly`
  (`student-service/accounts/permissions.py`): *any authenticated role* can
  read; only `super_admin`/`admin`/`registrar` can write. There is no role
  exclusion on the read side — `accounting` can read students today via the
  API, it's just never given a mobile screen for it.
- **Attendance/Grades/Narrative Reports** are gated by
  `GRADE_READ_ROLES = {super_admin, admin, registrar, teacher}`
  (`enrollment-service/accounts/permissions.py:47`) — `accounting` is
  explicitly excluded, confirmed by the backend's own test
  `test_accounting_denied_even_read`.
- **Cross-checked against the web admin-portal**, which is more granular
  than the mobile app in exactly this way: `frontend/admin-portal/src/
  App.jsx` has **no `roles=` gate at all** on the Students/Enrollments
  routes (open to any authenticated staff), while Attendance/Grades routes
  are gated to `GRADE_ROLES` (`App.jsx:66-67,86` — same 4 roles as the
  backend's `GRADE_READ_ROLES`). The web app already treats these as two
  separate gates; the mobile app currently conflates them into one.

**Decision confirmed with user (2026-07-15):** give `accounting` a read-only
Students tab. Resulting tab set per role:

| Role | Dashboard | Students | Attendance | Grades | More |
|---|---|---|---|---|---|
| teacher | ✅ | ✅ | ✅ write (own advisory) | ✅ write (own advisory) | ✅ |
| registrar | ✅ | ✅ | ✅ read-only (see Gap 3) | ✅ read-only (see Gap 3) | ✅ |
| admin | ✅ | ✅ | ✅ full | ✅ full | ✅ |
| super_admin | ✅ | ✅ | ✅ full | ✅ full | ✅ |
| accounting | ✅ | ✅ **(new)** | ❌ | ❌ | ✅ |

No other role's tab set changes — this is additive for `accounting` only.

**What to build:**

- Split `_visibleTabsForRole` in `app_shell.dart:22-25` into two checks
  instead of one. Any authenticated role (i.e. any non-empty/known role
  string) sees Dashboard, Students, More; only `hasAnyRole(role, gradeRoles)`
  additionally sees Attendance and Grades. Something like:
  ```dart
  List<ShellTab> _visibleTabsForRole(String role) {
    final tabs = [ShellTab.dashboard, ShellTab.students];
    if (hasAnyRole(role, gradeRoles)) {
      tabs.addAll([ShellTab.attendance, ShellTab.grades]);
    }
    tabs.add(ShellTab.more);
    return tabs;
  }
  ```
  Preserve nav-bar ordering (`ShellTab.values` order is `dashboard, students,
  attendance, grades, more` — the list above already matches that order).
  **Verified 2026-07-15: no further check needed on `ShellBottomNavBar`** —
  it renders via `_allNavItems.where((item) => visibleTabs.contains(item.tab))`
  (`lib/features/shell/ui/widgets/shell_bottom_nav_bar.dart:41`), which
  already filters correctly for any subset of tabs, contiguous or not (e.g.
  `accounting`'s new non-contiguous {dashboard, students, more} set — no
  Attendance/Grades gap to worry about). An earlier draft of this plan
  flagged this as something to double-check; that's now resolved, don't
  re-investigate it.
- `IndexedStack`'s index lookup in `app_shell.dart:78`
  (`ShellTab.values.indexOf(selected)`) already works off the full
  `ShellTab.values` enum regardless of which subset is visible, so no change
  needed there — only `_visibleTabsForRole`'s returned list changes.
- `StudentsListScreen` itself (`lib/features/students/ui/
  students_list_screen.dart`) is already read-only for every role per prior
  research (no write actions exist in this UI regardless of role — confirmed
  in earlier session, comment at `students_list_screen.dart:43-44`), so no
  additional write-guard is needed here the way Gap 3 is needed for
  Attendance/Grades — accounting reaching this screen is safe by construction.
- Test after: log in as the accounting test account (confirmed working live
  per 2026-07-15 testing) and verify Students now appears and loads the
  roster; verify Attendance/Grades remain absent from the nav bar.

---

## Appendix — Dashboard body audit (2026-07-15), for reference

Full per-role comparison of `dashboard_screen.dart`'s current rendered content
vs. backend RBAC scope, done to find Gap 6. Kept here so a future pass doesn't
need to redo the same read-through.

| Role | Body widget | Renders today | Backend entitlement | Verdict |
|---|---|---|---|---|
| teacher | `_TeacherBody` (208-263) | Today's Classes (live, advisory-scoped), My Sections count, Week Attendance Avg | Read+write grades/attendance/narrative-reports scoped to own `SectionAdvisory`; read-only elsewhere; no billing | Matches — correctly narrow |
| registrar | `_RegistrarBody` (323-371) | Needs Attention (enrollment approvals only), Active Students, Enrolled This Year, Pending Enrollment, Attendance summary, Announcements — no billing | Full read+write enrollments/subjects/etc.; read-only grades/attendance; zero billing access | Matches — comment at 318-322 documents the billing exclusion explicitly |
| admin | `_StaffBody` (265-316) | Needs Attention (invoices + enrollment approvals), Active Students, Enrolled This Year, Pending Enrollment, **Financial Snapshot**, Attendance, Announcements | Full access everywhere including billing (`BILLING_ROLES`) | Matches (Financial Snapshot itself is placeholder data — Gap 4, not a scope error) |
| super_admin | `_SuperAdminBody` (373-416) | System Health, Teacher/Registrar-Admin counts, Staff Overview, Pending Enrollment Approvals — **no billing** | Identical backend scope to admin, including full `BILLING_ROLES` access | **Mismatch — Gap 6.** Missing `FinancialSnapshotCard` |
| accounting | `_AccountingBody` (418-431) | Financial Snapshot only | Full billing access (`BILLING_ROLES`); zero access (even read) to grades/attendance/enrollments | Matches — correctly hollow outside billing (data itself is placeholder — Gap 4) |

## Cross-cutting notes for whoever picks this up

- **Verify field names against live API responses, not assumptions**, for any
  new model class (Gaps 2 and 4). Prior sessions building Grades/Attendance
  guessed field names from the design handoff and had to correct them after
  reading actual backend source/live samples — see project memory
  `asia_backend_ground_truth.md` for the pattern and the specific mistakes
  made last time, worth avoiding a repeat.
- **`guardian` role:** confirmed non-functional across the entire backend
  (assignable in identity-service, denied by every permission check
  everywhere else). Do not build guardian-specific UI for any of these gaps.
- **Live-tested accounts so far:** `registrar`, `teacher`, `accounting`
  (2026-07-15). `admin`/`super_admin` not yet explicitly confirmed live —
  worth testing those logins before or during this work, particularly for
  Gap 1's refactor and Gap 4's billing work which both touch admin-visible
  screens.
- Full backend permission ground truth (exact permission class names,
  file:line references in the ASIA repo, full endpoint table) is in project
  memory `asia_rbac_backend_status.md` and `asia_rbac_role_ux_plan.md` if
  more backend detail is needed than what's inlined above.
