import 'dart:convert';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/shelter_point.dart';

const String mapKey = "ee38134f6842380d04add94f75c872b4"; // FIRMS MAP KEY
const String weatherApiKey = 'e4f25ae8328481b162de03410e3eae03';

class ApiService {
  /// 🔥 Türkiye yangınlarını FIRMS'ten çeker (ürünleri sırayla dener).
  /// days: 1, 7, 14 gibi.
  static Future<List<Map<String, dynamic>>> fetchFireData({
    int days = 7,
    String countryCode = "TUR",
  }) async {
    final products = <String>[
      "VIIRS_SNPP_NRT",
      "VIIRS_NOAA20_NRT",
      "MODIS_NRT",
    ];

    for (final product in products) {
      final url = Uri.parse(
        "https://firms.modaps.eosdis.nasa.gov/api/country/csv/$mapKey/$product/$countryCode/$days",
      );

      final response = await http.get(url);

      final raw = utf8.decode(response.bodyBytes);
      final preview = raw.length > 300 ? raw.substring(0, 300) : raw;

      print("🛰️ FIRMS URL: $url");
      print("🛰️ Status: ${response.statusCode} | Product: $product | Days: $days");
      print("🛰️ Body preview: $preview");

      if (response.statusCode != 200) continue;

      final lines = raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (lines.length <= 1) {
        print("⚠️ $product için sadece header geldi (0 veri). Diğer ürüne geçiliyor...");
        continue;
      }

      final headers = _splitCsvLine(lines.first);
      final results = <Map<String, dynamic>>[];

      for (int i = 1; i < lines.length; i++) {
        final cols = _splitCsvLine(lines[i]);
        if (cols.length != headers.length) continue;

        final row = <String, String>{};
        for (int j = 0; j < headers.length; j++) {
          row[headers[j]] = cols[j];
        }

        final lat = double.tryParse(row["latitude"] ?? "") ??
            double.tryParse(row["lat"] ?? "") ??
            0.0;
        final lon = double.tryParse(row["longitude"] ?? "") ??
            double.tryParse(row["lon"] ?? "") ??
            0.0;

        if (lat == 0.0 && lon == 0.0) continue;

        results.add({
          "lat": lat,
          "lon": lon,
          "product": product,
          "acq_date": row["acq_date"],
          "acq_time": row["acq_time"],
          "confidence": row["confidence"],
          "bright_ti4": row["bright_ti4"],
          "frp": row["frp"],
        });
      }

      print("🔥 $product ile yangın verileri: ${results.length} kayıt bulundu.");
      if (results.isNotEmpty) return results;
    }

    print("❌ FIRMS: Tüm ürünlerde 0 veri geldi. (days=$days, country=$countryCode)");
    return [];
  }

  /// ✅ Haritada göstermek için direkt LatLng listesi döndürür
  static Future<List<LatLng>> fetchFireLocations({
    int days = 14,
    String countryCode = "TUR",
  }) async {
    final data = await fetchFireData(days: days, countryCode: countryCode);
    return data
        .map((e) => LatLng((e["lat"] as num).toDouble(), (e["lon"] as num).toDouble()))
        .toList();
  }

  /// ✅ Yakından uzağa yangın adres listesi (reverse geocode + distance)
  static Future<List<String>> fetchFireAddresses({
    int days = 14,
    String countryCode = "TUR",
  }) async {
    final records = await fetchFireData(days: days, countryCode: countryCode);

    if (records.isEmpty) return ["ℹ️ $days gün içinde $countryCode için FIRMS kaydı bulunamadı."];

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final userLat = position.latitude;
    final userLon = position.longitude;

    final points = <Map<String, dynamic>>[];
    for (final r in records) {
      final lat = (r["lat"] as num).toDouble();
      final lon = (r["lon"] as num).toDouble();
      final dist = _calculateDistance(userLat, userLon, lat, lon);
      points.add({"lat": lat, "lon": lon, "distance": dist});
    }

    points.sort((a, b) => (a["distance"] as double).compareTo(b["distance"] as double));

    final addresses = <String>[];
    for (final p in points.take(25)) {
      try {
        final addr = await getAddress(p["lat"], p["lon"]);
        addresses.add("🔥 ${(p["distance"] as double).toStringAsFixed(2)} km - $addr");
        await Future.delayed(const Duration(milliseconds: 700));
      } catch (e) {
        addresses.add("❌ Adres alınamadı: $e");
      }
    }
    return addresses;
  }

  /// 📍 Reverse geocode (OSM Nominatim)
  static Future<String> getAddress(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/reverse?format=json&lat=$latitude&lon=$longitude',
    );

    final response = await http.get(
      url,
      headers: {'User-Agent': 'fire-safety-app'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['display_name'] ?? "Adres Bulunamadı";
    }
    return "Adres Alınamadı (Hata: ${response.statusCode})";
  }

  /// Basit CSV split
  static List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        inQuotes = !inQuotes;
        continue;
      }
      if (ch == ',' && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  /// 🌬️ OpenWeatherMap üzerinden rüzgar verisi
  static Future<Map<String, dynamic>> getWindData(double lat, double lon) async {
    final url = Uri.parse(
      'https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&appid=$weatherApiKey&units=metric',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final wind = data['wind'];
      return {
        'speed': wind['speed'],
        'deg': wind['deg'],
        'direction': windDirectionFromDegree(wind['deg']),
      };
    } else {
      throw Exception('🌬️ Rüzgar verisi alınamadı! (${response.statusCode})');
    }
  }

  static String windDirectionFromDegree(num deg) {
    if (deg >= 337.5 || deg < 22.5) return 'Kuzey';
    if (deg >= 22.5 && deg < 67.5) return 'Kuzeydoğu';
    if (deg >= 67.5 && deg < 112.5) return 'Doğu';
    if (deg >= 112.5 && deg < 157.5) return 'Güneydoğu';
    if (deg >= 157.5 && deg < 202.5) return 'Güney';
    if (deg >= 202.5 && deg < 247.5) return 'Güneybatı';
    if (deg >= 247.5 && deg < 292.5) return 'Batı';
    return 'Kuzeybatı';
  }

  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
            sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);

  /// 🛡️ Dummy sığınma noktaları (geçici)
  static List<ShelterPoint> getDummyShelterPoints() {
    return [
      ShelterPoint(
        name: 'Varsova Devlet Hastanesi',
        type: 'Hastane',
        latitude: 52.2297,
        longitude: 21.0122,
      ),
      ShelterPoint(
        name: 'Kampüs Okulu',
        type: 'Okul',
        latitude: 52.2311,
        longitude: 21.0105,
      ),
      ShelterPoint(
        name: 'Açık Toplanma Alanı',
        type: 'Açık Alan',
        latitude: 52.2289,
        longitude: 21.0142,
      ),
    ];
  }
}
