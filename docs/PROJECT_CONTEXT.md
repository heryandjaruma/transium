# Project Context & Architecture Guide

## Status On August 19, 2026

`transium` is a high-performance native iOS SwiftUI application for smart transit and urban discovery in Bali. The repository combines an offline MapLibre vector tile rendering engine, real-time arterial corridor transit polyline calculations, complete OpenAPI backend integration, and a production-grade UI design system.

---

## Architecture & Code Structure

```
transium/
├── Backend/                 # Networking, BetterAuth contracts, Multipart uploaders, API configuration
│   ├── APIClient.swift          # Core async/await URLSession engine with automatic Bearer token injection
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
│   ├── Location/                # Geocoding, place autocomplete suggestions, and token resolvers
│   ├── Map/                     # LocationStore, TransiumMapStyleFactory, RoadGeometryResolver (Actor)
│   ├── Profile/                 # User profile models, SwiftData LocalProfile, and profile service
│   └── Quest/                   # Quest discovery catalogs, badge progression, and kelurahan grouping
│
├── Screens/                 # Screen-level SwiftUI views and interactive flows
│   ├── Auth/                    # Apple Sign-In screen with hero artwork and preview bypass
│   ├── Camera/                  # CameraScreen viewfinder and PhotoPreviewScreen keepsake flow
│   ├── DetailPage/              # DetailPlaceScreen with photo carousel, itinerary quest list, and bus fare badges
│   ├── Home/                    # HomeScreen, LocalBaliMapView, NavigationBottomSheet, and SearchSheetView
│   ├── Loading/                 # Transit-themed loading animation view
│   ├── Onboarding/              # Multi-step onboarding carousel and Permission request screens
│   ├── Payment/                 # PaymentMethod transit fare and QRIS preparation screen
│   ├── Profile/                 # ProfileScreen (Account, Badges, Photo Moments Gallery)
│   └── Settings/                # SettingsScreen (Language, Audio volumes, Notification permissions)
│
├── UI/                      # Design system tokens and reusable UI components
│   ├── Components/              # TransiumButton, TransiumIconButton, TransiumTicketCard, PageIndicator, AppToast
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
  - Calculates exact street-following geometry through consecutive stop pairs along `segment.stops` to follow the real inland bus avenue corridors (Jl. Imam Bonjol, Jl. Teuku Umar, Jl. Sudirman) rather than automobile toll bypasses.
  - Automatically falls back to pedestrian/restricted routing if highway access is restricted.
  - Caches resolved polyline coordinates in-memory for instant frame rendering with zero visual snapping or chord lines.
- **Route Line Aesthetics**:
  - Bus routes render with white outer casings (8pt) and official transit line colors (5pt) matching `K1B` through `K6B`.
  - Walking legs render with crisp emerald green dashed paths (4.5pt) and white casings.
  - Custom interactive stop annotations differentiate boarding (flag), intermediate (circle), and alighting points.

### 2. Design System & Typography
- **Display Typography**: `TransiumFont.display` using Londrina Solid (`LondrinaSolid-Black`, `LondrinaSolid-Light`, `LondrinaSolid-Regular`).
- **Body & Controls Typography**: `TransiumFont.body` using Poppins (`Poppins-Bold`, `Poppins-SemiBold`, `Poppins-Medium`, `Poppins-Regular`).
- **Color Palette**: `TransiumColor.primaryBlue` (`#316EFF`), `TransiumColor.primaryYellow` (`#FFAE12`), `TransiumColor.darkBlue` (`#071F55`), and curated ticket/transit palettes (`TransiumTransitColor`).
- **Haptics & Transitions**: Smooth spring animations (`.spring(response: 0.45, dampingFraction: 0.82)`) paired with `UINotificationFeedbackGenerator` and `UIImpactFeedbackGenerator`.

### 3. Swift 6 Concurrency & Strict Types
- All API and domain DTOs are declared `public nonisolated struct` / `public nonisolated enum` to enable seamless data transfer across background actor boundaries (`RoadGeometryResolver`, background services) without `MainActor` isolation friction.
- Modern iOS 26+ MapKit integration utilizing version-checked `MKMapItem(location:address:)` and backward-compatible fallback constructors.

---

## Git Workflow & Branch Strategy

- **`dev`**: The primary integration branch consolidating map navigation, backend services, and all new feature screens (`Profile`, `Settings`, `DetailPage`, `Camera`, `Payment`, `SearchSheet`).
- **`map`**: MapLibre rendering, dynamic route calculation, and full API service architecture.
- **`main`**: Production release baseline.
- **Author Identity**: All commits are authored and committed as `Moon <faris.kocak@gmail.com>` (`msafdev`).
