import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/shelter_point.dart';
import 'services/api_service.dart';

// ✅ Enum TOP-LEVEL olmalı (class içine yazılmaz)
enum TravelMode { driving, walking }

class MapPage extends StatefulWidget {
  final List<LatLng> fireLocations;

  const MapPage({super.key, required this.fireLocations});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final List<Marker> _fireMarkers = [];
  final List<Marker> _shelterMarkers = [];

  bool _loadingShelters = false;

  @override
  void initState() {
    super.initState();
    _loadFireMarkers();
    _loadSheltersSmart(); // ✅ Türkiye’deyse kullanıcı konumu, değilse TR büyük şehirler
  }

  // =========================
  // Travel + Share helpers
  // =========================
  String _travelModeToString(TravelMode mode) {
    return mode == TravelMode.driving ? "driving" : "walking";
  }

  /// Google Maps yönlendirme
  Future<void> _openDirections({
    required double lat,
    required double lon,
    TravelMode mode = TravelMode.driving,
  }) async {
    final travelMode = _travelModeToString(mode);

    final uri = Uri.parse(
      "https://www.google.com/maps/dir/?api=1&destination=$lat,$lon&travelmode=$travelMode",
    );

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception("Google Maps açılamadı.");
    }
  }

  /// Konum paylaş (WhatsApp/Telegram vs.)
  void _shareLocation({
    required String title,
    required double lat,
    required double lon,
  }) {
    final mapsLink = "https://www.google.com/maps?q=$lat,$lon";
    final text = "$title\n📍 $lat, $lon\n🗺️ $mapsLink";
    Share.share(text);
  }

  void _showPlaceActionsSheet({
    required String title,
    required String type,
    required double lat,
    required double lon,
    String? subtitle,
  }) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "$title • $type",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(subtitle),
                ],
                const SizedBox(height: 10),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _openDirections(
                        lat: lat,
                        lon: lon,
                        mode: TravelMode.driving,
                      ),
                      icon: const Icon(Icons.directions_car),
                      label: const Text("Araba ile"),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _openDirections(
                        lat: lat,
                        lon: lon,
                        mode: TravelMode.walking,
                      ),
                      icon: const Icon(Icons.directions_walk),
                      label: const Text("Yürüyerek"),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                OutlinedButton.icon(
                  onPressed: () => _shareLocation(
                    title: "$title ($type)",
                    lat: lat,
                    lon: lon,
                  ),
                  icon: const Icon(Icons.share),
                  label: const Text("Paylaş (WhatsApp/Telegram)"),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // =========================
  // 1) Fire markers
  // =========================
  Future<void> _loadFireMarkers() async {
    final List<Marker> markers = [];

    for (final loc in widget.fireLocations) {
      final lat = loc.latitude;
      final lon = loc.longitude;

      markers.add(
        Marker(
          width: 44,
          height: 44,
          point: LatLng(lat, lon),
          child: GestureDetector(
            onTap: () async {
              // BottomSheet aç + rüzgar göster + yol tarifi + paylaş
              String windText = "Yükleniyor...";
              try {
                final direction = await _fetchWindDirection(lat, lon);
                windText = "🌬️ Rüzgar: $direction";
              } catch (_) {
                windText = "🌬️ Rüzgar alınamadı";
              }

              if (!mounted) return;

              _showPlaceActionsSheet(
                title: "🔥 Yangın Noktası",
                type: "Yangın",
                lat: lat,
                lon: lon,
                subtitle: "📍 $lat, $lon\n$windText",
              );
            },
            child: const Icon(
              Icons.local_fire_department,
              size: 34,
              color: Colors.red,
            ),
          ),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _fireMarkers
        ..clear()
        ..addAll(markers);
    });
  }

  // =========================
  // 2) Smart shelters
  // =========================
  bool _isInTurkeyRough(double lat, double lon) {
    // Syria-Iraq şeridini kesmek için south 36.0
    return lat >= 36.0 && lat <= 42.3 && lon >= 25.5 && lon <= 45.5;
  }

  Future<void> _loadSheltersSmart() async {
    if (!mounted) return;
    setState(() => _loadingShelters = true);

    try {
      double? uLat;
      double? uLon;

      try {
        final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.medium,
        );
        uLat = pos.latitude;
        uLon = pos.longitude;
      } catch (_) {
        // konum alınamazsa fallback’e düş
      }

      List<ShelterPoint> shelters = [];

      // ✅ Türkiye’deyse: kullanıcıya yakın çek (hafif parametre)
      if (uLat != null && uLon != null && _isInTurkeyRough(uLat, uLon)) {
        shelters = await ApiService.fetchSheltersFromOSM(
          lat: uLat,
          lon: uLon,
          radiusKm: 15,
          limit: 120,
          includePharmacy: true,
          includeSchool: true,
        );
      } else {
        // ✅ Türkiye’de değilse: büyük şehirlerden çek (hafif parametre)
        shelters = await ApiService.fetchSheltersForMajorCitiesTR(
          radiusKm: 15,
          perCityLimit: 35,
          includePharmacy: true,
          includeSchool: true,
        );
      }

      final markers = shelters.map((s) {
        final color = _colorForShelterType(s.type);

        return Marker(
          width: 44,
          height: 44,
          point: LatLng(s.latitude, s.longitude),
          child: GestureDetector(
            onTap: () {
              _showPlaceActionsSheet(
                title: s.name,
                type: _shelterTypeLabelTR(s.type),
                lat: s.latitude,
                lon: s.longitude,
                subtitle: "📍 ${s.latitude}, ${s.longitude}",
              );
            },
            child: Icon(
              Icons.location_on,
              size: 34,
              color: color,
            ),
          ),
        );
      }).toList();

      if (!mounted) return;
      setState(() {
        _shelterMarkers
          ..clear()
          ..addAll(markers);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("⚠️ Sığınma noktaları geçici olarak yüklenemedi."),
          duration: Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingShelters = false);
    }
  }

  String _shelterTypeLabelTR(String t) {
    switch (t) {
      case "hospital":
        return "Hastane";
      case "fire_station":
        return "İtfaiye";
      case "police":
        return "Polis";
      case "pharmacy":
        return "Eczane";
      case "school":
        return "Okul";
      case "shelter":
        return "Sığınma Noktası";
      default:
        return "Konum";
    }
  }

  Color _colorForShelterType(String t) {
    switch (t) {
      case "hospital":
        return Colors.blue;
      case "fire_station":
        return Colors.deepOrange;
      case "police":
        return Colors.indigo;
      case "pharmacy":
        return Colors.purple;
      case "school":
        return Colors.teal;
      case "shelter":
        return Colors.green;
      default:
        return Colors.green;
    }
  }

  // =========================
  // 3) Wind direction (ApiService üzerinden)
  // =========================
  Future<String> _fetchWindDirection(double lat, double lon) async {
    final windData = await ApiService.getWindData(lat, lon);
    return (windData["direction"] ?? "Bilinmiyor").toString();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    final LatLng center = widget.fireLocations.isNotEmpty
        ? widget.fireLocations.first
        : const LatLng(39.9255, 32.8664);

    return Scaffold(
      appBar: AppBar(
        title: const Text("🔥 Yangın Haritası (OSM)"),
        backgroundColor: Colors.red,
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: center,
              initialZoom: 6,
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: "com.example.firesafetapp_fixed_new",
              ),
              // ✅ önce sığınmalar, sonra yangınlar (yangınlar üstte)
              MarkerLayer(markers: [..._shelterMarkers, ..._fireMarkers]),
            ],
          ),

          // ✅ Harita açıklaması
          Positioned(
            left: 12,
            top: 12,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Harita Açıklaması",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 6),
                    _LegendRow(color: Colors.red, label: "Yangın"),
                    _LegendRow(color: Colors.blue, label: "Hastane"),
                    _LegendRow(color: Colors.deepOrange, label: "İtfaiye"),
                    _LegendRow(color: Colors.indigo, label: "Polis"),
                    _LegendRow(color: Colors.purple, label: "Eczane"),
                    _LegendRow(color: Colors.teal, label: "Okul"),
                    _LegendRow(color: Colors.green, label: "Sığınma Noktası"),
                  ],
                ),
              ),
            ),
          ),

          // ✅ Loading
          if (_loadingShelters)
            const Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(10),
                  child: Text("Sığınma noktaları yükleniyor..."),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ✅ Legend satırı
class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendRow({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}
