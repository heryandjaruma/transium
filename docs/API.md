# Transium API Reference

This document outlines the API endpoints, data models, and routing logic provided by the Transium Backend service (`https://transium-api.heryandjaruma.workers.dev`). 

The API is used by the client for door-to-door transit planning, quest discovery, and authentication.

---

## Base URLs and Setup

- **Production API Base**: `https://transium-api.heryandjaruma.workers.dev/api`
- **Authentication Endpoints**: `https://transium-api.heryandjaruma.workers.dev/api/auth`
- **OpenAPI Schema**: `https://transium-api.heryandjaruma.workers.dev/api/openapi.json`
- **Scalar Reference Docs**: `https://transium-api.heryandjaruma.workers.dev/reference`

Configuration in the codebase is managed via [`transium/Backend/APIConfiguration.swift`](file:///Users/msafdev/Code/swift/transium/transium/Backend/APIConfiguration.swift).

---

## 1. Journey Planning

### `GET /journey/real`

Plan a real door-to-door transit journey directly to a Quest using its `questId` and the user's starting origin coordinates. This eliminates the need for the client to manually specify a destination coordinate, deriving it automatically from the quest's first actionable badge step.

#### Query Parameters
- `questId` (string, required): UUID identifier of the target quest. Example: `c8e567dc-e321-438f-9a30-33eb8ae06546`
- `origin` (string, required): Starting coordinate as `lat,lng`. Example: `-8.702105,115.176189`

#### Response Schema (200 OK)
Returns the standard `JourneyResponse` containing `best` (and optional `lessWalking`/`lessTransit` alternatives).

---

### `GET /journey/overview`

Plan a door-to-door journey between two coordinates in Bali, optimizing for different travel preferences (walking vs public transport).

#### Query Parameters
- `origin` (string, required): Starting coordinate as `lat,lng`. Example: `-8.6705,115.2126`
- `destination` (string, required): Destination coordinate as `lat,lng`. Example: `-8.7089,115.2537`

#### How Routing Works
The router computes routes under two distinct cost profiles:
1. **`lessWalking`**: Minimizes walking distances, accepting more transfers if needed.
2. **`lessTransit`**: Minimizes transfers and waiting time, accepting longer walks.

The backend response encapsulates this in the following structure:
- **`best`**: Always returned. This is the optimal route under `lessWalking`, or `lessTransit` if `lessWalking` is unavailable.
- **`alternativesAvailable`**: Set to `true` if both profiles found physically distinct routes (different stop sequences). In this case, the response contains `lessWalking` and `lessTransit` objects. If they are the same or only one exists, `alternativesAvailable` is `false` and only `best` is returned.
- **Walk Fallback**: If the origin and destination are close enough that walking is faster or transit is unavailable, the journey returned is a single walk segment.

#### Response Schema (200 OK)
```json
{
  "alternativesAvailable": boolean,
  "best": JourneyResult,
  "lessWalking": JourneyResult, // Optional, only if alternativesAvailable is true
  "lessTransit": JourneyResult  // Optional, only if alternativesAvailable is true
}
```

#### Error Responses
- **`400 Bad Request`**: Missing/invalid parameters.
  - `{ "error": "Invalid arguments" }`
- **`404 Not Found`**: No routes found or transit/walking directions unavailable.
  - `{ "error": "No stops available" }`
  - `{ "error": "No route found" }`
  - `{ "error": "No walking route to boarding stop" }`
  - `{ "error": "No walking route from alighting stop" }`

#### Example Curl and Response
```bash
curl -s "https://transium-api.heryandjaruma.workers.dev/api/journey/overview?origin=-8.6705,115.2126&destination=-8.7089,115.2537"
```

Response snippet:
```json
{
  "alternativesAvailable": false,
  "best": {
    "origin": { "lat": -8.6705, "lng": 115.2126 },
    "destination": { "lat": -8.7089, "lng": 115.2537 },
    "segments": [
      {
        "type": "walk",
        "from": { "lat": -8.6705, "lng": 115.2126, "name": "Origin" },
        "to": { "lat": -8.6693, "lng": 115.21259, "name": "Teuku Umar 2", "stopId": "cd8a695c-59df-4324-ae69-f89c8b41613c" },
        "distanceMeters": 284,
        "durationSeconds": 219,
        "geometry": [[115.212648, -8.670506], [115.212691, -8.670264], ...],
        "steps": [
          { "instructions": "Proceed to the route", "distanceMeters": 0, "durationSeconds": 4, "geometry": [...] },
          { "instructions": "Take a left onto Pulau Seram", "distanceMeters": 125, "durationSeconds": 94, "geometry": [...] }
        ]
      },
      {
        "type": "bus",
        "routeId": "K2B-1",
        "routeRef": "K2B-1",
        "routeName": "Ngurah Rai → Terminal Ubung",
        "routeColor": "#0073b2",
        "from": { "stopId": "cd8a695c-59df-4324-ae69-f89c8b41613c", "name": "Teuku Umar 2", "lat": -8.6693, "lng": 115.21259 },
        "to": { "stopId": "bc3055a6-503d-4d40-b594-24e6219b4fd6", "name": "Unud Sudirman 1", "lat": -8.6717297, "lng": 115.2182818 },
        "stops": [
          { "stopId": "cd8a695c-59df-4324-ae69-f89c8b41613c", "name": "Teuku Umar 2", "lat": -8.6693, "lng": 115.21259 },
          { "stopId": "bc3055a6-503d-4d40-b594-24e6219b4fd6", "name": "Unud Sudirman 1", "lat": -8.6717297, "lng": 115.2182818 }
        ],
        "distanceMeters": 681.5,
        "durationSeconds": 122.7,
        "geometry": [[-8.743842, 115.1790356], [-8.743842, 115.1790356]]
      },
      {
        "type": "transfer",
        "from": { "stopId": "bc3055a6-503d-4d40-b594-24e6219b4fd6", "name": "Unud Sudirman 1", "lat": -8.6717297, "lng": 115.2182818 },
        "to": { "stopId": "7d37a66c-9d9d-4c95-bea1-a0b19d75cb5f", "name": "Simpang Sudirman", "lat": -8.66953, "lng": 115.21849 },
        "distanceMeters": 245.7,
        "durationSeconds": 182.0,
        "geometry": [[115.2182818, -8.6717297], [115.21849, -8.66953]]
      }
    ],
    "summary": {
      "distanceMeters": 10763.8,
      "walkingDistanceMeters": 353,
      "walkingDurationSeconds": 276,
      "transitDistanceMeters": 10410.8,
      "busLegCount": 3,
      "transferCount": 2
    },
    "steps": [
      { "type": "walk", "durationMinutes": 4 },
      { "type": "ride", "routeRef": "K2B-1", "routeName": "Ngurah Rai → Terminal Ubung", "durationMinutes": 2 },
      { "type": "walk", "durationMinutes": 3 }
    ]
  }
}
```

---

## 2. Quests and Kelurahan

Quests are discoverable activities linked to specific regional areas ("Kelurahan") in Bali. A quest itself does not have a single coordinate; instead, it is reachable through any Kelurahan associated with its badges, and its route preview coordinates come from the badge action steps.

### `GET /quest`
List all discoverable quests along with their thumbnail assets.

#### Response Schema (200 OK)
```json
{
  "quests": [ Quest ]
}
```

#### Example Curl and Response
```bash
curl -s "https://transium-api.heryandjaruma.workers.dev/api/quest"
```
```json
{
  "quests": [
    {
      "id": "9d136db8-9c86-4222-8c2c-80240c44b85c",
      "name": "Explore Sanur",
      "category": "Beaches",
      "description": "Exploring Sanur.",
      "thumbnails": [
        {
          "id": "89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969",
          "createdAt": "2026-08-18T04:52:35.289Z",
          "type": "image/jpeg",
          "url": "/media/system/quest/9d136db8-9c86-4222-8c2c-80240c44b85c/89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969.jpg"
        }
      ]
    }
  ]
}
```

### `GET /quest/{id}`
Retrieve a detailed representation of a specific quest, including its thumbnails, attached badges (each with its ordered sequence of action steps), and computed origin/destination coordinates (derived from the first and last steps with coordinate mappings).

*Tip: Pass the returned `origin` and `destination` directly to `/journey/overview` to show a route preview for the quest.*

#### Response Schema (200 OK)
```json
{
  "quest": QuestDetail
}
```

#### Example Curl and Response
```bash
curl -s "https://transium-api.heryandjaruma.workers.dev/api/quest/9d136db8-9c86-4222-8c2c-80240c44b85c"
```
```json
{
  "quest": {
    "id": "9d136db8-9c86-4222-8c2c-80240c44b85c",
    "name": "Explore Sanur",
    "category": "Beaches",
    "description": "Exploring Sanur.",
    "thumbnails": [
      {
        "id": "89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969",
        "createdAt": "2026-08-18T04:52:35.289Z",
        "type": "image/jpeg",
        "url": "/media/system/quest/9d136db8-9c86-4222-8c2c-80240c44b85c/89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969.jpg"
      }
    ],
    "badges": [
      {
        "id": "3729e521-be0e-4ac3-9a02-7339b0123007",
        "badgeId": "ae2cf1b2-e536-416b-9db7-d7e76c6f3443",
        "badgeName": "Sanoored",
        "badgeCategory": "Explore",
        "badgeType": "quest",
        "badgeImageUrl": "/media/system/badge/ae2cf1b2-e536-416b-9db7-d7e76c6f3443/8d771144-5968-4262-b698-8213cb29d096.png",
        "steps": []
      }
    ],
    "origin": null,
    "destination": null
  }
}
```

### `GET /quest/{id}/badges`
List badges associated with a specific quest.

#### Response Schema (200 OK)
```json
{
  "questBadges": [ QuestBadgeEntry ]
}
```

### `GET /kelurahan/quests`
List quests grouped by Kelurahan. Only Kelurahans containing at least one quest are returned. Quests can appear under multiple Kelurahans if their badges span different regions.

#### Response Schema (200 OK)
```json
{
  "groups": [
    {
      "kelurahan": Kelurahan,
      "quests": [ Quest ]
    }
  ]
}
```

#### Example Curl and Response
```bash
curl -s "https://transium-api.heryandjaruma.workers.dev/api/kelurahan/quests"
```
```json
{
  "groups": [
    {
      "kelurahan": {
        "id": "20447277",
        "kelurahanName": "Sanur",
        "kecamatanName": "Denpasar Selatan"
      },
      "quests": [
        {
          "id": "9d136db8-9c86-4222-8c2c-80240c44b85c",
          "name": "Explore Sanur",
          "category": "Beaches",
          "description": "Exploring Sanur.",
          "thumbnails": [
            {
              "id": "89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969",
              "createdAt": "2026-08-18T04:52:35.289Z",
              "type": "image/jpeg",
              "url": "/media/system/quest/9d136db8-9c86-4222-8c2c-80240c44b85c/89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969.jpg"
            }
          ]
        }
      ]
    }
  ]
}
```

### `GET /kelurahan/{id}/quests`
List all quests reachable in a specific Kelurahan.

#### Response Schema (200 OK)
```json
{
  "kelurahan": Kelurahan,
  "quests": [ QuestWithBadges ]
}
```

#### Example Curl and Response
```bash
curl -s "https://transium-api.heryandjaruma.workers.dev/api/kelurahan/20447277/quests"
```
```json
{
  "kelurahan": {
    "id": "20447277",
    "kelurahanName": "Sanur",
    "kecamatanName": "Denpasar Selatan"
  },
  "quests": [
    {
      "id": "9d136db8-9c86-4222-8c2c-80240c44b85c",
      "name": "Explore Sanur",
      "category": "Beaches",
      "description": "Exploring Sanur.",
      "thumbnails": [
        {
          "id": "89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969",
          "createdAt": "2026-08-18T04:52:35.289Z",
          "type": "image/jpeg",
          "url": "/media/system/quest/9d136db8-9c86-4222-8c2c-80240c44b85c/89df4eaf-6fe4-4c8c-a2be-07e9d0bb4969.jpg"
        }
      ],
      "badges": [
        {
          "id": "3729e521-be0e-4ac3-9a02-7339b0123007",
          "questId": "9d136db8-9c86-4222-8c2c-80240c44b85c",
          "badgeId": "ae2cf1b2-e536-416b-9db7-d7e76c6f3443",
          "badgeName": "Sanoored",
          "badgeCategory": "Explore",
          "badgeType": "quest",
          "badgeImageUrl": "/media/system/badge/ae2cf1b2-e536-416b-9db7-d7e76c6f3443/8d771144-5968-4262-b698-8213cb29d096.png"
        }
      ]
    }
  ]
}
```

---

## 3. Data Models (Schemas)

### `JourneyResult`
Represents a fully-calculated route option.
- `origin` (`LatLng`): Origin point.
- `destination` (`LatLng`): Destination point.
- `summary` (object):
  - `distanceMeters` (number): Combined walking and transit distance.
  - `walkingDistanceMeters` (number): Total walking distance.
  - `walkingDurationSeconds` (number): Real walking duration from Apple Maps (first/last legs only).
  - `transitDistanceMeters` (number): Distance covered on buses and transfers.
  - `busLegCount` (integer): Number of bus rides.
  - `transferCount` (integer): Number of stop-to-stop transfers.
- `segments` (array of WalkLeg | TransferLeg | BusLeg):
  - **WalkLeg**: A walk leg from Apple Maps.
    - `type`: `"walk"`
    - `from`/`to`: `{ lat: number, lng: number, name: string, stopId?: string }`
    - `distanceMeters`: number (or null)
    - `durationSeconds`: number (or null)
    - `geometry`: `[[lng, lat], ...]`
    - `steps` (array of Turn): Turn-by-turn instruction list (each containing `instructions`, `distanceMeters`, `durationSeconds`, and `geometry`).
  - **TransferLeg**: A walking connection between two nearby transit stops.
    - `type`: `"transfer"`
    - `from`/`to`: `JourneyStopRef`
    - `distanceMeters`: number
    - `durationSeconds`: number
    - `geometry`: `[[lng, lat], ...]`
  - **BusLeg**: A transit segment on a specific route.
    - `type`: `"bus"`
    - `routeId` (string, UUID): Internal route ID.
    - `routeRef` (string, optional): Short display code (e.g., `"K2B-1"`).
    - `routeName` (string, optional): Name of the transit route.
    - `routeColor` (string, optional): Hex color code for rendering (e.g. `"#0073b2"`).
    - `from`/`to`: `JourneyStopRef`
    - `stops` (array of `JourneyStopRef`): Every stop the bus stops at during this leg.
    - `distanceMeters`: number
    - `durationSeconds`: number
    - `geometry`: `[[lng, lat], ...]`
- `steps` (array of `JourneyStep`): A glanceable step-by-step summary.

### `JourneyStep`
A simplified segment description for rapid UI timeline rendering.
- **Walk Step**: `{ "type": "walk", "durationMinutes": number }`
- **Ride Step**: `{ "type": "ride", "routeRef": string, "routeName": string | null, "durationMinutes": number }`

### `JourneyStopRef`
- `stopId` (string, UUID): Database identifier.
- `name` (string): Display name.
- `lat` (number): Latitude.
- `lng` (number): Longitude.

### `Quest`
- `id` (string, UUID)
- `name` (string)
- `category` (string)
- `description` (string)
- `thumbnails` (array of `MediaAsset`)

### `QuestDetail`
- `id` (string, UUID)
- `name` (string)
- `category` (string)
- `description` (string)
- `thumbnails` (array of `MediaAsset`)
- `badges` (array of `QuestBadgeWithSteps`)
- `origin` (`LatLng` | null): Coordinates of the first badge step.
- `destination` (`LatLng` | null): Coordinates of the last badge step.

### `QuestBadgeWithSteps`
- `id` (string, UUID): Link/attachment ID.
- `badgeId` (string, UUID): Core badge ID.
- `badgeName` (string)
- `badgeCategory` (string)
- `badgeType` (string)
- `badgeImageUrl` (string | null)
- `steps` (array of `BadgeActionStep`)

### `BadgeActionStep`
- `id` (string, UUID)
- `badgeId` (string, UUID)
- `actionId` (string, UUID)
- `actionName` (string)
- `actionType` (string)
- `sequence` (integer): Ordered sequence number.
- `lat` (number | null)
- `lng` (number | null)
- `instruction` (string | null)

### `Kelurahan`
- `id` (string): Kelurahan identifier.
- `kelurahanName` (string): Kelurahan name (e.g., `"Sanur"`).
- `kecamatanName` (string): Kecamatan name (e.g., `"Denpasar Selatan"`).

### `MediaAsset`
- `id` (string, UUID)
- `createdAt` (string, date-time)
- `type` (string): MIME type, e.g. `"image/jpeg"`.
- `url` (string): Relative URL path to media.

---

## 4. Authentication (Better Auth)

Authentication endpoints are integrated with the client in [`transium/Backend/BetterAuthBackend.swift`](file:///Users/msafdev/Code/swift/transium/transium/Backend/BetterAuthBackend.swift).

- **`POST /api/auth/sign-in/social`**: Performs social login verification (Sign in with Apple).
- **`GET /api/auth/get-session`**: Retrieves the active profile session.
- **`POST /api/auth/update-user`**: Updates profile properties.
- **`POST /api/auth/sign-out`**: Invalidates the active session token.
