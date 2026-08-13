# Authentication And Profile

## Scope

Transium currently supports one authentication method: Sign in with Apple.
Backend and database choices are intentionally undecided, so this document stops
at model contracts and security requirements.

## Pre-Auth Flow

- `ContentView` shows onboarding before authentication.
- Onboarding completion is stored in `@AppStorage("hasCompletedOnboarding")`.
- `AppEnvironment.DEV_MODE` can be set to `true` during development to replay
  onboarding every launch.
- Authentication must remain inaccessible until onboarding completes, except
  when onboarding is skipped/completed through the onboarding controls.
- The auth screen is light-mode only for now and uses shared `UI/System`
  typography/color tokens.

## Local Device Models

SwiftData is used only for private on-device state.

- `Features/Profile/ProfileModel.swift` defines `LocalProfile`, which mirrors the first profile model:
  `id`, `firstName`, `lastName`, `method`, and `level`.
- `Features/Auth/AuthModels.swift` defines `LocalAuthIdentity`, which stores the local Apple identity mapping separately from the
  profile so authentication metadata does not pollute the profile shape.
- Do not persist Apple identity tokens or authorization codes in SwiftData.
  Treat them as short-lived values to send to the backend verification layer.

## Backend Contracts

The backend must eventually implement `AuthBackend` from
`Backend/AuthBackendContract.swift`.

Minimum Apple verification requirements:

- Verify the identity-token signature using Apple's public keys.
- Verify the nonce sent with the original authorization request.
- Verify issuer is Apple's issuer.
- Verify audience matches Transium's configured client identifier.
- Verify token expiration.
- Exchange the single-use authorization code server-side.
- Store refresh tokens only on the server side if the backend uses them.

## Private Profile Access

Every profile endpoint must be authenticated.

Required middleware behavior:

- Resolve the authenticated backend user from a verified session token.
- Reject unauthenticated requests before profile lookup.
- Enforce owner-only profile reads and writes.
- Never accept a user ID from the client as proof of ownership.
- Sanitize first and last name before server storage.
- Return only the requesting user's private profile.

## Apple Sign-In Notes

- Use Apple's stable user identifier, not email, as the account identifier.
- Request `fullName` and `email` during initial authorization.
- Expect `fullName` to be available only during initial account creation.
- Check local Apple credential state for existing sessions.
- If Apple reports revoked, not found, or transferred credentials, clear the
  local session and ask the user to sign in again.
- The current auth screen surfaces Apple's stable user identifier after a
  successful sign-in as a temporary development callback/toast. A backend must
  still verify the identity token and authorization code server-side before
  trusting that identifier.
- The temporary identifier toast is for development visibility only; it is not
  a substitute for backend session creation.

## Future Backend Decision Points

- Database provider
- Server auth/session token format
- Token refresh and revocation strategy
- Row-level security or equivalent owner-policy implementation
- Account deletion and Apple token revocation flow
