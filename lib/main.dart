import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'slideshow_page.dart';
import 'calendar_kiosk_app.dart';
import 'kiosk_server.dart';
import 'loading_page.dart'; // Import the new loading page

final kioskServer = KioskServer();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final net = await Connectivity().checkConnectivity();
  if (net == ConnectivityResult.none) {
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
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kiosk Slideshow',
      debugShowCheckedModeBanner: false,

      // Start with the loading page
      initialRoute: '/',

      routes: {
        '/': (context) => const SplashScreen(), // The new initial route
        '/calendar': (context) => const CalendarKioskApp(),
      },

      // Build slideshow from arguments pushed by Calendar page
      onGenerateRoute: (settings) {
        if (settings.name == '/kiosk') {
          final args = (settings.arguments ?? {}) as Map;

          final slidesOrImages =
              (args['slidesOrImages'] as List<Map<String, dynamic>>?) ?? const [];

          final showThirukural = (args['showThirukural'] as bool?) ?? false;
          final thirukuralAssetPath =
              (args['thirukuralAssetPath'] as String?) ?? 'assets/data/Thirukural.xlsx';
          final thirukuralBackground =
              (args['thirukuralBackground'] as String?) ?? 'assets/backgrounds/thirukural.png';

          return MaterialPageRoute(
            builder: (_) => SlideshowPage(
              slidesOrImages: slidesOrImages,
              showThirukural: showThirukural,
              thirukuralAssetPath: thirukuralAssetPath,
              thirukuralBackground: thirukuralBackground,
            ),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}