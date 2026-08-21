# Transium 🌴 🚌

> **Smart Public Transit & Urban Discovery for Bali**  
> Native iOS Application built with SwiftUI, MapLibre Native, and Better Auth.

---

## Overview

**Transium** transforms public transit navigation in Bali by combining offline vector basemaps, real-time arterial corridor transit polyline calculations, kelurahan-centric quest discovery, and gamified travel summaries into a playful, high-performance native iOS experience.

---

## Core Features

- 🗺️ **High-Performance MapLibre Vector Map**
  - Completely offline-capable using bundled vector PMTiles (`bali_basemap.pmtiles` and `bali_transit.pmtiles`).
  - Seamless inland corridor-following transit routing across Bali's bus networks (Teman Bus / Trans Metro Dewata lines `K1B`–`K6B`).
  - Real-time road geometry resolution via parallel actor workers (`RoadGeometryResolver`).

- 🎯 **Kelurahan & Quest Discovery**
  - Discover curated local quests grouped by Bali's kelurahan administrative boundaries.
  - Horizontal paging ticket rail with serrated postage cards, dynamic price tags, and authentic Bali artwork.
  - Detail page with badge image carousels, photo galleries, and multi-badge stacked postage stamp indicators.

- 🚶‍♂️ **Interactive Go Mode Navigation**
  - Step-by-step turn-by-turn and transit alighting guidance.
  - Live geofence-based mission check-in and photo keepsake capture at scenic Bali checkpoints.
  - Passive HealthKit integration calculating accurate steps and active calories burned during transit walks.

- 🏆 **Postage Stamp Celebration & Summary**
  - Automatic 3-second animated wrap-up transitioning into celebration summary cards.
  - Rotated `-4°` postage stamp frames with authentic badge art, starburst effects, and confetti.
  - Shareable trip summary cards featuring distance, cost savings, calories, and step metrics.

- 🔒 **Apple Authentication & Bookmarking**
  - Streamlined Sign in with Apple integration backed by Better Auth.
  - Secure Keychain storage for session tokens (`SessionTokenStore`).
  - Live quest route bookmarking and synchronization.

---

## Architecture & Directory Layout

```
transium/
├── Backend/                 # Networking, BetterAuth contracts, Multipart uploaders, API configuration
│   ├── APIClient.swift          # Core async/await URLSession engine with Bearer token injection
│   ├── APIConfiguration.swift   # Base URLs and backend endpoint paths
│   ├── APIErrors.swift          # Categorized network and server error mapping
│   ├── AuthBackendContract.swift# Authentication DTOs and protocols
│   ├── BetterAuthBackend.swift  # BetterAuth Apple exchange implementation
│   └── MultipartFormData.swift  # Streaming multipart payload builder for media uploads
│
├── Features/                # Domain models, services, and business logic
│   ├── Auth/                    # SessionController, SessionTokenStore (Keychain), AppleSignInService
│   ├── Bookmark/                # User quest bookmark models and services
│   ├── Camera/                  # AVFoundation CameraModel and UIKit preview integration
│   ├── Common/                  # Shared nonisolated models (LatLng, MediaAsset, Kelurahan, APIErrorResponse)
│   ├── Device/                  # APNs device token registration and push testing
│   ├── Journey/                 # Door-to-door transit overview, multi-leg segments, and step models
│   ├── Location/                # Geocoding, reverse-geocoding, and token resolvers
│   ├── Map/                     # LocationStore, TransiumMapStyleFactory, RoadGeometryResolver (Actor)
│   ├── Profile/                 # User profile models, SwiftData LocalProfile, and profile service
│   └── Quest/                   # Quest discovery catalogs, badge progression, and kelurahan grouping
│
├── Screens/                 # Screen-level SwiftUI views and interactive flows
│   ├── Auth/                    # Apple Sign-In screen with hero artwork and preview bypass
│   ├── Camera/                  # CameraScreen viewfinder and PhotoPreviewScreen keepsake flow
│   ├── DetailPage/              # DetailPlaceScreen with photo carousel and itinerary quest list
│   ├── GoModeScreen/            # GoComponentMode active navigation panel and mission checkpoints
│   ├── Home/                    # HomeScreen and Views/ (Ticket carousel, Pinning overlay, Quick menu)
│   ├── Loading/                 # Transit-themed loading animation view
│   ├── Onboarding/              # Multi-step onboarding carousel and Permission request screens
│   ├── Payment/                 # PaymentMethod transit fare and QRIS preparation screen
│   ├── Profile/                 # ProfileScreen (Account, Badges, Photo Moments Gallery)
│   ├── Saved Quest/             # SavedQuestScreen bookmark catalog
│   ├── Settings/                # SettingsScreen (Language, Audio volumes, Notification permissions)
│   ├── States/                  # EmptyStateScreen placeholder states
│   └── Summary/                 # SummaryScreen and Views/ (SummaryIntroView, SummaryCelebrationView)
│
├── UI/                      # Design system tokens and reusable UI components
│   ├── Components/              # TransiumButton, TransiumIconButton, TransiumStampCard, AppToast
│   └── System/                  # DesignTokens (TransiumColor, TransiumAsset, TransiumTransitColor, TransiumFont)
│
└── Resources/               # Fonts, local vector PMTiles, and guideline assets
    ├── Fonts/                   # Londrina Solid and Poppins font binaries
    └── Maps/                    # Offline bali_basemap.pmtiles and bali_transit.pmtiles
```

---

## Design System & Tokens

Transium is built with a bespoke Bali transit aesthetic utilizing strict typography and color tokens defined in `transium/UI/System/DesignTokens.swift`:

| Token Group | Font / Colors | Purpose |
| :--- | :--- | :--- |
| **Headings** | `TransiumFont.display` (Londrina Solid) | Bold, playful hero titles and badge banners |
| **Body & UI** | `TransiumFont.body` (Poppins) | High-legibility captions, buttons, and transit subtitles |
| **Primary Color** | `TransiumColor.primaryBlue` (`#316EFF`) | Core brand accent, active toggles, and main action buttons |
| **Secondary Color**| `TransiumColor.primaryYellow` (`#FFAE12`) | Stars, points highlights, and warning accents |
| **Dark Blue** | `TransiumColor.darkBlue` (`#071F55`) | High-contrast backgrounds and header text |
| **Transit Lines** | `TransiumTransitColor` | Dedicated palettes for bus lines `K1B` through `K6B` |

---

## Development & Build Requirements

- **macOS**: Sonoma / Sequoia
- **Xcode**: 16.0+ (iOS 18.0+ SDK / Deployment Target iOS 18+)
- **Architecture**: Swift 6 Strict Concurrency Mode compatible (`Sendable`, `nonisolated struct`)
- **Simulator Build**:
  ```bash
  xcodebuild -scheme transium -destination 'generic/platform=iOS Simulator' build
  ```

---

## Xcode SwiftUI Canvas Previews

Transium supports live Xcode Canvas Previews (`#Preview`). When running inside Xcode Previews:
- `AppEnvironment.DEV_MODE` automatically evaluates to `true`.
- `SessionTokenStore.read()` supplies `"debug-token-123"` as the Bearer token for previewing authenticated endpoints without requiring a real Apple Sign-In flow.

---

## Contributing & Git Guidelines

- All commits follow semantic message prefixes (`feat:`, `fix:`, `refactor:`, `style:`, `docs:`, `chore:`).
- Author: `Moon <faris.kocak@gmail.com>`.
- Branches: Work on `dev` / feature branches and merge to `dev`.
