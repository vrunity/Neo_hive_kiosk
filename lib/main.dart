import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'slideshow_page.dart';
import 'calendar_kiosk_app.dart';
import 'kiosk_server.dart';  // import your server here

final kioskServer = KioskServer();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Check network connectivity before starting server
  var connectivityResult = await Connectivity().checkConnectivity();
  if (connectivityResult == ConnectivityResult.none) {
    // No network, show error UI by running app with error widget
    runApp(const NoNetworkApp());
    return;
  }

  await kioskServer.start();

  runApp(const KioskAppRoot());
}

class NoNetworkApp extends StatelessWidget {
  const NoNetworkApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'No network connection detected.\nPlease connect to WiFi and restart the app.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
        ),
      ),
    );
  }
}

class KioskAppRoot extends StatefulWidget {
  const KioskAppRoot({super.key});

  @override
  State<KioskAppRoot> createState() => _KioskAppRootState();
}

class _KioskAppRootState extends State<KioskAppRoot> {
  List<Map<String, dynamic>> _todayImages = [];

  @override
  void initState() {
    super.initState();
    _loadTodayImages();
  }

  void _loadTodayImages() {
    final todayStr = DateTime.now().toIso8601String().substring(0, 10);
    List<Map<String, dynamic>> images = [];
    for (int i = 1; i <= 5; i++) {
      final path = 'assets/images/${todayStr}_$i.jpg';
      images.add({
        'path': path,
        'name': 'Image $i',
        'duration_seconds': 5,
      });
    }
    setState(() {
      _todayImages = images;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Kiosk Slideshow",
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => SlideshowPage(slidesOrImages: _todayImages),
        '/calendar': (context) => const CalendarKioskApp(),
      },
    );
  }
}