# AGENTS.md

## Purpose

This repository is a brand-new native iOS app built with SwiftUI. Treat this
file as the default operating agreement for any agent working here.

## Project Snapshot

- App name: `transium`
- Platform: iOS
- UI stack: SwiftUI
- Entry point: `transium/transiumApp.swift`
- Root flow: `transium/ContentView.swift`
- Current launch order: onboarding first, then Apple-only authentication
- Local map assets live in `transium/Resources/Maps`
- Existing map notes live in `transium/Resources/Maps/guidelines.md`

## Current Reality

- The app has an onboarding flow, an Apple-only authentication screen, and
  SwiftData local auth/profile models.
- There are no tests yet.
- There are no external packages yet.
- The project uses Xcode's file-system-synchronized layout, so source files are
  discovered from the `transium/` folder instead of being manually listed one
  by one in the project file.

## Code Structure

- `transium/Screens/<Feature>` contains screen-level SwiftUI views.
- `transium/UI/System` contains shared fonts, colors, asset names, and
  app-wide constants. The current file is `DesignTokens.swift`.
- `transium/UI/Components` contains reusable UI pieces that are not tied to one
  feature.
- `transium/Features/<Feature>` contains domain models and feature services.
- `transium/Backend` contains backend contracts only until the backend/database
  is chosen.
- `transium/Resources/Fonts` stores font files registered through
  `transium/Info.plist`.

## App Flow Rules

- Onboarding must run before authentication.
- `ContentView` owns the one-time onboarding gate with `@AppStorage`.
- `AppEnvironment.DEV_MODE` in `UI/System/DesignTokens.swift`
  intentionally replays onboarding on every launch when set to `true`.
- Keep Sign in with Apple as the only authentication method unless the user
  explicitly changes product direction.
- Do not trust client-provided user IDs on a future backend; verify Apple
  identity tokens and enforce owner-only profile access server-side.

## UI System Rules

- The current app UI is light-mode only. Do not add dark-mode-specific styling
  until the user explicitly asks for dark mode.
- Use `TransiumFont.display` for Londrina Solid headings.
- Use `TransiumFont.body` for Poppins body, subtitle, button, and terms text.
- Use `TransiumColor` and `TransiumAsset` from `UI/System/DesignTokens.swift`
  instead of raw asset strings in screens when practical.
- Keep auth terms copy visually compact; it should target two lines on the
  current phone layout.
- Keep auth hero artwork large and slightly clipped by the white auth panel,
  matching the supplied reference direction.

## Non-Negotiable Git Rules

- Never push unless the user explicitly asks for a push.
- Never create a PR, merge, rebase, or force-push unless the user explicitly
  asks for it.
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

Format:

`<type>: <short imperative summary>`

Examples:

- `feat: add first transit map shell`
- `core: introduce map resource loader`
- `docs: add agent workflow and project context`

## Working Style

- Read the repository before making architectural assumptions.
- Preserve SwiftUI-first patterns unless there is a clear reason to introduce
  UIKit.
- Keep changes aligned with Apple platform conventions and accessibility
  expectations.
- Prefer small vertical slices that can run in the simulator quickly.
- When a task touches product feel or UI polish, actively apply design taste
  instead of stopping at bare functionality.
- Do not add new screen files at the app root. Use `Screens`, `UI`,
  `Features`, `Backend`, and `Resources` consistently.
- Use `TransiumFont` and `TransiumColor` for shared typography/color choices
  instead of scattering raw custom font names or asset colors.

## Skills To Prefer

Use the most relevant installed skill when the task matches it:

- `swiftui-expert-skill` for modern SwiftUI implementation
- `swiftui-pro` for SwiftUI reviews and refactors
- `update-swiftui-apis` when checking for newer SwiftUI APIs
- `taste` for stronger aesthetic judgment and polish
- `ios-hig-design` for Apple-aligned iOS design decisions
- `ios-accessibility` for VoiceOver, Dynamic Type, and accessibility quality
- `swiftui-patterns` for architecture and state management
- `swiftui-performance-audit` for render/update performance work
- `swiftui-animation` for motion and transition work
- `swift-testing` when tests are added
- `swiftdata` if persistence is introduced

## Known Oddity

- The current Xcode project includes `.gitignore` in the app resources build
  phase. Treat that as accidental unless the user says otherwise.
