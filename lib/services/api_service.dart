import 'dart:convert';
import 'dart:math';

import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

import '../models/shelter_point.dart';

/// ✅ FIRMS MAP_KEY
/// GitHub'a key yazmamak için --dart-define ile ver:
/// flutter run --dart-define=FIRMS_MAP_KEY=YOUR_KEY
const String firmsMapKey = String.fromEnvironment(
  'FIRMS_MAP_KEY',
  defaultValue: 'PUT_YOUR_FIRMS_MAP_KEY_HERE',
);

/// ✅ OpenWeather KEY (dart-define ile ver)
/// flutter run --dart-define=OPENWEATHER_API_KEY=YOUR_KEY
const String weatherApiKey = String.fromEnvironment(
  'OPENWEATHER_API_KEY',
  defaultValue: 'PUT_OPENWEATHER_API_KEY_HERE',
);

class ApiService {
  /// Türkiye bounding box (west,south,east,north)
  static const String _turkeyBbox = "25.66,35.80,44.82,42.11";

  /// FIRMS Area API: DAY_RANGE sadece 1..5
  static const int _maxChunkDays = 5;

  /// Ürünleri sırayla deniyoruz
  static const List<String> _products = [
    "VIIRS_SNPP_NRT",
    "VIIRS_NOAA20_NRT",
    "VIIRS_NOAA21_NRT",
    "MODIS_NRT",
  ];

  /// ✅ Türkiye kaba filtre (Suriye/Irak şeridini kesmek için south=36.0)
  static bool _isInTurkeyRough(double lat, double lon) {
    return lat >= 36.0 && lat <= 42.3 && lon >= 25.5 && lon <= 45.5;
  }

  /// 🔥 Türkiye yangın verileri (son N gün) - Area API üzerinden
  /// days=14 gibi değerler burada OK (içeride 5'lik parçalara bölüyoruz)
  static Future<List<Map<String, dynamic>>> fetchFireData({
    int days = 5,
    String countryCode = "TUR",
  }) async {
    if (firmsMapKey == "PUT_YOUR_FIRMS_MAP_KEY_HERE") {
      throw Exception(
        "FIRMS_MAP_KEY ayarlanmadı. "
        "Çalıştırırken ver: flutter run --dart-define=FIRMS_MAP_KEY=YOUR_KEY",
      );
    }

    final bbox =
        (countryCode.toUpperCase() == "TUR") ? _turkeyBbox : _turkeyBbox;

    final totalDays = days < 1 ? 1 : days;

    for (final product in _products) {
      final results = <Map<String, dynamic>>[];

      int remaining = totalDays;
      DateTime cursor =
          DateTime.now().toUtc().subtract(Duration(days: totalDays - 1));

      while (remaining > 0) {
        final chunk = remaining > _maxChunkDays ? _maxChunkDays : remaining;
        final dateStr = _fmtDate(cursor);

        final url = Uri.parse(
          "https://firms.modaps.eosdis.nasa.gov/api/area/csv/"
          "$firmsMapKey/$product/$bbox/$chunk/$dateStr",
        );

        final response = await http.get(url);
        final raw = utf8.decode(response.bodyBytes);

        // FIRMS bazen 200 dönüp body’de hata yazar
        if (raw.toLowerCase().contains("invalid api call")) {
          throw Exception(
            "FIRMS: Invalid API call. Endpoint/parametre/mapkey kontrol edin. "
            "Not: Area API kullanılmalı ve chunk 1..5 olmalı.",
          );
        }

        if (response.statusCode != 200) {
          remaining -= chunk;
          cursor = cursor.add(Duration(days: chunk));
          continue;
        }

        final lines = raw
            .split('\n')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // sadece header geldiyse
        if (lines.length <= 1) {
          remaining -= chunk;
          cursor = cursor.add(Duration(days: chunk));
          continue;
        }

        final headers = _splitCsvLine(lines.first);

        for (int i = 1; i < lines.length; i++) {
          final cols = _splitCsvLine(lines[i]);
          if (cols.length != headers.length) continue;

          final row = <String, String>{};
          for (int j = 0; j < headers.length; j++) {
            row[headers[j]] = cols[j];
          }

          final lat =
              double.tryParse(row["latitude"] ?? row["lat"] ?? "") ?? 0.0;
          final lon =
              double.tryParse(row["longitude"] ?? row["lon"] ?? "") ?? 0.0;

          if (lat == 0.0 && lon == 0.0) continue;

          // ✅ Türkiye dışını at (Suriye/Irak şeridi temizlenir)
          if (!_isInTurkeyRough(lat, lon)) continue;

          results.add({
            "lat": lat,
            "lon": lon,
            "product": product,
            "acq_date": row["acq_date"],
            "acq_time": row["acq_time"],
            "confidence": row["confidence"],
            "frp": row["frp"],
            "brightness": row["bright_ti4"] ?? row["brightness"],
          });
        }

        remaining -= chunk;
        cursor = cursor.add(Duration(days: chunk));
      }

      if (results.isNotEmpty) return results;
    }

    return [];
  }

  /// ✅ Harita için direkt LatLng listesi
  static Future<List<LatLng>> fetchFireLocations({
    int days = 14,
    String countryCode = "TUR",
    int limit = 800,
  }) async {
    final data = await fetchFireData(days: days, countryCode: countryCode);

    final locations = <LatLng>[];
    for (final row in data) {
      final lat = (row["lat"] as num).toDouble();
      final lon = (row["lon"] as num).toDouble();
      locations.add(LatLng(lat, lon));
      if (locations.length >= limit) break;
    }
    return locations;
  }

  /// ✅ “Yangın Verilerini Çek” için adres listesi (yakına göre)
  static Future<List<String>> fetchFireAddresses({
    int days = 14,
    String countryCode = "TUR",
    int maxItems = 15,
  }) async {
    final records = await fetchFireData(days: days, countryCode: countryCode);

    if (records.isEmpty) {
      return ["⚠️ FIRMS: Bu tarih aralığında 0 yangın kaydı döndürdü."];
    }

    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    final userLat = position.latitude;
    final userLon = position.longitude;

    final points = <Map<String, dynamic>>[];

    for (final r in records) {
      final lat = (r["lat"] as num).toDouble();
      final lon = (r["lon"] as num).toDouble();
      final dist = _calculateDistanceKm(userLat, userLon, lat, lon);

      points.add({
        "lat": lat,
        "lon": lon,
        "distance": dist,
        "acq_date": r["acq_date"],
        "acq_time": r["acq_time"],
        "product": r["product"],
      });
    }

    points.sort(
      (a, b) => (a["distance"] as double).compareTo(b["distance"] as double),
    );

    final addresses = <String>[];
    for (final p in points.take(maxItems)) {
      final lat = p["lat"] as double;
      final lon = p["lon"] as double;
      final dist = p["distance"] as double;

      try {
        final address = await getAddress(lat, lon);
        addresses.add(
          "🔥 ${dist.toStringAsFixed(2)} km | "
          "${p["acq_date"] ?? ""} ${p["acq_time"] ?? ""} | "
          "${p["product"]}\n$address",
        );
        await Future.delayed(const Duration(milliseconds: 700));
      } catch (e) {
        addresses.add("❌ ${dist.toStringAsFixed(2)} km - Adres alınamadı: $e");
      }
    }

    return addresses;
  }

  /// OSM reverse geocode
  static Future<String> getAddress(double latitude, double longitude) async {
    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/reverse"
      "?format=json&lat=$latitude&lon=$longitude",
    );

    final response = await http.get(
      url,
      headers: const {"User-Agent": "fire-safety-app"},
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data["display_name"] ?? "Adres Bulunamadı";
    }
    return "Adres Alınamadı (Hata: ${response.statusCode})";
  }

  /// OpenWeather rüzgar
  static Future<Map<String, dynamic>> getWindData(double lat, double lon) async {
    if (weatherApiKey == "PUT_OPENWEATHER_API_KEY_HERE") {
      throw Exception(
        "OPENWEATHER_API_KEY ayarlanmadı. "
        "Çalıştırırken ver: flutter run --dart-define=OPENWEATHER_API_KEY=YOUR_KEY",
      );
    }

    final url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather"
      "?lat=$lat&lon=$lon&appid=$weatherApiKey&units=metric",
    );

    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final wind = data["wind"];
      return {
        "speed": wind["speed"],
        "deg": wind["deg"],
        "direction": windDirectionFromDegree(wind["deg"]),
      };
    }
    throw Exception("🌬️ Rüzgar verisi alınamadı! (${response.statusCode})");
  }

  static String windDirectionFromDegree(num deg) {
    if (deg >= 337.5 || deg < 22.5) return "Kuzey";
    if (deg >= 22.5 && deg < 67.5) return "Kuzeydoğu";
    if (deg >= 67.5 && deg < 112.5) return "Doğu";
    if (deg >= 112.5 && deg < 157.5) return "Güneydoğu";
    if (deg >= 157.5 && deg < 202.5) return "Güney";
    if (deg >= 202.5 && deg < 247.5) return "Güneybatı";
    if (deg >= 247.5 && deg < 292.5) return "Batı";
    return "Kuzeybatı";
  }

  // =========================
  // Overpass Retry + Fallback
  // =========================

  static final List<Uri> _overpassMirrors = [
    Uri.parse("https://overpass-api.de/api/interpreter"),
    Uri.parse("https://overpass.kumi.systems/api/interpreter"),
    Uri.parse("https://overpass.nchc.org.tw/api/interpreter"),
  ];

  static Future<http.Response> _postOverpassWithRetry(String query) async {
    const int maxAttempts = 3;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final uri = _overpassMirrors[attempt % _overpassMirrors.length];

      try {
        final resp = await http
            .post(
              uri,
              headers: const {"Content-Type": "text/plain; charset=utf-8"},
              body: query,
            )
            .timeout(const Duration(seconds: 20));

        if (resp.statusCode == 200) return resp;

        final retryable = resp.statusCode == 429 ||
            resp.statusCode == 504 ||
            (resp.statusCode >= 500 && resp.statusCode <= 599);

        if (!retryable) return resp;
      } catch (_) {
        // timeout / network -> retry
      }

      await Future.delayed(Duration(milliseconds: 600 * (attempt + 1)));
    }

    throw Exception("Overpass error: 504 (retry sonrası da time-out)");
  }

  // =========================
  // OSM / Overpass Shelters
  // =========================

  // Basit cache (aynı merkezde sürekli istek atmasın)
  static DateTime? _lastShelterFetchAt;
  static String? _lastShelterKey;
  static List<ShelterPoint> _lastShelters = [];

  /// Merkeze yakın sığınma/yardım noktaları (hızlı/optimize)
  static Future<List<ShelterPoint>> fetchSheltersFromOSM({
    required double lat,
    required double lon,
    int radiusKm = 20, // ✅ düşürüldü (50 -> 20)
    int limit = 120, // ✅ düşürüldü (200 -> 120)
    bool includePharmacy = true,
    bool includeSchool = true,
  }) async {
    final now = DateTime.now();

    // ✅ Cache: aynı merkez + 10 dk dolmadan tekrar çekme
    final cacheKey =
        "${lat.toStringAsFixed(3)},${lon.toStringAsFixed(3)}-$radiusKm-$limit";

    if (_lastShelterFetchAt != null &&
        _lastShelterKey == cacheKey &&
        now.difference(_lastShelterFetchAt!).inMinutes < 10 &&
        _lastShelters.isNotEmpty) {
      return _lastShelters;
    }

    final radiusMeters = radiusKm * 1000;

    final parts = <String>[
      'node(around:$radiusMeters,$lat,$lon)["amenity"="hospital"];',
      'way(around:$radiusMeters,$lat,$lon)["amenity"="hospital"];',
      'relation(around:$radiusMeters,$lat,$lon)["amenity"="hospital"];',
      'node(around:$radiusMeters,$lat,$lon)["amenity"="fire_station"];',
      'way(around:$radiusMeters,$lat,$lon)["amenity"="fire_station"];',
      'relation(around:$radiusMeters,$lat,$lon)["amenity"="fire_station"];',
      'node(around:$radiusMeters,$lat,$lon)["amenity"="police"];',
      'way(around:$radiusMeters,$lat,$lon)["amenity"="police"];',
      'relation(around:$radiusMeters,$lat,$lon)["amenity"="police"];',
    ];

    if (includeSchool) {
      parts.addAll([
        'node(around:$radiusMeters,$lat,$lon)["amenity"="school"];',
        'way(around:$radiusMeters,$lat,$lon)["amenity"="school"];',
        'relation(around:$radiusMeters,$lat,$lon)["amenity"="school"];',
      ]);
    }

    if (includePharmacy) {
      parts.addAll([
        'node(around:$radiusMeters,$lat,$lon)["amenity"="pharmacy"];',
        'way(around:$radiusMeters,$lat,$lon)["amenity"="pharmacy"];',
        'relation(around:$radiusMeters,$lat,$lon)["amenity"="pharmacy"];',
      ]);
    }

    // “emergency=shelter” (her yerde yok ama varsa gelsin)
    parts.addAll([
      'node(around:$radiusMeters,$lat,$lon)["emergency"="shelter"];',
      'way(around:$radiusMeters,$lat,$lon)["emergency"="shelter"];',
      'relation(around:$radiusMeters,$lat,$lon)["emergency"="shelter"];',
    ]);

    final query = '''
[out:json][timeout:15];
(
${parts.join("\n")}
);
out center $limit;
''';

    // ✅ retry + mirror
    final resp = await _postOverpassWithRetry(query);

    if (resp.statusCode != 200) {
      throw Exception("Overpass error: ${resp.statusCode}");
    }

    final jsonData = jsonDecode(utf8.decode(resp.bodyBytes));
    final elements = (jsonData["elements"] as List?) ?? [];

    final results = <ShelterPoint>[];
    final seen = <String>{};

    for (final el in elements) {
      final elType = (el["type"] ?? "").toString();
      final id = (el["id"] ?? "").toString();

      // node -> lat/lon var, way/relation -> center.lat/center.lon var
      double? pLat;
      double? pLon;

      if (elType == "node") {
        pLat = (el["lat"] as num?)?.toDouble();
        pLon = (el["lon"] as num?)?.toDouble();
      } else {
        final center = el["center"];
        if (center != null) {
          pLat = (center["lat"] as num?)?.toDouble();
          pLon = (center["lon"] as num?)?.toDouble();
        }
      }

      if (pLat == null || pLon == null) continue;

      final tags = (el["tags"] as Map?) ?? {};
      final amenity = (tags["amenity"] ?? "").toString();
      final emergency = (tags["emergency"] ?? "").toString();

      final shelterType = _mapShelterType(amenity, emergency);
      if (shelterType == "unknown") continue;

      final name =
          (tags["name"] ?? _defaultNameForType(shelterType)).toString();

      // basit unique key
      final uniqueKey = "$elType-$id";
      if (seen.contains(uniqueKey)) continue;
      seen.add(uniqueKey);

      results.add(
        ShelterPoint(
          name: name,
          type: shelterType,
          latitude: pLat,
          longitude: pLon,
          osmId: uniqueKey,
        ),
      );
    }

    _lastShelterFetchAt = now;
    _lastShelterKey = cacheKey;
    _lastShelters = results;

    return results;
  }

  // =========================
  // TR Major Cities Fallback
  // =========================

  /// Kullanıcı Türkiye'de değilse (ör. Polonya) demo için Türkiye büyük şehirlerinden
  /// sığınma/yardım noktalarını toplu çeker.
  static Future<List<ShelterPoint>> fetchSheltersForMajorCitiesTR({
    int radiusKm = 20,
    int perCityLimit = 70,
    bool includePharmacy = true,
    bool includeSchool = true,
  }) async {
    // Büyük şehir merkezleri (yaklaşık)
    const cities = <Map<String, dynamic>>[
      {"name": "İstanbul", "lat": 41.0082, "lon": 28.9784},
      {"name": "Ankara", "lat": 39.9334, "lon": 32.8597},
      {"name": "İzmir", "lat": 38.4237, "lon": 27.1428},
      {"name": "Bursa", "lat": 40.1950, "lon": 29.0600},
      {"name": "Antalya", "lat": 36.8969, "lon": 30.7133},
      {"name": "Adana", "lat": 37.0000, "lon": 35.3213},
      {"name": "Gaziantep", "lat": 37.0662, "lon": 37.3833},
      {"name": "Konya", "lat": 37.8716, "lon": 32.4846},
      {"name": "Kayseri", "lat": 38.7225, "lon": 35.4875},
      {"name": "Samsun", "lat": 41.2867, "lon": 36.3300},
    ];

    final all = <ShelterPoint>[];
    final seen = <String>{};

    for (final c in cities) {
      try {
        final lat = c["lat"] as double;
        final lon = c["lon"] as double;

        // Şehir şehir çekiyoruz (Overpass’ı yormamak için limit düşük)
        final shelters = await fetchSheltersFromOSM(
          lat: lat,
          lon: lon,
          radiusKm: radiusKm,
          limit: perCityLimit,
          includePharmacy: includePharmacy,
          includeSchool: includeSchool,
        );

        for (final s in shelters) {
          // osmId varsa onunla unique yap, yoksa lat-lon-name
          final key = (s.osmId != null && s.osmId!.isNotEmpty)
              ? s.osmId!
              : "${s.latitude.toStringAsFixed(5)},${s.longitude.toStringAsFixed(5)}-${s.name}-${s.type}";

          if (seen.add(key)) {
            all.add(s);
          }
        }
      } catch (_) {
        // bu şehirde Overpass patladıysa geç
      }

      // ✅ mini bekleme (Overpass ban/504 riskini düşürür)
      await Future.delayed(const Duration(milliseconds: 800));
    }

    return all;
  }

  static String _mapShelterType(String amenity, String emergency) {
    if (emergency == "shelter") return "shelter";
    switch (amenity) {
      case "hospital":
        return "hospital";
      case "fire_station":
        return "fire_station";
      case "police":
        return "police";
      case "school":
        return "school";
      case "pharmacy":
        return "pharmacy";
      default:
        return "unknown";
    }
  }

  static String _defaultNameForType(String t) {
    switch (t) {
      case "hospital":
        return "Hastane";
      case "fire_station":
        return "İtfaiye";
      case "police":
        return "Polis";
      case "school":
        return "Okul";
      case "pharmacy":
        return "Eczane";
      case "shelter":
        return "Sığınma Noktası";
      default:
        return "Nokta";
    }
  }

  // ---- helpers ----

  static String _fmtDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, "0");
    final m = dt.month.toString().padLeft(2, "0");
    final d = dt.day.toString().padLeft(2, "0");
    return "$y-$m-$d";
  }

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
      if (ch == "," && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(ch);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  static double _calculateDistanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) *
            cos(_deg2rad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  static double _deg2rad(double deg) => deg * (pi / 180);
}
