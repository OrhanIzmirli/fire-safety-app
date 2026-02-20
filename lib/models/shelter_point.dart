class ShelterPoint {
  final String name;
  final String type;
  final double latitude;
  final double longitude;

  // opsiyonel
  final String? address;
  final String? osmId;

  ShelterPoint({
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    this.address,
    this.osmId,
  });
}
