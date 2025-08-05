import 'package:flutter/material.dart';
import 'slideshow_page.dart';
import 'calendar_kiosk_app.dart'; // Import your calendar page

void main() {
  runApp(const KioskAppRoot());
}

class KioskAppRoot extends StatelessWidget {
  const KioskAppRoot({super.key});

  List<Map<String, dynamic>> getTodayImages() {
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
    return images;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Kiosk Slideshow",
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => SlideshowPage(slidesOrImages: getTodayImages()),
        '/calendar': (context) => const CalendarKioskApp(),
      },
    );
  }
}
