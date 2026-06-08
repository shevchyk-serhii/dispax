# Map Implementation in Dispax Taxi Application

## Overview
Added Mapbox integration for map display and real-time location tracking for drivers and clients.

## Main Components

### 1. LocationService
**File**: `lib/services/location_service.dart`
- Singleton service for geolocation operations
- Real-time location tracking
- Geolocation permissions management

**Main methods:**
- `getCurrentPosition()` - get current location
- `startLocationTracking()` - start real-time tracking
- `stopLocationTracking()` - stop tracking
- `positionStream` - location updates stream

### 2. MapboxService (updated)
**File**: `lib/services/mapbox_service.dart`
- Extended map functionality
- Creating markers for drivers, clients, and route points
- Automatic map centering on route

**New methods:**
- `createDriverMarker()` - driver marker
- `createClientMarker()` - client marker
- `createRideMarkers()` - ride start and end markers
- `getCameraForRoute()` - optimal camera for route
- `isRideInProgress()` - check ride status

### 3. ClientMapScreen
**File**: `lib/screens/client_map_screen.dart`
- Map for clients
- Display client's current location
- Show driver location during active ride
- Information panel with ride details
- Camera control buttons

**Features:**
- Automatic location tracking
- Display active ride
- Update driver location every 10 seconds
- Center on route or current location

### 4. DriverMapScreen
**File**: `lib/screens/driver_map_screen.dart`
- Map for drivers
- Display all assigned rides
- Manage ride status (start/complete)
- Send location to server

**Features:**
- Display routes for all assigned rides
- Active ride control panel
- Automatic location tracking and transmission
- Map centering buttons

### 5. Updated Location Model
**File**: `lib/models/location.dart`
- Added `latitude` and `longitude` fields
- Coordinate support in location model

### 6. Updated Ride Model
**File**: `lib/models/ride.dart`
- Added `driverName` and `driverLocation` fields
- Driver location tracking support

### 7. RideBloc Updates
**File**: `lib/blocs/ride/ride_bloc.dart`
- New `RideStatusUpdateRequested` event
- Ride status update handling

## Dashboard Integration

### Client Dashboard
- Replaced "Current Ride" tab with "Map" showing ClientMapScreen
- Shows map instead of static placeholder

### Driver Dashboard
- Replaced "Profile" tab with "Map" showing DriverMapScreen
- Drivers can see all their rides and manage them

## Permissions and Settings

### Android
**File**: `android/app/src/main/AndroidManifest.xml`
- `ACCESS_FINE_LOCATION` - precise geolocation
- `ACCESS_COARSE_LOCATION` - approximate geolocation

### iOS
**File**: `ios/Runner/Info.plist`
- `NSLocationWhenInUseUsageDescription` - use during app operation
- `NSLocationAlwaysAndWhenInUseUsageDescription` - always use

## Assets
**Folder**: `assets/`
- `driver_marker.svg` - driver icon
- `client_marker.svg` - client icon
- `pickup_marker.svg` - ride start icon
- `destination_marker.svg` - ride end icon

## Dependencies
- `mapbox_maps_flutter: ^2.3.0` - Mapbox SDK
- `geolocator: ^13.0.1` - geolocation

## How to Use

### For Client:
1. Open "Map" tab in dashboard
2. App automatically shows current location
3. If there's an active ride, driver location will be displayed
4. Can center map on current location or route

### For Driver:
1. Open "Map" tab in dashboard
2. All assigned rides visible on map
3. When there's an active ride - control panel at bottom
4. Ability to start/complete ride
5. Automatic location sending to server

## Notes

- Current implementation uses mock data for demonstration
- For production need to:
  - Configure real Mapbox Access Token
  - Implement API for driver location tracking
  - Add offline mode handling
  - Optimize location update frequency
  - Add logging instead of print statements
