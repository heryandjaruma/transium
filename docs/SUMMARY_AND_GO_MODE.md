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
├── SummaryScreen.swift                  // Root coordinator (3-sec cross-fade)
└── Views/
    ├── SummaryIntroView.swift           // 165pt rotated postage stamp wrap-up
    ├── SummaryCelebrationView.swift     // 155pt rotated postage stamp with confetti & stat grid
    └── SummaryReportCard.swift          // Reusable summary metrics component
```

### 1. `SummaryIntroView`
- Displayed immediately upon journey completion.
- Features the badge artwork framed inside a `165pt` `TransiumStampCard` with `-4°` rotation.
- Shows total calories burned with motivational comparison text ("like doing 1,000 jumping jacks 🥵").

### 2. `SummaryCelebrationView`
- Transitions in after 3 seconds via smooth cross-fade animation.
- Visual elements:
  - Background radial shine (`BadgeShine`).
  - Colorful confetti particles (`Confetti-L`, `Confetti-R`).
  - Rotated `155pt` `TransiumStampCard` badge.
  - Floating outlined quest title with starburst splash (`OutlinedText` rotated `-5°`).
  - White route and stats summary card (Distance, Travel Cost saved, Calories, Steps).
  - "Share your experience" and "Go to the Next Trip!" actions.

---

## 4. Postage Stamp Design (`TransiumStampCard`)

Postage stamp cards across Transium use template rendering with authentic serrated edges:
- **`TransiumStampVariant`**: Supports `.classic`, `.blue`, `.warm`, and `.green` frame colors and shadow depths.
- **Tilt Angle**: Typically `-4°` or `-5°` to provide playful physical stamp character.
- **Async Image Loading**: Built-in shimmer loading placeholders and asset image fallbacks.
