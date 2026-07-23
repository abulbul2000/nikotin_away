/// A geofence transition at a [SignificantPlace] — written natively by
/// GeofenceTransitionReceiver.kt, even when the Flutter engine isn't
/// running. Deliberately carries no coordinates, only which place and
/// which transition.
class LocationVisitEvent {
  final String id;
  final String placeId;
  final String transitionType; // 'enter' | 'exit'
  final DateTime createdAt;

  const LocationVisitEvent({
    required this.id,
    required this.placeId,
    required this.transitionType,
    required this.createdAt,
  });
}
