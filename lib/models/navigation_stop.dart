import 'package:latlong2/latlong.dart';

/// A waypoint or stop along a hazard-aware navigation route.
class NavigationStop {
  const NavigationStop({
    required this.id,
    required this.location,
    required this.displayName,
    this.address,
    this.isDestination = false,
  });

  final String id;
  final LatLng location;
  final String displayName;
  final String? address;
  final bool isDestination;

  NavigationStop copyWith({
    String? id,
    LatLng? location,
    String? displayName,
    String? address,
    bool? isDestination,
  }) {
    return NavigationStop(
      id: id ?? this.id,
      location: location ?? this.location,
      displayName: displayName ?? this.displayName,
      address: address ?? this.address,
      isDestination: isDestination ?? this.isDestination,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'lat': location.latitude,
    'lng': location.longitude,
    'displayName': displayName,
    if (address != null) 'address': address,
    'isDestination': isDestination,
  };

  factory NavigationStop.fromJson(Map<String, dynamic> json) {
    return NavigationStop(
      id: json['id'] as String,
      location: LatLng(
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      ),
      displayName: json['displayName'] as String,
      address: json['address'] as String?,
      isDestination: json['isDestination'] as bool? ?? false,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NavigationStop &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          location.latitude == other.location.latitude &&
          location.longitude == other.location.longitude &&
          displayName == other.displayName &&
          address == other.address &&
          isDestination == other.isDestination;

  @override
  int get hashCode => Object.hash(
    id,
    location.latitude,
    location.longitude,
    displayName,
    address,
    isDestination,
  );

  @override
  String toString() =>
      'NavigationStop(id: $id, name: $displayName, destination: $isDestination, coords: ${location.latitude}, ${location.longitude})';
}
