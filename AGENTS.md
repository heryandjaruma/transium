# AGENTS.md

## Purpose

This repository is a native iOS transit and discovery app built with SwiftUI. Treat this
file as the default operating agreement for any agent working here.

## Project Snapshot

- App name: `transium`
- Platform: iOS (18.0+)
- UI stack: SwiftUI (Strict Concurrency compatible)
- Entry point: `transium/transiumApp.swift`
- Root flow: `transium/ContentView.swift`
- Current launch order: onboarding first, then Apple-only authentication
- Local map assets live in `transium/Resources/Maps`
- Backend origin: `https://transium-api.heryandjaruma.workers.dev`

## Current Reality

- The app has a complete onboarding flow, Sign in with Apple backed by Better Auth, offline MapLibre Native basemaps backed by PMTiles, live Geofence-driven Go Mode navigation, and gamified celebration summary cards.
- MapLibre Native is installed through Swift Package Manager.
- The project uses Xcode's file-system-synchronized layout, so source files are discovered from the `transium/` folder automatically.
- Live Xcode Canvas Previews (`#Preview`) automatically inject `"debug-token-123"` via `SessionTokenStore.read()`.

## Code Structure

- `transium/Screens/<Feature>` contains screen-level SwiftUI views and local `Views/` subfolders (e.g. `Screens/Home/Views/`, `Screens/Summary/Views/`).
- `transium/UI/System` contains shared fonts, colors, asset names, and app-wide constants (`DesignTokens.swift`).
- `transium/UI/Components` contains reusable UI pieces (buttons, toast center, postage stamp cards).
- `transium/Features/<Feature>` contains domain models, services, and business logic (`Auth`, `Bookmark`, `Device`, `Journey`, `Location`, `Map`, `Profile`, `Quest`).
- `transium/Backend` contains the `APIClient`, Better Auth implementation, multipart uploaders, and configuration.
- `transium/Resources/Fonts` stores Londrina Solid and Poppins font binaries registered through `Info.plist`.
- `transium/Resources/Maps` stores bundled PMTiles used by MapLibre.
- `docs/` contains comprehensive API references, authentication guides, architecture notes, and Go Mode documentation.

## App Flow Rules

- Onboarding must run before authentication.
- `ContentView` owns the one-time onboarding gate with `@AppStorage`.
- `AppEnvironment.DEV_MODE` in `UI/System/DesignTokens.swift` resets `hasCompletedOnboarding` to `false` once from `transiumApp.init()`. Do not use `DEV_MODE` directly in the onboarding/auth routing condition.
- Keep Sign in with Apple as the only authentication method unless the user explicitly changes product direction.
- Do not show Apple identifiers, identity tokens, authorization codes, or nonce values in user-facing toast copy.
- After successful local Apple sign-in persistence, route to `HomeScreen`.
- Do not trust client-provided user IDs on a future backend; verify Apple identity tokens and enforce owner-only profile access server-side.

## UI System Rules

- The current app UI is light-mode only. Do not add dark-mode-specific styling until the user explicitly asks for dark mode.
- Use `TransiumFont.display` for Londrina Solid headings.
- Use `TransiumFont.body` for Poppins body, subtitle, button, and terms text.
- Use `TransiumColor` and `TransiumAsset` from `UI/System/DesignTokens.swift` instead of raw asset strings in screens when practical.
- Use `TransiumStampCard` and `QuestBadgePostageStack` for postage stamp and badge rendering with consistent rotation (`-4°` / `-5°`).
- Use `AppToastCenter.shared` for global success, warning, and error feedback.
- Keep toast messages human-readable and action-oriented; do not surface raw error payloads, IDs, tokens, or implementation details.

## Non-Negotiable Git Rules

- Never push unless the user explicitly asks for a push.
- Never create a PR, merge, rebase, or force-push unless the user explicitly asks for it.
- Never commit by default. Commit only when the user asks for a commit.
- Before any commit, make sure the staged diff matches the requested scope.
- Prefer small, reviewable commits over large mixed commits.

## Commit Message Semantics

When the user asks for a commit, use a semantic prefix:

- `feat:` for new user-facing features
- `fix:` for bug fixes
- `core:` for foundational architecture, data flow, or app structure changes
- `docs:` for markdown, notes, or documentation-only changes
- `refactor:` for internal restructuring without behavior changes
- `test:` for test additions or test-only refactors
- `perf:` for measurable performance improvements
- `build:` for Xcode project, package, signing, or build configuration changes
- `ci:` for automation or pipeline changes
- `chore:` for maintenance tasks with no product behavior impact
- `style:` for formatting or naming-only cleanup
- `revert:` for reverting a prior change

Format: `<type>: <short imperative summary>`
