import 'dart:async'; // NEW: Import for Timer
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'slideshow_page.dart'; // Assuming you have this file for your slideshow UI

// --- CONSTANTS (No changes here) ---
const Map<String, List<String>> assetFolders = {
  'Confined Space': ['assets/Confined Space/confined space entry.jpg',],
  'EOT Crane': ['assets/EOT Crane/eot authorized person.jpg', 'assets/EOT Crane/EOT crane - 2.jpg', 'assets/EOT Crane/EOT crane - 3.jpg', 'assets/EOT Crane/eot hook.jpg', 'assets/EOT Crane/load limit.jpg',],
  'First Aid': ['assets/First Aid/aed.jpg', 'assets/First Aid/Be trained.jpg', 'assets/First Aid/CPR.jpg', 'assets/First Aid/CPR 2.jpg', 'assets/First Aid/CPR 3.jpg', 'assets/First Aid/eye wash station.jpg',],
  'Forklift': ['assets/Forklift/Forklift - 01.jpg', 'assets/Forklift/Forklift - 02.jpg', 'assets/Forklift/Forklift - 03.jpg',],
  'Hazards': ['assets/Hazards/Chemical  hazard.jpg', 'assets/Hazards/Fall hazard.jpg',],
  'Hight work': ['assets/Hight work/fall production.jpg', 'assets/Hight work/fall production - 2.jpg', 'assets/Hight work/ladder safety.jpg', 'assets/Hight work/suspended load.jpg', 'assets/Hight work/suspended load 2.jpg',],
  'Hot work': ['assets/Hot work/Felding. psd.jpg', 'assets/Hot work/hot work.jpg', 'assets/Hot work/Pass procedure.jpg',],
  'Labours day': ['assets/Labours day/May 1.jpg',],
  'Ladder safety': ['assets/Ladder safety/Ladder 1.jpg', 'assets/Ladder safety/Ladder 2.jpg', 'assets/Ladder safety/Ladder 3.jpg', 'assets/Ladder safety/Ladder 4.jpg',],
  'Material handling': ['assets/Material handling/award position.jpg', 'assets/Material handling/center of gravity.jpg', 'assets/Material handling/over load.jpg',],
  'MSDS': ['assets/MSDS/Chemical handling.jpg', 'assets/MSDS/Chemical spill.jpg', 'assets/MSDS/Chemical spill 2.jpg', 'assets/MSDS/lables.jpg', 'assets/MSDS/MSDS-1.jpg', 'assets/MSDS/Waste Disposal.jpg',],
  'Near misses': ['assets/Near misses/accidents.jpg', 'assets/Near misses/near miss.jpg', 'assets/Near misses/Prevent trips .jpg', 'assets/Near misses/Report gas leak.jpg',],
  'PPE': ['assets/PPE/ear.jpg', 'assets/PPE/ear 2.jpg', 'assets/PPE/eye protection.jpg', 'assets/PPE/face mask.jpg', 'assets/PPE/Face sheild.jpg', 'assets/PPE/gloves.jpg', 'assets/PPE/gloves - 2.jpg', 'assets/PPE/head production.jpg', 'assets/PPE/helmet.jpg', 'assets/PPE/helmet safety.jpg', 'assets/PPE/helmet 2.jpg', 'assets/PPE/helmet 3.jpg', 'assets/PPE/helmet 4.jpg', 'assets/PPE/mask.jpg', 'assets/PPE/ppe.jpg', 'assets/PPE/shoe.jpg',],
  'Scaffolding': ['assets/Scaffolding/scaffolding.jpg', 'assets/Scaffolding/scaffolding - 2.jpg', 'assets/Scaffolding/scaffolding 3.jpg',],
  'Unsafe act': ['assets/Unsafe act/prevent accident.jpg', 'assets/Unsafe act/unsafe act.jpg', 'assets/Unsafe act/unsafe act - 2.jpg',],
  'Women safety': ['assets/Women safety/women 2.jpg', 'assets/Women safety/Womens day.jpg', 'assets/Women safety/Womens day 2.jpg', 'assets/Women safety/Womens day 3.jpg',],
};

const Map<int, String> folderNumberToName = {
  1: 'Confined Space', 2: 'EOT Crane', 3: 'First Aid', 4: 'Forklift', 5: 'Hazards', 6: 'Hight work', 7: 'Hot work', 8: 'Labours day', 9: 'Ladder safety', 10: 'Material handling', 11: 'MSDS', 12: 'Near misses', 13: 'Others', 14: 'PPE', 15: 'Scaffolding', 16: 'Unsafe act', 17: 'Women safety',
};

// =========================================================================
// SPLASH SCREEN WIDGET (No changes here)
// =========================================================================
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateAfterSplash();
  }

  Future<void> _navigateAfterSplash() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const KioskControllerPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<int>(1),
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Text(
              'NEO HIVE',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 30.0),
              child: const Text(
                'Powered by LEE SAFEZONE, C/O SEED FOR SAFETY',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// KIOSK CONTROLLER PAGE (Changes are here)
// =========================================================================
class KioskControllerPage extends StatefulWidget {
  const KioskControllerPage({super.key});

  @override
  State<KioskControllerPage> createState() => _KioskControllerPageState();
}

class _KioskControllerPageState extends State<KioskControllerPage> {
  // --- STATE VARIABLES ---
  bool _isLoading = true;
  List<Map<String, dynamic>> _slideshowItems = [];
  bool _showThirukural = false;

  // NEW: Timer for periodic data checks.
  Timer? _dataCheckTimer;
  // NEW: Stores the last successfully processed raw JSON to prevent unnecessary rebuilds.
  String? _currentRawData;

  @override
  void initState() {
    super.initState();
    // 1. Perform the initial data load.
    _processData();
    // 2. Start the timer to periodically check for updates.
    _startDataRefreshTimer();
  }

  // NEW: This method sets up a recurring timer to check for data changes.
  void _startDataRefreshTimer() {
    // Timer.periodic creates a timer that fires every 5 seconds.
    _dataCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkForUpdates();
    });
  }

  // NEW: This function runs every 5 seconds to check for new data.
  Future<void> _checkForUpdates() async {
    final prefs = await SharedPreferences.getInstance();
    final newRawData = prefs.getString('calendar_events');

    // As requested: Print the fetched data every 5 seconds.
    print("--- [${DateTime.now()}] Polling SharedPreferences... ---");
    print(newRawData ?? "No data found in SharedPreferences.");

    // CRITICAL: Only proceed if new data exists AND it's different from what's currently loaded.
    if (newRawData != null && newRawData != _currentRawData) {
      print("--- New data detected! Reloading slideshow. ---");
      // Call _processData which will update state, UI, and _currentRawData.
      await _processData();
    }
  }

  /// This function processes the data from SharedPreferences and updates the UI.
  Future<void> _processData() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('calendar_events');

    // Store the raw data we are about to process. This will become our new baseline.
    _currentRawData = raw;

    List<Map<String, dynamic>> slideshowReadyEvents = [];
    bool dailyThirukural = false;
    Map<String, dynamic>? safetyDashboard;
    bool safetyEnabled = false;

    if (raw != null) {
      try {
        final Map<String, dynamic> data = jsonDecode(raw);
        dailyThirukural = (data['daily_thirukural'] as bool?) ?? false;

        final dynamic rawEventsData = data['events'];
        final todayKey = DateTime.now();
        final normalizedToday = DateTime(todayKey.year, todayKey.month, todayKey.day);

        if (rawEventsData is List) {
          for (var eventData in rawEventsData) {
            if (eventData is! Map<String, dynamic>) continue;
            final dateStr = eventData['date'];
            final date = DateTime.tryParse(dateStr);
            if (date == null) continue;
            final normalizedDate = DateTime(date.year, date.month, date.day);

            if (normalizedDate == normalizedToday) {
              final imagesList = eventData['images'] as List? ?? [];
              for (var imageGroup in imagesList) {
                if (imageGroup is! Map<String, dynamic>) continue;
                if (imageGroup.containsKey('template')) {
                  final folderNum = imageGroup['folder'] as int? ?? 0;
                  final folderName = folderNumberToName[folderNum];
                  final List<String> allImagesInFolder = assetFolders[folderName] ?? [];
                  final imageIndexList = imageGroup['images'] as List? ?? [];
                  List<String> resolvedMediaPaths = [];
                  Map<String, int> resolvedDurations = {};
                  for (var img in imageIndexList) {
                    if (img is Map && img.isNotEmpty) {
                      final entry = img.entries.first;
                      final pos = int.tryParse(entry.key.toString()) ?? 0;
                      final duration = entry.value as int? ?? 5;
                      if (pos > 0 && pos <= allImagesInFolder.length) {
                        final imgPath = allImagesInFolder[pos - 1];
                        resolvedMediaPaths.add(imgPath);
                        resolvedDurations[imgPath] = duration;
                      }
                    }
                  }
                  slideshowReadyEvents.add({ 'template': imageGroup['template'], 'text': imageGroup['text'] ?? '', 'scrollingText': imageGroup['scrollingText'] ?? false, 'mediaPaths': resolvedMediaPaths, 'durations': resolvedDurations, 'folderNum': folderNum, });
                } else {
                  final folderNum = imageGroup['folder'] as int? ?? 0;
                  final folderName = folderNumberToName[folderNum];
                  final List<String> allImagesInFolder = assetFolders[folderName] ?? [];
                  final imageIndexList = imageGroup['images'] as List? ?? [];
                  for (var img in imageIndexList) {
                    if (img is Map && img.isNotEmpty) {
                      final entry = img.entries.first;
                      final pos = int.tryParse(entry.key.toString()) ?? 0;
                      final duration = entry.value as int? ?? 5;
                      if (pos > 0 && pos <= allImagesInFolder.length) {
                        final imgPath = allImagesInFolder[pos - 1];
                        slideshowReadyEvents.add({ 'path': imgPath, 'name': imgPath.split(Platform.pathSeparator).last, 'duration_seconds': duration, 'folderNum': folderNum, });
                      }
                    }
                  }
                }
              }
            }
          }
        }

        final sdRaw = data['safety_dashboard'];
        if (sdRaw is Map) {
          safetyDashboard = sdRaw.cast<String, dynamic>();
          safetyEnabled = (safetyDashboard['enabled'] == true);
        }
      } catch (e) {
        print("Error decoding or processing JSON: $e");
        // Handle error, maybe show an error slide or default content
      }
    }

    final finalSlideshowList = <Map<String, dynamic>>[
      ...slideshowReadyEvents,
      ..._buildSafetySlidesFor(DateTime.now(), safetyEnabled, safetyDashboard),
    ];

    print('--- Reprocessing complete. Today\'s Slideshow Data: ---');
    print(finalSlideshowList);

    if (mounted) {
      setState(() {
        _slideshowItems = finalSlideshowList;
        _showThirukural = dailyThirukural;
        _isLoading = false;
      });
    }
  }

  // --- HELPER FUNCTIONS (No changes to these) ---
  List<Map<String, dynamic>> _buildSafetySlidesFor(DateTime date, bool safetyEnabled, Map<String, dynamic>? safetyDashboard) {
    if (!safetyEnabled || safetyDashboard == null) return [];
    final ds = (safetyDashboard['date'] ?? '').toString();
    final parsed = DateTime.tryParse(ds);
    final normalizedDate = DateTime(date.year, date.month, date.day);
    if (parsed == null || DateTime(parsed.year, parsed.month, parsed.day) != normalizedDate) return [];
    return [_buildDashboardSlide(safetyDashboard)];
  }

  Map<String, dynamic> _buildDashboardSlide(Map<String, dynamic> dashboard) {
    final d = (dashboard['data'] as Map?)?.cast<String, dynamic>() ?? {};
    String v(String k) => (d[k] ?? '').toString();
    final rows = [
      {'label': 'Days Since Last Incident', 'key': 'daysSinceLastIncident'}, {'label': 'Lost Time Injuries', 'key': 'lostTimeInjuries'}, {'label': 'Total Recordable Injuries', 'key': 'totalRecordableInjuries'}, {'label': 'First Aid Cases', 'key': 'firstAidCases'}, {'label': 'Near Misses', 'key': 'nearMisses'}, {'label': 'Safety Observations', 'key': 'safetyObservations'}, {'label': 'Audits', 'key': 'audits'}, {'label': 'Toolbox Talks', 'key': 'toolboxTalks'}, {'label': 'Training Sessions', 'key': 'trainingSessions'}, {'label': 'PPE Compliance', 'key': 'ppeCompliancePct'}, {'label': 'Open Corrective Actions', 'key': 'openCorrectiveActions'},
    ];
    final cells = <Map<String, dynamic>>[
      {'text': 'Safety Dashboard', 'align': 'topCenter', 'dxPct': 0.0, 'dyPct': 0.06, 'widthPct': 0.90, 'fontSize': 38, 'weight': 'w800', 'color': '#000000', 'shadow': false,},
      {'text': 'Site: ${v('site')}', 'align': 'topCenter', 'dxPct': 0.0, 'dyPct': 0.12, 'widthPct': 0.90, 'fontSize': 22, 'weight': 'w600', 'color': '#555555', 'shadow': false,},
    ];
    const startY = 0.22;
    const stepY = 0.065;
    for (int i = 0; i < rows.length; i++) {
      final y = startY + i * stepY;
      cells.add({'text': rows[i]['label'], 'align': 'topCenter', 'dxPct': -0.22, 'dyPct': y, 'widthPct': 0.40, 'fontSize': 18, 'weight': 'w600', 'textAlign': 'right', 'color': '#222222', 'shadow': false,});
      final key = rows[i]['key']!;
      final valueText = key == 'ppeCompliancePct' ? '${v(key)}%' : v(key);
      cells.add({'text': valueText, 'align': 'topCenter', 'dxPct': 0.22, 'dyPct': y, 'widthPct': 0.22, 'fontSize': 15, 'weight': 'w800', 'textAlign': 'left', 'color': '#000000', 'shadow': false,});
    }
    return {'template': 'kural-cells', 'mediaPaths': ['assets/backgrounds/dashboard.png'], 'dim': 0.0, 'panelHeightPct': 0.0, 'folderNum': 99, 'cells': cells,};
  }

  // --- BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        key: const ValueKey<int>(2),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text('Loading Kiosk...', style: TextStyle(fontSize: 18)),
            ],
          ),
        ),
      );
    }

    return SlideshowPage(
      slidesOrImages: _slideshowItems,
      showThirukural: _showThirukural,
      thirukuralAssetPath: 'assets/data/Thirukural.xlsx',
      thirukuralBackground: 'assets/backgrounds/thirukural.png',
    );
  }

  // NEW: Dispose the timer when the widget is removed from the screen
  // to prevent memory leaks and background tasks.
  @override
  void dispose() {
    _dataCheckTimer?.cancel();
    super.dispose();
  }
}