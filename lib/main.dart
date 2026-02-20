import 'dart:async'; // ⏳ Timer için
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as g; // ✅ alias
import 'package:latlong2/latlong.dart' as ll; // ✅ OSM LatLng alias

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_options.dart'; // ✅ Firebase config
import 'map_page.dart';
import 'services/api_service.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}
  print('📩 [Arka Plan Bildirimi] ${message.notification?.title}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (_) {}

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(const FireSafetyApp());
}

class FireSafetyApp extends StatefulWidget {
  const FireSafetyApp({super.key});

  @override
  State<FireSafetyApp> createState() => _FireSafetyAppState();
}

class _FireSafetyAppState extends State<FireSafetyApp> {
  Timer? _fireCheckTimer;
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();

    // 🔔 Local notification init
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    _notifications.initialize(initSettings);

    // 🔥 Her 30 dakikada bir yangın verilerini kontrol et
    _fireCheckTimer = Timer.periodic(
      const Duration(minutes: 30),
      (timer) => _checkForFires(),
    );

    // 🔔 Konum izni kontrolü
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission(context);
    });

    final messaging = FirebaseMessaging.instance;

    messaging
        .requestPermission(alert: true, badge: true, sound: true)
        .then((settings) {
      print('📲 Bildirim izin durumu: ${settings.authorizationStatus}');
    });

    messaging.getToken().then((token) {
      print("🔐 Firebase Token: $token");
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        final n = message.notification!;
        _notifications.show(
          DateTime.now().millisecondsSinceEpoch ~/ 1000,
          n.title ?? "Yangın Uyarısı",
          n.body ?? "Yeni bir bildirim var.",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fire_alerts',
              'Yangın Uyarıları',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });
  }

  /// 🔥 Yangın verilerini çekip bildirim gösterme
  Future<void> _checkForFires() async {
    try {
      final records = await ApiService.fetchFireData(days: 14, countryCode: "TUR");

      if (records.isNotEmpty) {
        final fire = records.first;
        await _notifications.show(
          999,
          "🚨 Yeni Yangın Tespit Edildi!",
          "Konum: ${fire["lat"]}, ${fire["lon"]} | ${fire["acq_date"] ?? ""} ${fire["acq_time"] ?? ""}",
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fire_channel',
              'Yangın Otomatik Uyarıları',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      } else {
        print("ℹ️ Yangın verisi: 0 kayıt (TUR, 14 gün).");
      }
    } catch (e) {
      print("❌ Yangın kontrolü hatası: $e");
    }
  }

  // 📍 KONUM İZNİ KONTROLÜ
  void _checkLocationPermission(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text("Konum İzni Gerekli"),
            content: const Text(
              "Uygulamayı kullanabilmek için konum iznine izin vermeniz gerekmektedir.",
            ),
            actions: [
              TextButton(
                onPressed: () => Geolocator.openAppSettings(),
                child: const Text("Ayarları Aç"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Tamam"),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _fireCheckTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fire Safety App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  String sayilariOku(String sayi) {
    final rakamlar = {
      '0': 'sıfır',
      '1': 'bir',
      '2': 'iki',
      '3': 'üç',
      '4': 'dört',
      '5': 'beş',
      '6': 'altı',
      '7': 'yedi',
      '8': 'sekiz',
      '9': 'dokuz',
      '.': 'nokta',
      '-': 'eksi'
    };
    return sayi.split('').map((e) => rakamlar[e] ?? '').join(' ');
  }

  Future<void> yanginBildir(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position =
        await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

    final latitude = position.latitude.toStringAsFixed(4);
    final longitude = position.longitude.toStringAsFixed(4);

    final message = '''
Yangın var, yardım. Koordinatları veriyorum…

Enlem: $latitude → (${sayilariOku(latitude)})
Boylam: $longitude → (${sayilariOku(longitude)})
''';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("ACİL YARDIM MESAJI"),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Tamam"),
          ),
        ],
      ),
    );
  }

  Future<void> yanginVerileriniCek(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text("Veri Yükleniyor..."),
        content: SizedBox(
          height: 50,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      // ✅ days=14
      final addresses =
          await ApiService.fetchFireAddresses(days: 14, countryCode: "TUR");

      Navigator.pop(context);

      if (addresses.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text("Sonuç"),
            content: Text("Bu tarih aralığında FIRMS 0 yangın kaydı döndürdü."),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Yangın Noktaları (En Yakından Uzağa)"),
          content: SingleChildScrollView(child: Text(addresses.join('\n\n'))),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tamam"),
            )
          ],
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      print("❌ Hata: $e");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Hata"),
          content: Text("$e"),
        ),
      );
    }
  }

  /// ✅ split yok, direkt LatLng listesi alıyoruz
  Future<void> yanginHaritadaGoster(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        title: Text("Yangın Verileri Yükleniyor..."),
        content: SizedBox(
          height: 50,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      // ApiService hâlâ google_maps_flutter LatLng dönüyor olabilir
      final List<g.LatLng> locations =
          await ApiService.fetchFireLocations(days: 14, countryCode: "TUR");

      Navigator.pop(context);

      if (locations.isEmpty) {
        showDialog(
          context: context,
          builder: (context) => const AlertDialog(
            title: Text("Sonuç"),
            content: Text("Bu tarih aralığında FIRMS 0 yangın kaydı döndürdü."),
          ),
        );
        return;
      }

      // ✅ google_maps_flutter LatLng -> latlong2 LatLng dönüşümü
      final locationsLL = locations
          .map((p) => ll.LatLng(p.latitude, p.longitude))
          .toList();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MapPage(fireLocations: locationsLL),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      print("❌ Hata: $e");
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("Hata"),
          content: Text("$e"),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/fire.image.jpg', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.4)),
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '🔥 Fire Safety App',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Protect your home and environment from fires with smart solutions.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                ElevatedButton.icon(
                  onPressed: () => yanginBildir(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text(
                    'Yangın Bildir',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: () => yanginVerileriniCek(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  icon: const Icon(Icons.list_alt, color: Colors.white),
                  label: const Text(
                    'Yangın Verilerini Çek',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
                const SizedBox(height: 20),

                ElevatedButton.icon(
                  onPressed: () => yanginHaritadaGoster(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 30,
                      vertical: 15,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6,
                  ),
                  icon: const Icon(Icons.map, color: Colors.white),
                  label: const Text(
                    'Haritada Göster',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
