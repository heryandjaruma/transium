# Project Context

## Status On August 19, 2026

`transium` is a native iOS SwiftUI app for smart transit and urban discovery in Bali. The repository includes a full-featured MapLibre-powered transit navigation engine, comprehensive OpenAPI-compliant backend services, an end-to-end screen suite, and native Sign in with Apple integration.

## Repository Shape

- `transium/transiumApp.swift`: App lifecycle, SwiftData container, and environment injection.
- `transium/ContentView.swift`: Top-level routing (Onboarding -> Apple Auth -> Home Map).
- `transium/Screens/`:
  - `Onboarding/`: Multi-step onboarding carousel and permission request views (`Permission.swift`).
  - `Auth/`: Native Sign in with Apple with BetterAuth backend integration and preview bypass.
  - `Home/`: Interactive MapLibre native map, search/pinning sheet (`SearchSheetView.swift`), ticket carousel, "Do Quest" route calculation, and collapsible navigation drawer (`NavigationBottomSheet.swift`).
  - `DetailPage/`: Rich place detail screen (`DetailPageScreen.swift`) with photo gallery, quest cards, and transit details.
  - `Profile/`: User profile (`ProfileScreen.swift`) featuring Account management, Badges/achievements, and quest photo Gallery.
  - `Settings/`: User preferences, permission management, and legal policies (`SettingsScreen.swift`).
  - `Camera/`: Custom AVFoundation camera viewfinder (`CameraScreen.swift`) and quest photo capture preview (`PhotoPreviewScreen.swift`).
  - `Loading/`: Transit-themed loading animation (`LoadingScreen.swift`).
  - `Payment/`: Transit fare and QRIS payment method selection (`PaymentMethod.swift`).
- `transium/Backend/`:
  - `APIClient.swift`: Async network engine supporting JSON and multipart upload payloads with automatic Bearer token injection.
  - `APIConfiguration.swift`: Base URL definitions (`/api` endpoints and BetterAuth paths).
  - `APIErrors.swift` & `MultipartFormData.swift`: Error categorization and multipart request builders.
- `transium/Features/`:
  - `Auth/`: Authentication state store, Keychain token management (`SessionTokenStore.swift`), and `SessionController.swift`.
  - `Bookmark/`: Bookmark models and services (`BookmarkService.swift`).
  - `Camera/`: Camera session manager and UIKit preview integration (`CameraModel.swift`, `CameraPreviewView.swift`).
  - `Device/`: Push notification device registration service (`DeviceService.swift`).
  - `Journey/`: Route planning models, multi-leg segments, and overview services (`JourneyService.swift`).
  - `Location/`: Geocoding, place autocomplete, and token resolution (`LocationService.swift`).
  - `Map/`: MapLibre PMTiles style generator (`TransiumMapStyleFactory.swift`).
  - `Profile/`: Server-backed profile models and avatar management (`ProfileService.swift`).
  - `Quest/`: Quest catalogs, badge retrieval, and kelurahan groupings (`QuestService.swift`).
- `transium/UI/`:
  - `System/DesignTokens.swift`: Color palette, typography (`Londrina Solid` & `Poppins`), transit line color mapping (`TransiumTransitColor`), and preview environment flags.
  - `Components/`: Shared UI buttons (`TransiumButton`), icon buttons, page indicators, ticket cards, and `AppToastCenter`.
- `transium/Resources/`:
  - `Fonts/`: Londrina Solid display font and Poppins body font family.
  - `Maps/`: Bundled offline `bali_basemap.pmtiles` and `bali_transit.pmtiles`.
  - `Maps/guidelines.md`: Map PMTiles and vector layer documentation.

## Map & Transit Routing Architecture

- **MapLibre Engine**: Uses offline bundled PMTiles for land, district borders, roads, and transit networks.
- **Route Visualization**:
  - Bus segments dynamically follow exact road geometry using MapKit direction requests and render with official route colors (`K1B`, `K2B`, `K3B`, `K4B`, `K5B`, `K6B`, `I1`, `TS1`).
  - Walking segments render as distinct emerald green dashed trails with white casing.
  - Interactive transit stop pins highlight departure, intermediate transfer, and arrival points.

## Backend & API Integration

- Direct integration with Cloudflare Workers backend (`https://transium-api.heryandjaruma.workers.dev/api`).
- Complete OpenAPI client layer documented in [API.md](file:///Users/msafdev/Code/swift/transium/docs/API.md).

## Branches

- `main`: Production-ready baseline.
- `map`: MapLibre rendering, dynamic route calculation, and full API service architecture.
- `noia_punya`: Feature UI additions (Profile, Settings, Camera, Detail Page, Payments, Search Sheet).
- `dev`: Unified integration branch consolidating `map` and `noia_punya` with best practices and synchronized build configuration.

