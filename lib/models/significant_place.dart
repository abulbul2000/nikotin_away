/// A place the user visits often enough to be worth a geofence, discovered
/// entirely from foreground samples (never a stored location trail — see
/// PlaceClusteringEngine). Only the finalized centroid is persisted, capped
/// at [SignificantPlace.maxPlaces] rows.
class SignificantPlace {
  static const int maxPlaces = 8;

  final String id;
  final double latitude;
  final double longitude;
  final int visitCount;
  final DateTime firstSeenAt;
  final DateTime lastSeenAt;

  const SignificantPlace({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.visitCount,
    required this.firstSeenAt,
    required this.lastSeenAt,
  });

  SignificantPlace copyWith({
    int? visitCount,
    double? latitude,
    double? longitude,
    DateTime? lastSeenAt,
  }) {
    return SignificantPlace(
      id: id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      visitCount: visitCount ?? this.visitCount,
      firstSeenAt: firstSeenAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
