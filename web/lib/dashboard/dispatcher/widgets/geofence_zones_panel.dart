/// GeofenceZonesPanel — thin dispatcher-dashboard wrapper around GeofenceScreen.
///
/// The full geofence logic lives in [GeofenceScreen]. This panel embeds it
/// inside the dispatcher dashboard tab so the same screen can be reused in
/// both full-screen navigation and as a dashboard panel.
///
/// Backend note:
/// - GET  /geofences          — list zones (implemented)
/// - GET  /geofences/alerts   — recent alerts (implemented)
/// - DELETE /geofences/:id    — delete zone (implemented)
/// - POST /geofences          — create zone (implemented)
/// - POST /geofences/:id/activate   — activate zone (TODO: not yet on backend)
/// - POST /geofences/:id/deactivate — deactivate zone (TODO: not yet on backend)
library;

export '../../../screens/geofence_screen.dart' show GeofenceScreen;
