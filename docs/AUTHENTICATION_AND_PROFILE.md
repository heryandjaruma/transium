# Authentication & User Profile Reference

## 1. Authentication Architecture

Transium uses **Sign in with Apple** exchanged through a **Better Auth** backend service (`https://transium-api.heryandjaruma.workers.dev/api/auth`).

```
┌────────────────────────┐      ┌─────────────────────────┐      ┌─────────────────────────┐
│     SwiftUI Client     │ ---> │   Better Auth Backend   │ ---> │     Apple ID Server     │
│ (AppleSignInDelegate)  │      │  (POST /sign-in/social) │      │ (Public Key Validation) │
└────────────────────────┘      └─────────────────────────┘      └─────────────────────────┘
            │                                │
            ▼ (Session Token)                │
┌────────────────────────┐                   │
│   SessionTokenStore    │                   │
│ (iOS Keychain Access)  │ <─────────────────┘
└────────────────────────┘
```

---

## 2. Session Management (`SessionTokenStore`)

Session tokens and cached user profiles are stored in the iOS device's secure Keychain (`si.transporta.transium-app.auth`) via `SessionTokenStore.swift`.

### Methods
- `SessionTokenStore.save(token:profile:)`: Persists bearer token and profile DTO to Keychain.
- `SessionTokenStore.read() -> String?`: Reads bearer token.
  - **Preview Mode**: Returns `"debug-token-123"` when running in Xcode SwiftUI Canvas Previews (`AppEnvironment.DEV_MODE`).
  - **Runtime**: Fetches decrypted token data from Keychain.
- `SessionTokenStore.readProfile() -> BackendProfile?`: Reads cached profile metadata.
- `SessionTokenStore.clear()`: Deletes session token and cached profile on sign-out.

---

## 3. Bearer Token Injection (`APIClient`)

`APIClient.swift` automatically injects the Authorization header into all requests where `requiresAuth == true`:

```swift
if requiresAuth, let token = SessionTokenStore.read(), !token.isEmpty {
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
}
```

---

## 4. Endpoints & Payloads

### `POST /api/auth/sign-in/social`
Exchanges Apple ID authorization tokens for a Better Auth session.

- **Request Body**:
  ```json
  {
    "provider": "apple",
    "idToken": "<raw-apple-identity-token>",
    "authorizationCode": "<raw-apple-auth-code>",
    "user": {
      "name": { "firstName": "Wayan", "lastName": "Bali" },
      "email": "user@privaterelay.appleid.com"
    }
  }
  ```

- **Response (200 OK)**:
  ```json
  {
    "token": "sess_89412abc...",
    "user": {
      "id": "usr_1029",
      "name": "Wayan Bali",
      "email": "user@privaterelay.appleid.com",
      "image": null
    }
  }
  ```

---

### `GET /api/private/profile`
Retrieves authenticated user profile information, XP level, and awarded badges.

- **Auth**: Required (`Bearer <token>`)

#### Response (200 OK)
```json
{
  "profile": {
    "id": "usr_1029",
    "name": "Wayan Bali",
    "email": "user@privaterelay.appleid.com",
    "avatarUrl": "https://storage.googleapis.com/.../avatar.jpg",
    "level": 4,
    "xp": 450,
    "badges": [
      {
        "id": "badge_1",
        "badgeName": "Sanur Explorer",
        "badgeImageUrl": "/media/system/badge/sanur.png"
      }
    ]
  }
}
```

---

### `POST /api/private/profile/image`
Uploads a user avatar image via multipart form-data.

- **Auth**: Required (`Bearer <token>`)
- **Content-Type**: `multipart/form-data; boundary=...`
- **Field**: `image` (`image/jpeg` or `image/png`)

---

## 5. Security & Privacy Rules

1. **Client-Server Trust**: Client-provided user IDs are never trusted on the backend; all resource operations derive ownership strictly from the verified session token.
2. **Token Sanitization**: Apple identifiers, raw identity tokens, and authorization codes are never surfaced in user-facing toasts or error alerts.
3. **Keychain Scope**: Tokens are saved with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` to prevent cross-device migration.
