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
│   ├── Badge/                   # User earned badges catalog and BadgeService
│   ├── Bookmark/                # User quest bookmark models and BookmarkService
│   ├── Camera/                  # AVFoundation CameraModel, UIImage+Compression, and photo preview
│   ├── Common/                  # Shared nonisolated models (LatLng, MediaAsset, Kelurahan, APIErrorResponse)
│   ├── Device/                  # APNs device token registration and push testing
│   ├── Gallery/                 # Moments gallery models, pagination, download, and GalleryService
│   ├── Journey/                 # Door-to-door transit overview, multi-leg segments, and step models
│   ├── Location/                # Geocoding, reverse-geocoding, and token resolvers
│   ├── Map/                     # LocationStore, TransiumMapStyleFactory, RoadSnapper, RoadGeometryResolver (Actor)
│   ├── Profile/                 # User profile models, SwiftData LocalProfile, and profile service
│   └── Quest/                   # Quest discovery catalogs, badge progression, and kelurahan grouping
│
├── Screens/                 # Screen-level SwiftUI views and modular view structures
│   ├── Auth/                    # Apple Sign-In screen with hero artwork and preview bypass
│   ├── Camera/                  # CameraScreen viewfinder and PhotoPreviewScreen keepsake flow
│   ├── DetailPage/              # DetailPlaceScreen with badge carousels, itinerary quest list, and bus fare badges
│   ├── GoModeScreen/            # GoComponentMode active navigation panel, stopsLeft counter, and mission checkpoints
│   ├── Home/                    # HomeScreen and Views/ (Ticket carousel, Pinning overlay, Quick menu)
│   │   ├── HomeScreen.swift         # Main root coordinator
│   │   ├── HomeViewModel.swift      # Combine-driven reactive map, location, and quest state
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
│   └── Summary/                 # SummaryScreen and Views/ (SummaryIntroView, SummaryCelebrationView, SummaryMapView, SummaryStoryCardView)
│       ├── SummaryScreen.swift                  # 3-second transition coordinator & data resolver
│       └── Views/
│           ├── SummaryIntroView.swift           # Intro wrap-up view with 165pt postage stamp
│           ├── SummaryCelebrationView.swift     # Celebration card with coaxial BadgeShine, 190pt stamp, 230pt vector map & confetti
│           ├── SummaryMapView.swift             # MapLibre vector route snapshot & auto-framing container
│           ├── SummaryStoryCardView.swift       # 9:16 Instagram Story card renderer with MapLibre basemap
│           └── SummaryReportCard.swift          # Reusable summary metrics component
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

### 1. Map, Road Snapping & Transit Routing Engine
- **MapLibre Offline Foundation**: Powered by offline PMTiles vector layers (`bali_basemap.pmtiles` and `bali_transit.pmtiles`) via `TransiumMapStyleFactory`.
- **Interactive Map Under Sheets**:
  - Full-screen touch interceptors removed across `HomeScreen` and `GoComponentMode`, allowing user gestures (pan, pinch, zoom, rotate) to pass directly to `LocalBaliMapView` while sheets and drawers are open.
  - Native `.presentationBackgroundInteraction(.enabled)` configured on search and pinning sheets.
- **20m Road-Snapping (`RoadSnapper`)**:
  - Orthogonally projects user location and raw GTFS stop coordinates directly onto active route polylines and vector road tile layers (`roads`, `roads-casing`).
  - Snaps when within $\le 20\text{m}$; allows free movement when beyond $20\text{m}$.
  - Snaps all intermediate, boarding, and alighting stop circles directly onto the centerline of the active route polyline.
- **Bus Travel Direction Lock**:
  - When traversing a bus corridor in Go Mode, user annotation cone and camera heading lock to the forward direction along the bus road geometry, avoiding device compass spin while inside a bus.
- **Dynamic 3D Marker Tilt**:
  - Marker orientation dynamically leans into 3D perspective proportional to live MapLibre camera pitch.
- **Concurrent Road Corridor Resolution (`RoadGeometryResolver`)**:
  - Pre-resolves all transit segments concurrently in parallel using `withTaskGroup`.
  - Calculates exact street-following geometry through consecutive stop pairs along `segment.stops` to follow real inland bus avenue corridors (Jl. Imam Bonjol, Jl. Teuku Umar, Jl. Sudirman) rather than toll bypasses.
  - Caches resolved polyline coordinates in-memory for instant frame rendering with zero snapping.
- **Route Line Aesthetics & Map Framing**:
  - Bus routes render with white outer casings (8pt) and official transit line colors (5pt) matching `K1B` through `K6B`.
  - Walking legs render with crisp emerald green dashed paths (4.5pt) and white casings.
  - Dynamic route bounding box calculations with 12% margin expansion and 22pt padding insets to prevent route clipping in celebration views.

### 2. Postage Stamp Design System (`TransiumStampCard` & `QuestBadgePostageStack`)
- Reusable postage stamp cards featuring serrated postage stamp borders, customizable tilt angles, drop shadows, and theme variants (`.classic`, `.blue`, `.warm`, `.green`).
- **Coaxial Sunburst Centering**: `Image("BadgeShine")` is nested directly behind `BadgeArtworkStamp` / `TransiumStampCard` on the same Y-axis center to radiate light rays authentically from the postage stamp.
- **Deterministic Multi-Badge Stacking**:
  - **1 Badge**: Size `72`, `tilt: 0°`, offset `(0, 0)`.
  - **2 Badges**: Scaled to `62`–`64`, scattered with back badge (`tilt: -8°`, offset `(-6, -4)`) and front badge (`tilt: +6°`, offset `(+5, +4)`).
  - **3 Badges**: Scaled down to `52`–`56`, scattered with bottom badge (`tilt: -12°`, offset `(-10, -6)`), middle badge (`tilt: +10°`, offset `(+8, -3)`), and top badge (`tilt: -2°`, offset `(0, +6)`).

### 3. Summary Celebration & Instagram Story Sharing
- **Two-Step Celebration Flow**: Automatic 3-second animated intro (`SummaryIntroView`) transitioning into `SummaryCelebrationView` with smooth step-2 map entrance.
- **Instagram Story Card Engine (`SummaryStoryCardView` & `SummaryStoryShareManager`)**:
  - High-resolution 9:16 story card rendering matching Transium brand identity (`TransiumColor.primaryBlue`, `BadgeShine`, confetti, outlined title, 4-stat metrics grid).
  - Uses live MapLibre vector basemap snapshots (`SummaryMapSnapshotCache`) and pre-cached badge assets (`TransiumImageCache`).
  - Direct sharing via `instagram-stories://share` with fallback to standard `UIActivityViewController`.

### 4. Custom Modal System & Live Activity Lifecycle
- **Branded Conflict Dialog**: Custom overlay card replacing system alerts for active journey conflicts (`journeyConflictModal`) with Transium typography (`TransiumFont.display`), warning badge icon, and branded primary/destructive buttons.
- **Immediate ActivityKit Dismissal**: `LiveActivityManager.shared.endAllActivities(dismissalPolicy: .immediate)` immediately terminates Dynamic Island and lock screen activities upon journey completion or cancellation.

### 5. Swift 6 Concurrency & Strict Types
- All API and domain DTOs are declared `public nonisolated struct` / `public nonisolated enum` to enable seamless data transfer across background actor boundaries (`RoadGeometryResolver`, background services) without `MainActor` isolation friction.
- Modern iOS MapKit integration utilizing version-checked `MKMapItem(location:address:)` and backward-compatible fallback constructors.

### 6. Authentication & Keychain Token Management
- Powered by Better Auth with Apple Sign-In exchange.
- Session tokens stored securely in iOS Keychain via `SessionTokenStore`.
- Automatic Bearer token header injection in `APIClient`.
- `#Preview` canvas environments automatically use `"debug-token-123"` to render live UI without requiring full sign-in flows.

---

## Git Workflow & Branch Strategy

- **`dev`**: The primary integration branch consolidating map navigation, backend services, and all new feature screens (`Profile`, `Settings`, `DetailPage`, `Camera`, `Payment`, `SearchSheet`, `Summary`).
- **`main`**: Production release baseline.
- **Author Identity**: All commits are authored and committed as `Moon <faris.kocak@gmail.com>` (`msafdev`).
