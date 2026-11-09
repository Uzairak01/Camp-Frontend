# CAMP Mobile

[![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart_%5E3.13.4-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Tests](https://img.shields.io/badge/Tests-507%2B%20passing-22C55E)](mobile/test/)
[![Analyze](https://img.shields.io/badge/flutter%20analyze-0%20issues-22C55E)](mobile/analysis_options.yaml)

CAMP Mobile is a Flutter rider cockpit for managing a motorcycle fleet, logging post-ride reports, tracking predictive maintenance and trip finances, navigating with offline maps, finding mechanics, and managing rider settings. The implementation uses a tactical **skeuomorphic clay** design system, reactive singleton `ChangeNotifier` state management, and fully offline-first `SharedPreferences` persistence.

> **100% Software-Based Architecture** — CAMP operates on rider-logged data (odometer readings, service records, terrain tags) and standard smartphone GPS. There is **no OBD-II, no ECU polling, no hardware sensor pairing, no fake detection, and no live telemetry hardware**. All wear indicators, service warnings, straight-line distance calculations (Haversine formula), and carburetor guidance are deterministic software calculations derived from user input or GPS.

---

## Quick Start

```bash
cd mobile
flutter pub get
flutter run
```

### Static Analysis & Tests
```bash
flutter analyze    # 0 issues expected
flutter test       # 445+ passing
```

---

## Architecture Overview

```
lib/
├── main.dart                     ← App root, WidgetsBindingObserver (save-on-exit),
│                                   eager LocalStore + controller loads, route map
├── app/
│   ├── routes.dart               ← CampRoutes — single source for all route strings
│   └── theme/
│       ├── app_colors.dart       ← Design tokens: colors, shadows, radii, spacing
│       └── app_theme.dart        ← MaterialTheme + AppTextStyles (Manrope, Teko, Share Tech Mono)
├── core/
│   ├── storage/
│   │   └── local_store.dart      ← SharedPreferences wrapper with ordered write queue & flush()
│   └── widgets/                  ← 18+ shared UI components (CampCard, BikeLabelChip, CampBottomNav …)
└── features/
    ├── auth/                     ← SignIn · SignUp · ForgotPassword (mock auth)
    ├── bike_scan/                ← AddMotorcycle · BikeScan · BikeDetails
    ├── dashboard/                ← HomeScreen · ProfileScreen · EditProfileScreen + 8 widgets
    ├── emergency_sos/            ← EmergencySosScreen (Emergency contact, dialer, scannable QR)
    ├── garage/                   ← GarageScreen · BikeProfileScreen
    │   ├── controllers/          ← ActiveBikeController (singleton, persisted)
    │   └── domain/               ← Bike · ServiceRecord · FuelSystem · TrackingMode
    ├── maintenance/              ← MaintenanceScreen · FinanceRigHealthScreen · ServiceScheduleScreen + sub-screens
    │   ├── controllers/          ← MaintenanceController · ServiceVisitController · PostRideReportController · TripBudgetController
    │   └── domain/               ← ServiceScheduleEngine · MaintenancePredictionEngine · CarburetorGuidanceTable …
    ├── mechanics/                ← MechanicsHomeScreen · AddMechanicScreen
    ├── navigation/               ← NavigationMapScreen · RoutePacksScreen
    │   ├── controllers/          ← NavigationController (per-screen, not singleton)
    │   └── domain/               ← LocationService · RoutingService · GeocodingService · PlacesPoiService
    ├── ride_history/             ← RideHistoryScreen
    ├── settings/                 ← SettingsScreen
    │   └── controllers/          ← SettingsController (singleton, persisted)
    └── voice_copilot/            ← VoiceAssistantScreen
```

---

## State Management & Data Flow

Persistent user data is managed by reactive **ChangeNotifier controllers** and repositories, loaded eagerly in `main()` before `runApp`:

| Controller / Repository | Persists To | Consumed By |
|---|---|---|
| `ActiveBikeController` | `LocalStore` (`camp_bikes`, `camp_active_bike_id`) | Dashboard, Maintenance, Navigation, Garage, Bike Scan |
| `ProfileController` | `LocalStore` (`camp_rider_profile`) | Dashboard, ProfileScreen, EditProfileScreen |
| `SettingsController` | `LocalStore` (`camp_settings`) | Settings screen, NavigationController (units), Emergency SOS |
| `MaintenanceController` | `LocalStore` via `MaintenanceRepository` | ServiceScheduleScreen, FinanceRigHealthScreen, HomeScreen |
| `ServiceVisitController` | `LocalStore` via `MaintenanceRepository` | NextServiceVisitCard, PlanServiceVisitSheet, MarkServiceDone |
| `PostRideReportController` | `LocalStore` (`camp_post_ride_reports`) | MaintenanceScreen (PostRide tab, Diagnostics engine), RideHistory |
| `TripBudgetController` | `LocalStore` (`camp_trip_budget`, `camp_trip_expenses`) | FinanceRigHealth screen and all expense sub-screens |
| `MechanicController` | `LocalStore` (`camp_mechanics_list`) | MechanicsHomeScreen, AddMechanicScreen |

`NavigationController` is **not** a singleton — it is created and disposed per `NavigationMapScreen` lifecycle. It reads `ActiveBikeController` (for fuel estimates) and `SettingsController` (for metric/imperial units) and includes strict `_disposed` lifecycle guards.

### Persistence Layer (`LocalStore`)

`LocalStore` wraps `SharedPreferences` with:
- **Ordered write queue** — a chained `Future<void> _writeQueue` guarantees writes complete in submission order, preventing a later write from overtaking an earlier one.
- **`flush()`** — awaits the entire queue; called on app lifecycle `paused / inactive / detached` via `WidgetsBindingObserver` in `CampApp`.
- **Transactional Rollback** — UI optimistically reflects changes and rolls back with an `AppMessenger` alert if storage operations fail.
- **Schema versioning** — `camp_schema_version` key guards against loading data from a future schema version.
- **First-run seeding** — `camp_first_run_completed` gates whether defaults are seeded on install.

---

## Registered Routes

All route strings are declared as constants in [`lib/app/routes.dart`](lib/app/routes.dart). **One constant per screen, no duplicates.**

| Route | Screen | Feature |
|---|---|---|
| `/` | `HomeScreen` | Dashboard |
| `/sign-in` | `SignInScreen` | Auth |
| `/sign-up` | `SignUpScreen` | Auth |
| `/forgot-password` | `ForgotPasswordScreen` | Auth |
| `/add-bike` | `AddMotorcycleScreen` | Bike Scan |
| `/bike-scan` | `BikeScanScreen` | Bike Scan |
| `/bike-details` | `BikeDetailsScreen` | Bike Scan |
| `/garage` | `GarageScreen` | Garage |
| `/bike-profile` | `BikeProfileScreen` | Garage |
| `/profile` | `ProfileScreen` | Dashboard |
| `/edit-profile` | `EditProfileScreen` | Dashboard |
| `/mechanics` | `MechanicsHomeScreen` | Mechanics |
| `/add-mechanic` | `AddMechanicScreen` | Mechanics |
| `/navigation/map` | `NavigationMapScreen` | Navigation |
| `/voice-copilot` | `VoiceAssistantScreen` | Voice Copilot |
| `/route-packs` | `RoutePacksScreen` | Navigation |
| `/ride-history` | `RideHistoryScreen` | Ride History |
| `/finance-rig-health` | `FinanceRigHealthScreen` | Maintenance |
| `/maintenance` | `MaintenanceScreen` | Maintenance |
| `/service-schedule` | `ServiceScheduleScreen` | Maintenance |
| `/post-ride-debrief` | `PostRideDebriefScreen` | Maintenance |
| `/predictive-maintenance` | `MaintenanceScreen(initialTab: diagnostics)` | Maintenance |
| `/carburetor-tuning` | `MaintenanceScreen(initialTab: carburetor)` ¹ | Maintenance |
| `/settings` | `SettingsScreen` | Settings |
| `/emergency-sos` | `EmergencySosScreen` | Emergency SOS |

> ¹ EFI bikes automatically fall back to the Diagnostics tab.
>
> **Legacy aliases** (kept for backwards compatibility):
> `/mechanics/map` → `NavigationMapScreen` · `/mechanics/voice-assistant` → `VoiceAssistantScreen`

---

## Feature Details

### Dashboard (`features/dashboard/`)
- **HomeScreen** — cockpit landing: active bike card with live GPS fuel calculation, voice bar, dynamic maintenance alert reading from schedule engine with "+N more due" expandable link, recent updates feed, floating `CampBottomNav`.
- **ProfileScreen** — rider overview: cockpit hero, touring tier, trail badges, garage summary, ride health, SOS medical ID.
- **EditProfileScreen** — form editor for rider personal details.

### Bike Scan (`features/bike_scan/`)
- **AddMotorcycleScreen** — entry hub: Scan Bike (camera) or View Garage.
- **BikeScanScreen** — camera with 8-second timeout, "Starting camera…" status, manual-entry fallback.
- **BikeDetailsScreen** — multi-step spec form; on save calls `ActiveBikeController.addBike()`.

### Garage (`features/garage/`)
- **GarageScreen** — fleet list, bike switcher, remove bike.
- **BikeProfileScreen** — full spec sheet, service records, active bike toggle.
- **Bike model** — `id`, `make`, `modelName`, `modelYear`, `odometerKm`, `fuelSystem` (`efi` | `carburetor`), `carburetorType`, `fuelTankCapacityLiters`, `fuelAverageKmPerLiter`, `ridingTerrain`, `lastOilChange`, `lastTuneUp`, `vin`, `nickname`, `imagePath`.

### Maintenance & Service Schedule (`features/maintenance/`)
- **Rider-Set Service Schedule Engine**:
  - Deterministic arithmetic per motorcycle; no silent defaults, no sensor dependencies, and no estimated costs.
  - Configurable items: Oil & Small Service, Oil Filter, Air Filter, Drive Chain, Spark Plug, Valve Tuning, Brakes, Tyres, Battery, Carburetor.
  - Harsh conditions mode shortens distance intervals by 20% (`intervalKm * 0.80`).
  - Status classification: `Not set up`, `Add last done`, `Overdue`, `Due soon`, `OK`.
  - Predictions project due dates from 7+ days of logged debriefs and odometer progress.
- **Multi-Bike Maintenance**:
  - `BikeLabelChip` displays bike model/nickname and license plate.
  - Prefilled with the active bike; backwards compatible with "No bike" legacy records.
- **Finances & Rig Health**:
  - Trip budget (`TripBudgetController`) + maintenance item list with rollback protection on disk errors.
  - Refill sheet calculates dynamically across any two of litres, price per litre, and total paid in PKR.

### Bike Scan & Optical Onboarding (`features/bike_scan/`)
- **AddMotorcycleScreen** — photo picker ("Take Bike Photo") and manual entry.
- **BikeDetailsScreen** — manual entry form (make, model, year, plate, odometer, fuel average, fuel system); photo card with preview, change, and remove. No fake detection banner or hardcoded defaults.
- **Typed Recognition Plug-in Point** — `BikeRecognitionResult` and `BikeRecognitionService` interface (cleanly parked for backend Firebase AI Logic with Gemini without any local mock). `populateFromRecognition` fills only detected fields and leaves odometer, fuel level, VIN, nickname, and fuel system unassigned.

### Navigation (`features/navigation/`)
- **NavigationMapScreen** — OSM vector map (`flutter_map`), OSRM routing, Nominatim geocoding, GPS position stream, wakelock during active guidance, topo/standard layer toggle, POI markers (mechanic · fuel · rest stop).
- **NavigationController** states: `idle → previewing → navigating → arrived`. Off-route detection (>50 m from polyline for 3 consecutive fixes) triggers reroute (throttled to 1 per 10 s). Includes safe disposal lifecycle guard.
- **RoutePacksScreen** — offline route packs displaying honest "Coming soon" status. Clean header without unbacked "Topo V4.8" sync buttons. Persistent Wi-Fi auto-update preference toggle via `SettingsRepository`.

### Mechanics (`features/mechanics/`)
- **MechanicsHomeScreen** — directory with honest straight-line distance via Haversine formula ($R = 6371.0\text{ km}$, only displayed when shop coordinates and user phone GPS are present). Pull-to-refresh reload. Clean header without unbacked "GPS LOCKED" pill.
- **Real Filter Chips** — exactly 3 filter chips ("All", "Open now", "Emergency Pitstop") with live, non-fabricated counts. "Open now" derives from deterministic opening-hours arithmetic (days, hours, 24h, overnight shifts).
- **AddMechanicScreen** — workshop registration form with photo picker, latitude/longitude coordinates, opening hours builder, and persistent local storage.

### Emergency SOS (`features/emergency_sos/`)
- Emergency number selector (1122, 15, 115, custom).
- Dedicated Emergency QR screen with real scannable payload, per-field privacy toggles, and PNG/PDF export.

### Voice Copilot (`features/voice_copilot/`)
- **Tactical Chatbot Interface** — Simple chatbot conversation layout with header drawer toggle, close action, suggestion chips, and bottom text bar with animated mic.
- **Local Chat History** — Side drawer panel supporting "New chat", search across messages, time categorization (Today, Yesterday, Earlier), and local phone persistence.
- **Data Honesty** — Answers strictly from stored telemetry (fuel level, odometer, service schedule, mechanics directory); answers "I can't answer that yet" otherwise without fabricated helmet, mesh intercom, or Bluetooth token claims.

### Brand Design System (UI-1)
- **Authentic Header Branding** — `HomeScreen` displays the CAMP logo and title without orange dot.
- **De-cluttered Headers** — Logo, wordmark, and orange dot removed from all secondary screen headers (retained on Login, Sign-up, Forgot Password, and Drawer).

---

## Test Suite

20+ test files · **445+ tests · 0 failures · 0 lints**

| File | What It Covers |
|---|---|
| `persistence_test.dart` | LocalStore write queue, flush, schema fallback, model round-trips |
| `widget_test.dart` | Route uniqueness, lifecycle flush (paused/inactive), tab selection |
| `navigation_unit_test.dart` | NavigationController dispose guard, distance-to-polyline math |
| `navigation_map_screen_test.dart` | Map screen renders with FakeTileProvider network isolation |
| `maintenance_bike_label_test.dart` | Multi-bike scoping, bike chip rendering, active bike prefill |
| `maintenance_persistence_and_rollback_test.dart` | Rollback handling on storage failure, AppMessenger alerts |
| `maintenance_refresh_and_list_test.dart` | Reactive UI synchronization across Home, Finances, and Schedule |
| `service_schedule_wording_test.dart` | Neutral phrasing, plain question helpers, harsh condition calculations |
| `fuel_refill_pricing_test.dart` | Three-way dynamic calculation (litres / price / total) in PKR |
| `budget_and_cost_per_km_test.dart` | Trip finances, distance tracking over trip periods, delete trip dialog |
| `finance_maintenance_restore_test.dart` | Rider-added maintenance items restoration and "+ Add Item" |
| `home_honesty_pass_test.dart` | Home screen service alert and status card agreement with schedule |
| `maintenance_prediction_test.dart` | Prediction math, 7-day ride debrief thresholds, debrief screen navigation |
| `maintenance_test.dart` | MaintenanceScreen tab switching, EFI carburetor fallback |
| `bike_scan_test.dart` | BikeScanScreen no-camera fallback, honest manual entry, photo preservation, typed `populateFromRecognition` (full & partial) |
| `bike_profile_test.dart` | BikeProfileScreen renders, active bike toggle |
| `bike_details_test.dart` | BikeDetailsScreen form validation, photo card, save bike |
| `add_motorcycle_test.dart` | AddMotorcycleScreen entry point routing, "Take Bike Photo" card |
| `settings_screen_test.dart` | SettingsScreen toggles, SettingsController persistence |
| `profile_screen_test.dart` | ProfileScreen renders with active bike data |
| `ride_history_test.dart` | RideHistoryScreen renders expedition list |
| `route_packs_test.dart` | RoutePacksScreen "Coming soon" honesty, Wi-Fi auto-update persistence, absence of Topo V4.8 button |
| `mechanics_test.dart` | Mechanics directory filtering (All, Open now, Emergency Pitstop), real counts, Haversine distance, opening hours, header honesty (no GPS LOCKED pill), seeded mechanics cleanup |
| `safety_and_honesty_test.dart` | Emergency contact card, dialer launch, and real QR generation |

---

## Project Status & Issue Tracking

The project uses a comprehensive **156-issue tracking matrix** documented in [`CODE_REVIEW_REPORT.md`](CODE_REVIEW_REPORT.md).

- **Current Progress**: **117 Done / 156 Tracked (75.0% Complete)**
- **Batches Completed**: Batches A, B, C, D, E, F, G, and UI-1 are completed and verified on device.
- **Next Development Focus**: **Batch H-1** (login/sign-up cleanup, local accounts with salted hash, Google sign-in button placeholder, and glass UI), followed by **Batch H-2** (change password), **Step 4** (Navigation & live ride tracking), and **Firebase** backend.

