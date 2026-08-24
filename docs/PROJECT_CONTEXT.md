# Project Context & Architecture Guide

## Status Overview

`transium` is a high-performance native iOS SwiftUI application for smart transit navigation, urban discovery, and gamified quest journeys in Bali. The repository integrates:
- Offline MapLibre vector tile rendering engine backed by PMTiles (`bali_basemap.pmtiles`, `bali_transit.pmtiles`).
- Concurrent road geometry resolution using `RoadGeometryResolver` (Swift Actor) for inland corridor transit routing.
- Complete private OpenAPI backend integration with Better Auth Bearer token authentication.
- Live Geofence Monitoring, HealthKit passive step and calorie recording, and camera photo captures for Go Mode journeys.
- Gamified postage stamp badge rewards, celebration summary cards, and quest bookmarking.

---

## Architecture & Code Structure

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
│   ├── Bookmark/                # User quest bookmark models and BookmarkService
│   ├── Camera/                  # AVFoundation CameraModel and UIKit preview integration
│   ├── Common/                  # Shared nonisolated models (LatLng, MediaAsset, Kelurahan, APIErrorResponse)
│   ├── Device/                  # APNs device token registration and push testing
│   ├── Journey/                 # Door-to-door transit overview, multi-leg segments, and step models
│   ├── Location/                # Geocoding, reverse-geocoding, and token resolvers
│   ├── Map/                     # LocationStore, TransiumMapStyleFactory, RoadGeometryResolver (Actor)
│   ├── Profile/                 # User profile models, SwiftData LocalProfile, and profile service
│   └── Quest/                   # Quest discovery catalogs, badge progression, and kelurahan grouping
│
├── Screens/                 # Screen-level SwiftUI views and modular view structures
│   ├── Auth/                    # Apple Sign-In screen with hero artwork and preview bypass
│   ├── Camera/                  # CameraScreen viewfinder and PhotoPreviewScreen keepsake flow
│   ├── DetailPage/              # DetailPlaceScreen with badge carousels, itinerary quest list, and bus fare badges
│   ├── GoModeScreen/            # GoComponentMode active navigation panel and mission checkpoints
│   ├── Home/                    # HomeScreen and Views/ (Ticket carousel, Pinning overlay, Quick menu)
│   │   ├── HomeScreen.swift         # Main root coordinator
│   │   ├── SearchSheetView.swift    # Place search & starting point picker sheet
│   │   └── Views/
│   │       ├── HomeBottomTicketCarousel.swift   # Ticket rail carousel & location pill
│   │       ├── HomeNavigationControls.swift     # Navigation top bar & "Go" action stack
│   │       ├── HomeQuickMenuView.swift          # Floating 3-dot FAB menu
│   │       ├── HomePinningOverlayView.swift     # Pin-drop overlay controls & center pin indicator
│   │       ├── HomeLocationHelper.swift         # Kelurahan coordinates & distance calculations
│   │       ├── LocalBaliMapView.swift           # MapLibre map representation & polyline overlays
│   │       ├── NavigationBottomSheet.swift      # Itinerary bottom sheet
│   │       └── OngoingTripCard.swift            # Ongoing active journey banner
│   ├── Loading/                 # Transit-themed loading animation view
│   ├── Onboarding/              # Multi-step onboarding carousel and Permission request screens
│   ├── Payment/                 # PaymentMethod transit fare and QRIS preparation screen
│   ├── Profile/                 # ProfileScreen (Account, Badges, Photo Moments Gallery)
│   ├── Saved Quest/             # SavedQuestScreen bookmark catalog
│   ├── Settings/                # SettingsScreen (Language, Audio volumes, Notification permissions)
│   ├── States/                  # EmptyStateScreen placeholder states
│   └── Summary/                 # SummaryScreen and Views/ (SummaryIntroView, SummaryCelebrationView)
│       ├── SummaryScreen.swift                  # 3-second transition coordinator
│       └── Views/
│           ├── SummaryIntroView.swift           # Intro wrap-up view with 165pt postage stamp
│           ├── SummaryCelebrationView.swift     # Celebration card with 155pt postage stamp & confetti
│           └── SummaryReportCard.swift          # Reusable summary report card component
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

## Key Subsystems & Design Highlights

### 1. Map & Transit Routing Engine
- **MapLibre Offline Foundation**: Powered by offline PMTiles vector layers (`bali_basemap.pmtiles` and `bali_transit.pmtiles`) via `TransiumMapStyleFactory`.
- **Concurrent Road Corridor Resolution (`RoadGeometryResolver`)**:
  - Pre-resolves all transit segments concurrently in parallel using `withTaskGroup`.
  - Calculates exact street-following geometry through consecutive stop pairs along `segment.stops` to follow real inland bus avenue corridors (Jl. Imam Bonjol, Jl. Teuku Umar, Jl. Sudirman) rather than toll bypasses.
  - Caches resolved polyline coordinates in-memory for instant frame rendering with zero snapping.
- **Route Line Aesthetics**:
  - Bus routes render with white outer casings (8pt) and official transit line colors (5pt) matching `K1B` through `K6B`.
  - Walking legs render with crisp emerald green dashed paths (4.5pt) and white casings.
  - Custom interactive stop annotations differentiate boarding (flag), intermediate (circle), and alighting points.

### 2. Postage Stamp Design System (`TransiumStampCard` & `QuestBadgePostageStack`)
- Reusable postage stamp cards featuring serrated postage stamp borders, customizable tilt angles, drop shadows, and theme variants (`.classic`, `.blue`, `.warm`, `.green`).
- **Deterministic Multi-Badge Stacking**:
  - **1 Badge**: Size `72`, `tilt: 0°`, offset `(0, 0)`.
  - **2 Badges**: Scaled to `62`–`64`, scattered with back badge (`tilt: -8°`, offset `(-6, -4)`) and front badge (`tilt: +6°`, offset `(+5, +4)`).
  - **3 Badges**: Scaled down to `52`–`56`, scattered with bottom badge (`tilt: -12°`, offset `(-10, -6)`), middle badge (`tilt: +10°`, offset `(+8, -3)`), and top badge (`tilt: -2°`, offset `(0, +6)`).

### 3. Swift 6 Concurrency & Strict Types
- All API and domain DTOs are declared `public nonisolated struct` / `public nonisolated enum` to enable seamless data transfer across background actor boundaries (`RoadGeometryResolver`, background services) without `MainActor` isolation friction.
- Modern iOS MapKit integration utilizing version-checked `MKMapItem(location:address:)` and backward-compatible fallback constructors.

### 4. Authentication & Keychain Token Management
- Powered by Better Auth with Apple Sign-In exchange.
- Session tokens stored securely in iOS Keychain via `SessionTokenStore`.
- Automatic Bearer token header injection in `APIClient`.
- `#Preview` canvas environments automatically use `"debug-token-123"` to render live UI without requiring full sign-in flows.

---

## Git Workflow & Branch Strategy

- **`dev`**: The primary integration branch consolidating map navigation, backend services, and all new feature screens (`Profile`, `Settings`, `DetailPage`, `Camera`, `Payment`, `SearchSheet`, `Summary`).
- **`main`**: Production release baseline.
- **Author Identity**: All commits are authored and committed as `Moon <faris.kocak@gmail.com>` (`msafdev`).
