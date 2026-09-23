# Go Mode & Summary Celebration Guide

## 1. Overview

**Go Mode** and the **Summary Celebration Flow** form the core gamified travel loop in Transium:
1. **Planning & Start**: The user explores Kelurahan quests, picks an itinerary, and launches Go Mode via `POST /private/journey/go`.
2. **Turn-by-Turn & Geofencing**: Live GPS tracking monitors transit corridors and checkpoint arrivals (`POST /private/journey/{id}/advance`).
3. **Spontaneous Photo Ops**: Spontaneous keepsake photo points pop up camera prompts at scenic Bali stops (`RandomPhotoOpPlanner`).
4. **Completion & HealthKit**: Once all steps reach `.done`, HealthKit passively aggregates steps and calories, submitting `POST /private/journey/{id}/complete`.
5. **Summary Presentation**: `SummaryScreen` presents a 3-second `SummaryIntroView` before cross-fading into `SummaryCelebrationView` with rotated postage stamp badges and confetti.

---

## 2. Go Mode Architecture

### Native Sheet & UI Presentation (`GoComponentMode`)
- Presented as a native SwiftUI `.sheet` with `presentationDetents([.height(110), .fraction(0.55)])` and `presentationBackgroundInteraction(.enabled)`.
- Map and navigation controls remain fully interactive underneath while the user drags between the collapsed "Trip Details" peek and the full itinerary timeline.

### Real-Time `stopsLeft` Count
- While on an active bus leg, `GoComponentMode` calculates the remaining stops count in real time based on the user's distance and passed intermediate bus stop checkpoints.

### Road Snapping & Bus Heading Alignment (`RoadSnapper`)
- Snaps user GPS location to active route polylines and vector road tile layers within $\le 20\text{m}$.
- Snaps all intermediate, boarding, and alighting stop circles directly onto the centerline of the active route polyline.
- Locks marker cone and camera heading to the forward road geometry while on a bus to avoid compass jitters.

### Geofence Lifecycle
- `JourneyGeofenceMonitor` manages dynamic CoreLocation circular regions based on `step.lat`, `step.lng`, and `step.radiusMeters` (default ~69m).
- When a user enters a geofenced area, `handleGeofenceEntered` triggers:
  - If the step requires a photo (`step.isPhotoCheckpoint`), `CameraScreen` is presented automatically after a brief 5-second grace period.
  - An advance request is sent via `journeyService.advanceJourney`.
  - The step is removed from active geofence monitoring.

### Spontaneous Photo Ops (`RandomPhotoOpPlanner`)
- Generates 0–2 spontaneous keepsake points along intermediate transit corridors.
- Monitored on an independent `randomPhotoOpMonitor` to ensure cosmetic photo ops never block or modify actual quest progress.

### HealthKit Integration (`HealthKitStepService`)
- Passively queries `HKHealthStore` for cumulative steps and active energy burned between `startedAt` and completion time.
- Falls back to distance-based estimates if HealthKit permissions are unavailable.

---

## 3. Summary Screens Architecture

```
Screens/Summary/
├── SummaryScreen.swift                  // Root coordinator (3-sec cross-fade, location resolvers)
└── Views/
    ├── SummaryIntroView.swift           // 165pt rotated postage stamp wrap-up
    ├── SummaryCelebrationView.swift     // 190pt postage stamp with coaxial BadgeShine, 230pt vector map & 4-stat grid
    ├── SummaryMapView.swift             // MapLibre vector route snapshot & auto-framing container
    ├── SummaryStoryCardView.swift       // 9:16 Instagram Story card renderer with MapLibre basemap
    └── SummaryReportCard.swift          // Reusable summary metrics component
```

### 1. `SummaryIntroView`
- Displayed immediately upon journey completion.
- Features the badge artwork framed inside a `165pt` `TransiumStampCard` with `-4°` rotation.
- Shows total calories burned with motivational comparison text ("like doing 1,000 jumping jacks 🥵").

### 2. `SummaryCelebrationView`
- Transitions in after 2.8–3.0 seconds via smooth spring and opacity animation.
- Visual elements:
  - **Coaxial Sunburst Shine (`BadgeShine`)**: Sunburst rays nested in the exact same `ZStack` as the badge stamp on the same Y-axis center.
  - **Confetti Pops**: Pop animations for `Confetti-L` and `Confetti-R`.
  - **Hero Postage Stamp**: `190pt` `BadgeArtworkStamp` rotated `-7.5°`.
  - **Floating Outlined Title**: Outlined quest title (`OutlinedText` rotated `-5°`) with starburst splash (`Splash`).
  - **White Content Card**:
    - Route header: Origin (red pin) ➔ Destination (green pin).
    - **Dynamic Vector Map (`SummaryMapView`)**: `230pt` height, smooth entrance animation, full route polyline rendering with white road casing.
    - **4-Stat Metrics Grid (`SummaryBox`)**: Distance (km), Cost Saved (Rp), Calories, and Total Steps.
  - **Action Buttons**: "Share your experience" (Instagram Story export) and "Go to the Next Trip!".

### 3. Vector Map Snapshotting (`SummaryMapView`)
- Custom `UIViewRepresentable` wrapping `SummaryMapContainerView` (`MLNMapView`).
- Pre-centers camera on route midpoint coordinate.
- Automatically calculates coordinate bounding box with `12%` margin padding and `22pt` edge insets to prevent start/dest pin clipping.
- Captures Metal framebuffer into `SummaryMapSnapshotCache.shared` for zero-delay offline rendering in story shares.

### 4. Instagram Story Share (`SummaryStoryCardView` & `SummaryStoryShareManager`)
- **Dimensions**: Formatted for 9:16 canvas ratio (`414 × 896 pt`).
- **Brand Consistency**: Uses authentic Transium primary blue (`TransiumColor.primaryBlue`), coaxial `BadgeShine` sunburst rays, tilted postage stamp badge, outlined title, route summary pill, and MapLibre vector map snapshot.
- **Sharing Pipeline**:
  1. Pre-caches quest badge `UIImage` from `TransiumImageCache` or loads synchronously.
  2. Grabs latest vector map snapshot from `SummaryMapSnapshotCache.shared`.
  3. Renders `SummaryStoryCardView` via `ImageRenderer`.
  4. Copies sticker image pasteboard data and deep-links to `instagram-stories://share` with fallback to `UIActivityViewController`.

---

## 4. Postage Stamp Design (`TransiumStampCard`)

Postage stamp cards across Transium use template rendering with authentic serrated edges:
- **`TransiumStampVariant`**: Supports `.classic`, `.blue`, `.warm`, and `.green` frame colors and shadow depths.
- **Tilt Angle**: Typically `-4°`, `-5°`, or `-7.5°` to provide playful physical stamp character.
- **Async Image Loading**: Built-in shimmer loading placeholders and asset image fallbacks.
- **Coaxial Alignment**: Centered directly with background sunburst shines without hardcoded vertical offsets.
