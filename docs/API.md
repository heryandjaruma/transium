# Transium API Reference

This document outlines the complete REST API endpoints, schemas, authentication protocols, and data models provided by the Transium Backend service (`https://transium-api.heryandjaruma.workers.dev`).

---

## 1. Base URLs & Configuration

- **Production API Base**: `https://transium-api.heryandjaruma.workers.dev/api`
- **OpenAPI JSON Schema**: `https://transium-api.heryandjaruma.workers.dev/api/openapi.json`
- **Scalar Interactive Docs**: `https://transium-api.heryandjaruma.workers.dev/reference`

Configuration in the codebase is managed via [`transium/Backend/APIConfiguration.swift`](file:///Users/msafdev/Code/swift/transium/transium/Backend/APIConfiguration.swift).

### Authorization Header
All endpoints under `/api/private/*` require an HTTP `Authorization` header:
```http
Authorization: Bearer <session-token>
```
Tokens are stored securely in iOS Keychain via `SessionTokenStore`. When running in Xcode SwiftUI Previews (`AppEnvironment.DEV_MODE`), `"debug-token-123"` is injected automatically.

---

## 2. Kelurahan & Quest Discovery Endpoints

### `GET /api/private/kelurahan/quest`
Lists all Kelurahan groups containing quests, with optional distance calculation relative to the user's starting location.

- **Auth**: Required (`Bearer <token>`)
- **Query Parameters**:
  - `origin` (string, optional): Starting coordinate as `lat,lng` (e.g. `-8.702105,115.176189`). When provided, `distanceMeters` is calculated for each quest.

#### Response (200 OK)
```json
{
  "groups": [
    {
      "kelurahan": {
        "id": "7760985",
        "kelurahanName": "Benoa",
        "kecamatanName": "Kuta Selatan",
        "description": "Scenic southern coastal region",
        "thumbnails": [
          {
            "id": "c711fa7a-d0a4-4f0f-8c3b-ef90731a5450",
            "url": "https://storage.googleapis.com/.../benoa.jpg",
            "type": "image/jpeg"
          }
        ]
      },
      "quests": [
        {
          "id": "9d136db8-9c86-4222-8c2c-80240c44b85c",
          "name": "Explore Nusa Dua Coast",
          "category": "Beach",
          "description": "Discover white sand beaches and coral reefs.",
          "xp": 10,
          "distanceMeters": 4200,
          "thumbnails": [
            {
              "id": "89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969",
              "url": "/media/system/quest/9d136db8.../thumb.jpg",
              "type": "image/jpeg"
            }
          ]
        }
      ]
    }
  ]
}
```

---

### `GET /api/private/kelurahan/{id}/quest`
Retrieves detailed quests and badge associations for a specific Kelurahan.

- **Auth**: Required (`Bearer <token>`)
- **Path Parameters**:
  - `id` (string, required): Kelurahan ID (e.g. `7760985`).

#### Response (200 OK)
```json
{
  "kelurahan": {
    "id": "7760985",
    "kelurahanName": "Benoa",
    "kecamatanName": "Kuta Selatan",
    "thumbnails": [...]
  },
  "quests": [
    {
      "id": "9d136db8-9c86-4222-8c2c-80240c44b85c",
      "name": "Bougenville Trail",
      "category": "Leisure",
      "description": "Bougie vibez along the boulevard.",
      "xp": 10,
      "thumbnails": [...],
      "badges": [
        {
          "id": "3729e521-be0e-4ac3-9a02-7339b0123007",
          "badgeId": "ae2cf1b2-e536-416b-9db7-d7e76c6f3443",
          "badgeName": "Sanoored",
          "badgeCategory": "Explore",
          "badgeType": "quest",
          "badgeImageUrl": "/media/system/badge/.../badge.png"
        }
      ]
    }
  ]
}
```

---

### `GET /api/private/quest/{id}`
Retrieves full details for a specific quest, including origin/destination anchor coordinates and all checkpoint badge steps.

#### Response (200 OK)
```json
{
  "quest": {
    "id": "9d136db8-9c86-4222-8c2c-80240c44b85c",
    "name": "Sanur Sunrise Quest",
    "category": "Nature",
    "description": "Catch early sunrise and local markets.",
    "xp": 15,
    "thumbnails": [...],
    "badges": [
      {
        "id": "b1",
        "badgeId": "badge-1",
        "badgeName": "Early Bird",
        "badgeCategory": "Explore",
        "badgeType": "quest",
        "badgeImageUrl": "https://.../early_bird.png",
        "steps": [
          {
            "id": "step-1",
            "badgeId": "badge-1",
            "actionId": "act-1",
            "actionName": "Arrive at Pantai Karang",
            "type": "location",
            "sequence": 1,
            "lat": -8.6942,
            "lng": 115.2638,
            "instruction": "Walk to the pavilion marker."
          }
        ]
      }
    ],
    "origin": { "lat": -8.7021, "lng": 115.1762 },
    "destination": { "lat": -8.6942, "lng": 115.2638 }
  }
}
```

---

## 3. Location & Geocoding Endpoints

### `GET /api/maps/reverse-geocode`
Converts coordinates to human-readable street names and locality labels in Bali.

- **Query Parameters**:
  - `lat` (double, required): Latitude (e.g. `-8.73704`).
  - `lng` (double, required): Longitude (e.g. `115.17570`).

#### Response (200 OK)
```json
{
  "results": [
    {
      "label": "Jl. Raya Tuban, Kuta, Kabupaten Badung",
      "lat": -8.73704,
      "lng": 115.17570
    }
  ]
}
```

---

### `GET /api/maps/autocomplete`
Provides real-time search suggestions for Bali landmarks, bus stops, and venues.

- **Query Parameters**:
  - `input` (string, required): Partial query text.

#### Response (200 OK)
```json
{
  "suggestions": [
    {
      "placeId": "place_12345",
      "mainText": "Sanur Port",
      "secondaryText": "Jl. Hang Tuah, Denpasar Selatan"
    }
  ]
}
```

---

## 4. Transit & Journey Routing Endpoints

### `GET /api/journey/overview`
Calculates door-to-door transit itineraries between any two Bali coordinates.

- **Query Parameters**:
  - `origin` (string, required): `lat,lng`
  - `destination` (string, required): `lat,lng`

#### Response (200 OK)
```json
{
  "alternativesAvailable": false,
  "best": {
    "origin": { "lat": -8.7021, "lng": 115.1762 },
    "destination": { "lat": -8.6882, "lng": 115.2635 },
    "summary": {
      "distanceMeters": 14200,
      "walkingDistanceMeters": 680,
      "walkingDurationSeconds": 540,
      "transitDistanceMeters": 13520,
      "busLegCount": 1,
      "transferCount": 0
    },
    "segments": [
      {
        "type": "walk",
        "from": { "lat": -8.7021, "lng": 115.1762, "name": "Current Location" },
        "to": { "lat": -8.7050, "lng": 115.1780, "name": "Halte Tuban 1", "stopId": "stop_1" },
        "distanceMeters": 350,
        "durationSeconds": 280,
        "geometry": [[115.1762, -8.7021], [115.1780, -8.7050]],
        "steps": []
      },
      {
        "type": "bus",
        "routeId": "route_k2b",
        "routeRef": "K2B",
        "routeName": "GOR Ngurah Rai - Bandara",
        "routeColor": "#0073b2",
        "from": { "lat": -8.7050, "lng": 115.1780, "name": "Halte Tuban 1" },
        "to": { "lat": -8.6882, "lng": 115.2635, "name": "Halte Sanur 2" },
        "stops": [...],
        "distanceMeters": 13520,
        "durationSeconds": 1800,
        "geometry": [...]
      }
    ],
    "steps": [
      { "type": "walk", "durationMinutes": 5 },
      { "type": "ride", "routeRef": "K2B", "routeName": "GOR Ngurah Rai - Bandara", "durationMinutes": 30 }
    ]
  }
}
```

---

## 5. Live Journey (Go Mode) Lifecycle

### `POST /api/private/journey/go`
Starts a live Go Mode session for a specific quest.

- **Auth**: Required
- **Request Body**:
  ```json
  {
    "questId": "9d136db8-9c86-4222-8c2c-80240c44b85c"
  }
  ```

#### Response (200 OK)
```json
{
  "journeyAttempt": {
    "id": "attempt_9988",
    "questId": "9d136db8-9c86-4222-8c2c-80240c44b85c",
    "questName": "Sanur Sunrise Quest",
    "status": "started",
    "startedAt": "2026-08-21T08:00:00.000Z"
  },
  "steps": [
    {
      "id": "step_1",
      "actionName": "Board K2B at Tuban",
      "status": "waiting",
      "sequence": 1,
      "lat": -8.7050,
      "lng": 115.1780,
      "radiusMeters": 69
    }
  ],
  "geofences": [
    {
      "stepId": "step_1",
      "sequence": 1,
      "lat": -8.7050,
      "lng": 115.1780,
      "radiusMeters": 69
    }
  ]
}
```

---

### `POST /api/private/journey/{id}/advance`
Advances a step within an ongoing attempt when a geofence is triggered or user taps "I'm Here".

- **Auth**: Required
- **Request Body**:
  ```json
  {
    "stepId": "step_1",
    "lat": -8.70502,
    "lng": 115.17801
  }
  ```

#### Response (200 OK)
Returns the updated `journeyAttempt` and updated `steps` array with the target step marked `.done`.

---

### `POST /api/private/journey/{id}/complete`
Finalizes an attempt once all steps are completed, awarding XP, badges, and recording trip metrics.

- **Auth**: Required
- **Request Body**:
  ```json
  {
    "stepsTaken": 1840,
    "distanceMeters": 14200,
    "calorie": 92.5,
    "startPoint": "Jl. Raya Tuban",
    "finishPoint": "Sanur Beach",
    "path": [
      { "lat": -8.7021, "lng": 115.1762, "recordedAt": "2026-08-21T08:00:00Z" },
      { "lat": -8.6882, "lng": 115.2635, "recordedAt": "2026-08-21T08:35:00Z" }
    ]
  }
  ```

#### Response (200 OK)
```json
{
  "journeyAttempt": {
    "id": "attempt_9988",
    "status": "completed",
    "completedAt": "2026-08-21T08:35:10Z"
  },
  "summary": {
    "distanceMeters": 14200,
    "stepsTaken": 1840,
    "calorie": 92.5,
    "startPoint": "Jl. Raya Tuban",
    "finishPoint": "Sanur Beach",
    "rideHailingMotorcycleSavedIdr": 40000
  },
  "badgesAwarded": [
    {
      "id": "badge_earned_1",
      "badgeName": "Sanoored",
      "badgeImageUrl": "/media/system/badge/.../badge.png"
    }
  ]
}
```

---

## 6. Bookmark Endpoints

- **`GET /api/private/bookmark`**: Lists all saved quest bookmarks for the authenticated user.
- **`POST /api/private/bookmark/{questId}`**: Adds a quest to user bookmarks.
- **`DELETE /api/private/bookmark/{questId}`**: Removes a quest from user bookmarks.
