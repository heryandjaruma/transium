# Project Context

## Status On August 13, 2026

`transium` is now a native SwiftUI app with a first-run onboarding flow,
Apple-only authentication, a post-auth MapLibre home map, and local SwiftData
auth/profile models. Backend and database choices are still intentionally
undecided.

## Repository Shape

- `transium/transiumApp.swift` wires the main `WindowGroup` and SwiftData model
  container
- `transium/ContentView.swift` gates onboarding before authentication
- `transium/Screens/Onboarding` contains the first-run onboarding flow
- `transium/Screens/Auth` contains the Apple sign-in screen
- `transium/Screens/Home` contains the initial post-auth map experience
- `transium/UI/System` contains shared colors, fonts, asset names, and
  app environment flags in `DesignTokens.swift`
- `transium/UI/Components` contains reusable buttons, page indicators, and
  global app toast UI
- `transium/Features/Auth` contains Apple sign-in service/store/local identity
  models
- `transium/Features/Map` contains local MapLibre style generation
- `transium/Features/Profile` contains the local private profile model
- `transium/Backend` contains backend auth contracts only
- `transium/Assets.xcassets` holds app icon, color assets, and illustrations
- `transium/Resources/Fonts` holds Londrina Solid and Poppins font files
- `transium/Resources/Maps` holds bundled PMTiles data and notes
- `transium.xcodeproj/project.pbxproj` defines one iOS app target named
  `transium`

## Launch Flow

`ContentView` owns the app's current pre-auth flow:

1. Show `OnboardingScreen` when onboarding has not completed.
2. Persist completion with `@AppStorage("hasCompletedOnboarding")`.
3. If `AppEnvironment.DEV_MODE == true`, reset onboarding completion once from
   `transiumApp.init()` so onboarding replays on fresh launch.
4. Show `AuthScreen` after onboarding completes.
5. Show `HomeScreen` after Apple sign-in succeeds and the local profile is
   persisted.

Onboarding must stay before authentication until product direction changes.

## Design System

- Use `TransiumFont.display` for Londrina Solid display headings.
- Use `TransiumFont.body` for Poppins body/action text.
- Use `TransiumColor` for shared product colors.
- Use `TransiumAsset` for shared image asset names.
- Keep reusable controls in `UI/Components`, not inside individual screen
  folders unless they are screen-private.
- The current visual implementation is light-mode only.
- Auth should keep the hero artwork large, slightly raised, and clipped by the
  white bottom panel. The terms copy should remain compact and target two lines
  on the current phone layout.

## Map Assets

Two PMTiles files are already checked in:

- `bali_basemap.pmtiles`
- `bali_transit.pmtiles`

The existing notes say these are intended for MapLibre usage and describe the
available layers:

- Basemap layers include land, district boundaries, water, vegetation, and
  roads.
- Transit layers include bus stops and bus routes.
- `HomeScreen` wraps MapLibre Native's `MLNMapView` in SwiftUI.
- `TransiumMapStyleFactory` writes a temporary MapLibre style JSON that points
  to the bundled PMTiles through `pmtiles://file://...` URLs.
- The initial map style intentionally avoids symbol/text layers because no
  local glyph or sprite assets are bundled yet.

## Build And Target Notes

- Xcode project format is modern and uses synchronized filesystem groups.
- iPhone deployment target is currently `26.5`.
- Sign in with Apple capability is enabled via `transium/transium.entitlements`.
- `transium/Info.plist` registers bundled app fonts.
- MapLibre Native `6.28.0` is configured through Swift Package Manager.
- No test target exists yet.

## What Future Agents Should Assume

- This repo is early enough that many architecture decisions are still open,
  but the screen/component/UI-system folders should be preserved.
- Map data is an important product clue, so any navigation, transit, or mapping
  work should start by respecting the bundled PMTiles assets.
- Documentation should stay close to the codebase while the project is still
  forming.

## Good Next Milestones

- Add the post-auth profile destination
- Add local glyph/sprite support if map labels become necessary
- Define app navigation and first feature boundaries
- Add an accessibility baseline early
- Add tests as soon as domain logic appears

## Known Caveat

- `.gitignore` is currently included in the resources build phase. If bundle
  contents matter, verify whether that should be removed from the target.
