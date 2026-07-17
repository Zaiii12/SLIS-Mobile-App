# Session Kick-Out Asymmetry — Fix Guide

Written 2026-07-17. **Audience:** the agent/session picking up mobile work
next — read this before touching auth/session code again, and before
closing this out as done.

**Symptom reported by the user:** logging in via the mobile emulator kicks
the web admin-portal session out (near-instantly), but logging in on web did
not appear to kick the mobile session out at all.

**Status: root cause found, fix applied to `lib/main.dart`, not yet
live-verified end-to-end on a real emulator + web session pair.** That
verification is the first thing whoever picks this up should do.

---

## 0. Ground truth — where each piece of this lives

This bug spans two repos. Don't re-derive this by re-reading both codebases
from scratch; it's already been done.

- **`~/Documents/GitHub/ASIA`** (backend + web admin-portal) — session
  enforcement itself. Confirmed **symmetric and correct** — not the bug.
- **This repo** (`SLIS-Mobile-App`) — where the actual gap was: the app had
  no way to *notice* a superseded session while idle. **Fixed** in
  `lib/main.dart` (see §2).

---

## 1. What was ruled out (don't re-investigate these)

Full research pass confirmed, with file:line citations, in the ASIA repo:

- **One login endpoint, no platform branching.** `LoginView` in
  `backend/identity-service/accounts/views.py:25-90` is used identically by
  web and mobile — no `device_type`/`platform` field exists anywhere in
  `LoginSerializer`, `User`, or the session-stamping code.
- **Single shared session slot per user**, not per-platform:
  `User.current_session_id` (`backend/identity-service/accounts/models.py:18`),
  stamped fresh on every login via `stamp_session_id()`
  (`backend/identity-service/accounts/services/auth_service.py:19-24`),
  embedded as the JWT's `sid` claim.
- **Enforced identically across all 3 downstream services** —
  `SingleSessionJWTAuthentication.get_user()` is byte-identical in
  `enrollment-service`, `student-service`, and `billing-service`
  (`accounts/authentication.py:5-19` in each), rejecting any token whose
  `sid` doesn't match the user's current `current_session_id`.
- **No websocket/push "log out the other client" mechanism** anywhere in the
  backend — repo-wide grep for websocket/socket.io/polling came back empty.
  Invalidation is entirely passive: an old token just stops being accepted
  the next time it's used for anything.
- **This app's transport/auth plumbing was already solid before this fix** —
  not the bug either:
  - `lib/core/network/auth_interceptor.dart` — correct single-flight 401→
    refresh→retry, with `onSessionExpired()` firing on refresh failure.
  - `lib/core/network/dio_client_factory.dart` — correct per-client cookie
    jar on the identity-service client only (needed for the httpOnly
    `refresh` cookie), per-client `AuthInterceptor` instance so retries keep
    the right cookie jar/interceptor chain.
  - `lib/features/auth/data/auth_repository.dart` — `restoreSession()`
    already validates against the backend (refresh + re-fetch user) rather
    than trusting local token presence; `forceLogout()` already exists as a
    distinct path from `logout()` for server-invalidated sessions (skips the
    now-pointless `/api/auth/logout/` call).

**Conclusion of that pass:** if the plumbing was already correct end-to-end,
the only way "mobile never notices" makes sense is a *timing* gap — the app
simply wasn't checking often enough to ever hit the 401 that would trigger
all of the above.

---

## 2. Root cause — confirmed, fixed

**The gap:** this app only ever validated its session in two places:

1. Cold launch — `SplashScreen._resolveSession()` →
   `AuthProvider.tryRestoreSession()` → `AuthRepository.restoreSession()`.
2. Reactively, whenever some real API call happened to 401.

`lib/features/shell/ui/app_shell.dart` builds all visited tabs into an
`IndexedStack` and keeps them alive — so once a tab like Dashboard has
loaded, simply sitting on it (which is exactly what a manual test looks
like: log in on mobile, leave the emulator open, then log in on web) fires
**zero** further requests. No `WidgetsBindingObserver` and no polling
`Timer` existed anywhere in the app (confirmed via grep — zero matches for
`AppLifecycleState`/`Timer.periodic` before this fix), so there was
genuinely no code path that would ever notice a supersession while idle,
no matter how long you waited.

Contrast with the web admin-portal: it's a dashboard SPA that fires API
calls on nearly every navigation, so it stumbles into the 401 within
seconds — which is why the kick-out looked one-directional. It wasn't; the
web side just got lucky on timing every time, and mobile never did.

**Fix applied — `lib/main.dart`:**

- `SlisMobileApp` converted from `StatelessWidget` to `StatefulWidget`
  (`_SlisMobileAppState`), adding `WidgetsBindingObserver`.
- `didChangeAppLifecycleState()` triggers `_revalidateSession()` on
  `AppLifecycleState.resumed` (app returning to foreground), but only if
  `AuthProvider.status == AuthStatus.authenticated` — no-op if not logged in.
- `_revalidateSession()` calls the existing
  `authRepository.refreshAccessToken()`. On success: nothing else happens,
  session confirmed still valid. On failure (refresh rejected — the
  supersession case): routes through the **same** `forceLogout()` +
  push-to-`LoginScreen` sequence `main.dart`'s existing `onSessionExpired()`
  closure already uses for the reactive 401 path, so there are now two
  triggers converging on one well-tested exit path, not two divergent ones.

This deliberately mirrors the *pattern* already established in this file
(`onSessionExpired`'s re-fetch-`navigatorKey.currentContext`-after-`await`
shape) rather than introducing a new one — see that closure at the top of
`main()` before touching this again.

**What this fix does NOT do**, on purpose:

- No polling timer. Resume-based detection was the option chosen (over a
  periodic timer, or both) when this was scoped — catches the realistic
  case (backgrounding/switching apps) without extra idle-foreground network
  traffic. If a future report shows the app being kicked out while sitting
  **foregrounded** and idle for a long stretch (not backgrounded) without
  noticing, that's the case resume-detection can't catch — see §4.
- No backend changes. None were needed or made.

---

## 3. Verify before considering this closed

Not yet done as of this writing — do this first:

1. Log in on the emulator (any role).
2. Background the app — home button or app switcher, **not** force-quit.
3. Log in on the web admin-portal with the same account.
4. Bring the emulator back to foreground.
5. **Expected:** near-immediate bounce to `LoginScreen`, not a stale
   Dashboard that silently 401s on next tap.

Also sanity-check the reverse still works (mobile login still kicks web —
should be unaffected, but confirm no regression):
1. Log in on web.
2. Log in on the emulator with the same account.
3. On web, trigger any navigation/API call.
4. **Expected:** unchanged — web still redirects to `/login` as before.

`flutter analyze` was run on the change: clean except one new
`info`-level `use_build_context_synchronously` (same class already present
in the adjacent `onSessionExpired` closure — not a new pattern, not
actionable) — no new errors. A pre-existing unrelated error in
`test/widget_test.dart` (`missing_required_argument` for
`onSessionExpired`) predates this change; don't attribute it to this fix if
you see it.

---

## 4. If verification in §3 fails, or a variant of this bug resurfaces

Check these in order — cheapest/most-likely first:

1. **Is the emulator actually backgrounding, or force-quitting?** A
   force-quit kills the process; there's no "resume" to observe, and the
   next cold launch goes through `SplashScreen`/`tryRestoreSession()`
   instead, which should *also* catch it. If that path is also failing,
   the bug has moved to `AuthRepository.restoreSession()` — re-read that
   method fresh, don't assume it's still correct.
2. **Idle-while-foregrounded case** (app is open and visible the whole
   time, never backgrounded, but the user also never navigates anywhere).
   `didChangeAppLifecycleState` cannot catch this — it only fires on actual
   lifecycle transitions. If the user confirms this specific scenario
   matters (e.g. "I left it open on Dashboard and never touched it"), the
   fix is a periodic `Timer` alongside the resume check — this was
   explicitly considered and deferred when this fix was scoped (see §2),
   not an oversight.
3. **Cookie jar not surviving app restart.** `DioClientFactory`'s
   `CookieJar()` (`lib/core/network/dio_client_factory.dart:32`) is
   in-memory only (not `PersistCookieJar`) — confirm this is still true,
   and if a fresh cold-launch refresh is failing even right after a
   successful login, check whether the httpOnly refresh cookie is actually
   being captured/replayed at all, vs. a `current_session_id` mismatch.
4. **Check the ASIA repo hasn't changed the session model.** `git log
   backend/identity-service/accounts/` in ASIA for anything touching
   `current_session_id`/`stamp_session_id`/`SingleSessionJWTAuthentication`
   since 2026-07-17 — if the backend contract changed, §1's ground truth is
   stale and needs re-verification, don't trust it blindly.

---

## 5. Cross-repo note

If a fix ever needs to happen on the **backend** side instead (e.g. moving
to a per-device session table rather than one global slot, or adding a
push-based "log out now" signal instead of passive detection), that work
belongs in `~/Documents/GitHub/ASIA`, not here — specifically
`backend/identity-service/accounts/` for the model/session logic, plus a
matching change in all 3 `accounts/authentication.py` copies in the
downstream services (they're intentionally duplicated, not shared via a
package — keep them byte-identical if one changes). No such change was
needed for this fix, but flagging the location in case a future report
shows the passive-detection approach itself (as opposed to just this app's
gap in triggering it) isn't good enough.
