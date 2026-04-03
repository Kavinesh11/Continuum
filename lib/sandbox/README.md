# Sandbox Environment

This folder contains the full sandbox layer for Continuum. It replaces live backend calls with deterministic, pre-seeded driver personas so the app can be demoed, tested, and presented without any real infrastructure.

---

## Why this exists

The app previously used a flat `MockData` class with hardcoded strings scattered across screens. That worked for UI scaffolding but gave no way to simulate different driver profiles, switch personas mid-session, or pass structured location/order data through the widget tree.

The sandbox layer fixes that by introducing:
- Typed data models for drivers, locations, and orders
- A fake service layer that mimics async API calls
- An `InheritedWidget` provider so any screen can read the active driver
- A persona selector screen shown after login

---

## Files

### `sandbox_drivers.dart`

Defines three data classes and three pre-seeded driver personas.

**Data classes:**

| Class | Fields |
|---|---|
| `SandboxLocation` | `lat`, `lng`, `address`, `zone`, `timestamp` |
| `SandboxOrder` | `orderId`, `platform`, `status`, `earnings`, `pickupAddress`, `dropAddress`, `timestamp`, `durationMinutes` |
| `SandboxDriver` | All profile fields + `currentLocation`, `locationHistory`, `orderHistory` + computed getters |

**Computed getters on `SandboxDriver`:**

| Getter | What it returns |
|---|---|
| `weeklyEarnings` | Sum of earnings from completed orders |
| `weeklyOrderCount` | Total orders in the history list |
| `completionRate` | Completed orders / total orders |

**Driver personas:**

| Variable | Name | City | Tier | Platform | Orders/week |
|---|---|---|---|---|---|
| `sandboxDriverSudarshan` | Sudarshan K. | Bangalore | Platinum | Swiggy + Zomato | 7 |
| `sandboxDriverDakshina` | Dakshina Moorthy | Chennai | Gold | Swiggy + Zomato | 6 |
| `sandboxDriverSudha` | Sudha P. | Kolkata | Silver | Swiggy | 5 |

Each persona has 5 location pings across their city and a realistic mix of completed/failed/cancelled orders with real restaurant names and addresses.

All personas are exported in `allSandboxDrivers` (a `List<SandboxDriver>`).

---

### `sandbox_service.dart`

A fake backend service. Takes a `SandboxDriver` and exposes async methods that simulate network latency (default 400ms).

```dart
final service = SandboxService(driver);

await service.fetchProfile()           // Map<String, dynamic>
await service.fetchCurrentLocation()   // Map<String, dynamic>
await service.fetchLocationHistory()   // List<Map<String, dynamic>>
await service.fetchOrderHistory()      // List<Map<String, dynamic>>
await service.fetchEarningsSummary()   // Map<String, dynamic>
await service.fetchRiskProfile()       // Map<String, dynamic> — risk score, trigger probability, expected loss
```

All methods return plain maps so they can be dropped in wherever a real API response would go. The risk profile score is derived from the driver's tier (Platinum → 0.82, Gold → 0.65, Silver → 0.48).

---

### `driver_provider.dart`

Two classes:

**`DriverProvider`** — an `InheritedWidget` that holds the active driver and service. Any widget in the tree can read it:

```dart
final driver = DriverProvider.of(context).driver;
final service = DriverProvider.of(context).service;
DriverProvider.of(context).switchDriver(newDriver);
```

**`DriverProviderRoot`** — a `StatefulWidget` that owns the active driver state and wraps the app. It is placed at the root in `main.dart`, above `MaterialApp`.

---

### `sandbox_selector_screen.dart`

A full-screen persona picker shown after login (route: `/sandbox`). Displays each driver as a card with:

- Name, initials avatar, city
- Tier badge (color-coded: purple/Platinum, amber/Gold, grey/Silver)
- Weekly order count, earnings, completion rate
- Current location address and ping count

Tapping a card calls `DriverProvider.of(context).switchDriver(driver)` and navigates to `/home`.

---

## Changes made to existing files

### `lib/main.dart`
- Wrapped `MaterialApp` inside `DriverProviderRoot` so the provider is available to all routes
- Added import for `driver_provider.dart` and `sandbox_selector_screen.dart`
- Registered the `/sandbox` route pointing to `SandboxSelectorScreen`

### `lib/routes/app_routes.dart`
- Added `static const String sandboxSelect = '/sandbox'`

### `lib/screens/login.dart`
- Changed `_login()` to navigate to `AppRoutes.sandboxSelect` instead of `AppRoutes.home`
- This routes every login through the persona picker first

### `lib/screens/profile.dart`
- Fully rewritten to pull data from `DriverProvider.of(context).driver` instead of `MockData`
- Now shows: sandbox tier badge, driver name/initials/city, total protected, claims approved, phone, platform, zone, emergency contact, weekly order summary (count, earnings, completion rate), current location with ping count
- Edit button replaced with a swap icon that navigates back to `/sandbox` to switch personas
- Extracted `_StatCard` and `_DataRow` as private widget classes

### `lib/screens/dashboard.dart`
- Added import for `driver_provider.dart`
- Avatar initials in the AppBar now read from `DriverProvider.of(context).driver.initials` instead of the hardcoded string `'PS'`

---

## How to use

1. Run the app — login screen appears
2. Tap either login button — navigates to the sandbox selector
3. Pick a driver persona — the app loads with that driver's data
4. Navigate to Profile to see full driver info, orders, and location
5. Tap the swap icon (↔) in the profile AppBar to switch personas without restarting

To use sandbox data in any new screen:

```dart
// Read the active driver
final driver = DriverProvider.of(context).driver;

// Use the service for async calls
final service = DriverProvider.of(context).service;
final orders = await service.fetchOrderHistory();
```

To add a new driver persona, add a new `SandboxDriver(...)` instance in `sandbox_drivers.dart` and append it to `allSandboxDrivers`.
