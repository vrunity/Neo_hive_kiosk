import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'qr_scanner_page.dart';
import 'slideshow_page.dart';
import 'kiosk_server.dart'; // your server class

class CalendarKioskApp extends StatefulWidget {
  const CalendarKioskApp({super.key});
  @override
  State<CalendarKioskApp> createState() => _CalendarKioskAppState();
}

const Map<String, List<String>> assetFolders = {
  'Confined Space': [
    'assets/Confined Space/confined space entry.jpg',
  ],

  'EOT Crane': [
    'assets/EOT Crane/eot authorized person.jpg',
    'assets/EOT Crane/EOT crane - 2.jpg',
    'assets/EOT Crane/EOT crane - 3.jpg',
    'assets/EOT Crane/eot hook.jpg',
    'assets/EOT Crane/load limit.jpg',
  ],

  'First Aid': [
    'assets/First Aid/aed.jpg',
    'assets/First Aid/Be trained.jpg',
    'assets/First Aid/CPR.jpg',
    'assets/First Aid/CPR 2.jpg',
    'assets/First Aid/CPR 3.jpg',
    'assets/First Aid/eye wash station.jpg',
  ],

  'Forklift': [
    'assets/Forklift/Forklift - 01.jpg',
    'assets/Forklift/Forklift - 02.jpg',
    'assets/Forklift/Forklift - 03.jpg',
  ],

  'Hazards': [
    // Note: filename appears to have two spaces between "Chemical" and "hazard" in the screenshot.
    'assets/Hazards/Chemical  hazard.jpg',
    'assets/Hazards/Fall hazard.jpg',
  ],

  'Hight work': [
    'assets/Hight work/fall production.jpg',
    'assets/Hight work/fall production - 2.jpg',
    'assets/Hight work/ladder safety.jpg',
    'assets/Hight work/suspended load.jpg',
    'assets/Hight work/suspended load 2.jpg',
  ],

  'Hot work': [
    // Unusual name kept verbatim as in screenshot:
    'assets/Hot work/Felding. psd.jpg',
    'assets/Hot work/hot work.jpg',
    'assets/Hot work/Pass procedure.jpg',
  ],

  'Labours day': [
    'assets/Labours day/May 1.jpg',
  ],

  'Ladder safety': [
    'assets/Ladder safety/Ladder 1.jpg',
    'assets/Ladder safety/Ladder 2.jpg',
    'assets/Ladder safety/Ladder 3.jpg',
    'assets/Ladder safety/Ladder 4.jpg',
  ],

  'Material handling': [
    'assets/Material handling/award position.jpg',
    'assets/Material handling/center of gravity.jpg',
    'assets/Material handling/over load.jpg',
    // If you also have this (from your older list), keep it:
    // 'assets/Material handling/Safe lifting.jpg',
  ],

  'MSDS': [
    'assets/MSDS/Chemical handling.jpg',
    'assets/MSDS/Chemical spill.jpg',
    'assets/MSDS/Chemical spill 2.jpg',
    'assets/MSDS/lables.jpg',
    'assets/MSDS/MSDS-1.jpg',
    'assets/MSDS/Waste Disposal.jpg',
  ],

  'Near misses': [
    'assets/Near misses/accidents.jpg',
    'assets/Near misses/near miss.jpg',
    // Screenshot shows a space before .jpg — keep it exactly:
    'assets/Near misses/Prevent trips .jpg',
    'assets/Near misses/Report gas leak.jpg',
  ],

  'PPE': [
    'assets/PPE/ear.jpg',
    'assets/PPE/ear 2.jpg',
    'assets/PPE/eye protection.jpg',
    'assets/PPE/face mask.jpg',
    'assets/PPE/Face sheild.jpg',
    'assets/PPE/gloves.jpg',
    'assets/PPE/gloves - 2.jpg',
    'assets/PPE/head production.jpg',
    'assets/PPE/helmet.jpg',
    'assets/PPE/helmet safety.jpg',
    'assets/PPE/helmet 2.jpg',
    'assets/PPE/helmet 3.jpg',
    'assets/PPE/helmet 4.jpg',
    'assets/PPE/mask.jpg',
    'assets/PPE/ppe.jpg',
    'assets/PPE/shoe.jpg',
  ],

  'Scaffolding': [
    'assets/Scaffolding/scaffolding.jpg',
    'assets/Scaffolding/scaffolding - 2.jpg',
    'assets/Scaffolding/scaffolding 3.jpg',
  ],

  'Unsafe act': [
    'assets/Unsafe act/prevent accident.jpg',
    'assets/Unsafe act/unsafe act.jpg',
    'assets/Unsafe act/unsafe act - 2.jpg',
  ],

  'Women safety': [
    'assets/Women safety/women 2.jpg',
    'assets/Women safety/Womens day.jpg',
    'assets/Women safety/Womens day 2.jpg',
    'assets/Women safety/Womens day 3.jpg',
  ],
};


const Map<int, String> folderNumberToName = {
  1:  'Confined Space',
  2:  'EOT Crane',
  3:  'First Aid',
  4:  'Forklift',
  5:  'Hazards',
  6:  'Hight work',
  7:  'Hot work',
  8:  'Labours day',
  9:  'Ladder safety',
  10: 'Material handling',
  11: 'MSDS',
  12: 'Near misses',
  13: 'Others',
  14: 'PPE',
  15: 'Scaffolding',
  16: 'Unsafe act',
  17: 'Women safety',
};

const Map<String, int> folderNameToNumber = {
  'Confined Space': 1,
  'EOT Crane': 2,
  'First Aid': 3,
  'Forklift': 4,
  'Hazards': 5,
  'Hight work': 6,
  'Hot work': 7,
  'Labours day': 8,
  'Ladder safety': 9,
  'Material handling': 10,
  'MSDS': 11,
  'Near misses': 12,
  'Others': 13,
  'PPE': 14,
  'Scaffolding': 15,
  'Unsafe act': 16,
  'Women safety': 17,
};


const Map<int, String> templateIdToString = {
  1: '70image30text',
  2: '70image30scrolltext',
  3: 'image-image',
  4: 'video-image',
};

class _CalendarKioskAppState extends State<CalendarKioskApp> {
  Timer? _debugTimer; // For debug print
  Timer? _reloadTimer;
  Timer? _onlineFetchTimer;

  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> events = {};
  String? kioskIp;
  late KioskServer kioskServer;
  bool _dailyThirukural = false; // persisted flag


  bool isOnline = false; // <-- online/offline mode flag

  // Safety dashboard state
  Map<String, dynamic>? _safetyDashboard;
  bool _safetyEnabled = false;

  void _logSafetyDashboard([String tag = '']) {
    print('SAFETY[$tag] enabled=${_safetyEnabled} raw=${_safetyDashboard}');
    if (_safetyDashboard == null) return;

    final dateStr = (_safetyDashboard!['date'] ?? '').toString();
    final data = (_safetyDashboard!['data'] as Map?)?.cast<String, dynamic>() ?? {};
    print('SAFETY[$tag] date=$dateStr');

    for (final e in data.entries) {
      print('SAFETY[$tag] ${e.key}: ${e.value}');
    }
  }

// Reuse an existing background image (already in your project)
  String get _safetyBgAsset => 'assets/backgrounds/thirukural.png';

// Build Safety slides for a given date (one scrolling text slide per line)

  List<Map<String, dynamic>> _buildSafetySlidesFor(DateTime date) {
    if (!_safetyEnabled || _safetyDashboard == null) return [];

    final ds = (_safetyDashboard!['date'] ?? '').toString();
    final parsed = DateTime.tryParse(ds);
    if (parsed == null || normalizeDate(parsed) != normalizeDate(date)) {
      return [];
    }

    // Build a single “dashboard” slide that uses dashboard.png
    return [_buildDashboardSlide(_safetyDashboard!)];
  }
  Widget _buildThirukuralToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Daily Thirukural: '),
        Switch(
          value: _dailyThirukural,
          onChanged: (val) async {
            setState(() => _dailyThirukural = val);
            final prefs = await SharedPreferences.getInstance();
            final raw = prefs.getString('calendar_events');
            Map<String, dynamic> current = {};
            if (raw != null) {
              try { current = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
            }
            current['daily_thirukural'] = _dailyThirukural;
            await prefs.setString('calendar_events', jsonEncode(current));
          },
        ),
        Text(_dailyThirukural ? 'On' : 'Off'),
      ],
    );
  }


  int _safetySlidesCountFor(DateTime date) {
    return _buildSafetySlidesFor(normalizeDate(date)).length;
  }

  String _safetyStatusTextFor(DateTime date) {
    if (!_safetyEnabled || _safetyDashboard == null) return 'Disabled';
    final ds = (_safetyDashboard!['date'] ?? '').toString();
    final parsed = DateTime.tryParse(ds);
    if (parsed == null) return 'Enabled (no valid date)';
    final same = normalizeDate(parsed) == normalizeDate(date);
    final n = _safetySlidesCountFor(date);
    return same ? 'Enabled for ${ds} • $n line(s)' : 'Enabled for ${ds} • 0 line(s) today';
  }
  Map<String, dynamic> _buildDashboardSlide(Map<String, dynamic> dashboard) {
    final d = (dashboard['data'] as Map?)?.cast<String, dynamic>() ?? {};
    String v(String k) => (d[k] ?? '').toString();

    // rows: label text + key in your data
    final rows = [
      {'label': 'Days Since Last Incident', 'key': 'daysSinceLastIncident'},
      {'label': 'Lost Time Injuries',       'key': 'lostTimeInjuries'},
      {'label': 'Total Recordable Injuries','key': 'totalRecordableInjuries'},
      {'label': 'First Aid Cases',          'key': 'firstAidCases'},
      {'label': 'Near Misses',              'key': 'nearMisses'},
      {'label': 'Safety Observations',      'key': 'safetyObservations'},
      {'label': 'Audits',                   'key': 'audits'},
      {'label': 'Toolbox Talks',            'key': 'toolboxTalks'},
      {'label': 'Training Sessions',        'key': 'trainingSessions'},
      {'label': 'PPE Compliance',           'key': 'ppeCompliancePct'},
      {'label': 'Open Corrective Actions',  'key': 'openCorrectiveActions'},
    ];

    final cells = <Map<String, dynamic>>[
      // Title + site (both centered)
      {
        'text': 'Safety Dashboard',
        'align': 'topCenter',
        'dxPct': 0.0, 'dyPct': 0.06,
        'widthPct': 0.90,
        'fontSize': 38, 'weight': 'w800',
        'color': '#000000', 'shadow': false,
      },
      {
        'text': 'Site: ${v('site')}',
        'align': 'topCenter',
        'dxPct': 0.0, 'dyPct': 0.12,
        'widthPct': 0.90,
        'fontSize': 22, 'weight': 'w600',
        'color': '#555555', 'shadow': false,
      },
    ];

    // Centered two-column layout:
    // left column: dxPct = -0.22 (22% left of center), right-aligned labels
    // right column: dxPct =  +0.22 (22% right of center), left-aligned values
    const startY = 0.22;   // first row vertical position (22% from top)
    const stepY  = 0.065;  // spacing between rows (~6.5% of height)
    for (int i = 0; i < rows.length; i++) {
      final y = startY + i * stepY;

      // LABEL (left column)
      cells.add({
        'text': rows[i]['label'],
        'align': 'topCenter',
        'dxPct': -0.22, 'dyPct': y,
        'widthPct': 0.40,
        'fontSize': 18, 'weight': 'w600',
        'textAlign': 'right',
        'color': '#222222', 'shadow': false,
      });

      // VALUE (right column)
      final key = rows[i]['key']!;
      final valueText = key == 'ppeCompliancePct' ? '${v(key)}%' : v(key);
      cells.add({
        'text': valueText,
        'align': 'topCenter',
        'dxPct': 0.22, 'dyPct': y,
        'widthPct': 0.22,
        'fontSize': 15, 'weight': 'w800',
        'textAlign': 'left',
        'color': '#000000', 'shadow': false,
      });
    }

    // Notes at bottom, wide block
    // cells.add({
    //   'text': 'Notes: ${v('notes')}',
    //   'align': 'bottomCenter',
    //   'dxPct': 0.0, 'dyPct': -0.10,     // 10% up from bottom
    //   'widthPct': 0.90,
    //   'fontSize': 16, 'weight': 'w600',
    //   'textAlign': 'left',
    //   'color': '#222222', 'shadow': false,
    //   'maxLines': 3,
    // });

    return {
      'template': 'kural-cells',
      'mediaPaths': ['assets/backgrounds/dashboard.png'],
      'dim': 0.0,
      'panelHeightPct': 0.0,
      'folderNum': 99,
      'cells': cells,
    };
  }

  Widget _safetyStatusRow() {
    final ds = (_safetyDashboard?['date'] ?? '').toString();
    final parsed = DateTime.tryParse(ds);
    final selected = normalizeDate(_focusedDay);
    final matches = parsed != null && normalizeDate(parsed) == selected;
    final lines = _buildSafetySlidesFor(selected).length;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        children: [
          Chip(
            label: Text(_safetyEnabled ? 'Safety: ON' : 'Safety: OFF'),
            backgroundColor: _safetyEnabled ? Colors.green.shade200 : Colors.grey.shade300,
          ),
          Chip(label: Text(ds.isEmpty ? 'Date: —' : 'Date: $ds')),
          Chip(label: Text(matches ? 'Applies to selected day ($lines line(s))' : 'No slides for selected day')),
        ],
      ),
    );
  }


  @override
  void initState() {
    super.initState();
    _fetchLocalIp();

    kioskServer = KioskServer(onNewData: (newData) {
      _handleNewData(newData);
    });

    _startServer();

    _loadEvents();

    _debugTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final prefs = await SharedPreferences.getInstance();
      final savedData = prefs.getString('calendar_events');
      bool? dbgFlag;
      try {
        final m = savedData != null ? jsonDecode(savedData) as Map<String, dynamic> : null;
        if (m != null && m['daily_thirukural'] is bool) dbgFlag = m['daily_thirukural'] as bool;
      } catch (_) {}
      print('SharedPreferences calendar_events data: $savedData  |  daily_thirukural=$dbgFlag');
    });

    _reloadTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isOnline) {
        _loadEventsFromStorage();
      }
    });

    if (isOnline) {
      _startOnlineFetchTimer();
    }
  }

  Future<void> _startServer() async {
    try {
      await kioskServer.start();
    } catch (e) {
      print('Failed to start server: $e');
    }
  }

  Future<void> _fetchLocalIp() async {
    final info = NetworkInfo();
    final ip = await info.getWifiIP();
    setState(() {
      kioskIp = ip;
    });
  }

  Future<List<String>> listOthersFolderFiles() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final othersDir = Directory('${appDocDir.path}/Others');
    if (!await othersDir.exists()) return [];
    final files = await othersDir
        .list()
        .where((entity) => entity is File)
        .map((file) => file.path)
        .toList();
    return files;
  }

  Future<Map<String, dynamic>> _convertImagesToTemplateData(
      List<dynamic> images, int folderNum, bool isOnline) async {
    String? folderName = folderNumberToName[folderNum];

    List<String> allImages =
    folderNum == 13 ? await listOthersFolderFiles() : (assetFolders[folderName] ?? []);

    List<String> mediaPaths = [];
    Map<String, int> durations = {};

    for (var img in images) {
      if (img is Map && img.isNotEmpty) {
        var entry = img.entries.first;
        int pos;
        if (entry.key is int) {
          pos = entry.key as int;
        } else if (entry.key is String) {
          pos = int.tryParse(entry.key) ?? 0;
        } else {
          pos = 0;
        }
        int duration = entry.value ?? 5;

        if (isOnline) {
          // Use URL format for online mode
          // Construct URL based on folderName and image name at pos-1
          if (pos > 0 && pos <= allImages.length) {
            final imageName = allImages[pos - 1].split('/').last;
            final url = 'https://esheapp.in/kiosk/Images/${Uri.encodeComponent(folderName ?? '')}/${Uri.encodeComponent(imageName)}';
            mediaPaths.add(url);
            durations[url] = duration;
          }
        } else {
          // Offline mode: use local assets or local file paths
          String imgPath = (pos > 0 && pos <= allImages.length) ? allImages[pos - 1] : '';
          if (imgPath.isEmpty) continue;

          mediaPaths.add(imgPath);
          durations[imgPath] = duration;
        }
      }
    }
    return {'mediaPaths': mediaPaths, 'durations': durations};
  }


  Future<void> _loadEvents() async {
    if (isOnline) {
      await _fetchRemoteEvents();
    } else {
      await _loadEventsFromStorage();
    }
  }

  /// New helper to normalize incoming events data in any of the 3 accepted formats
  List<dynamic> _normalizeEvents(dynamic rawEvents) {
    if (rawEvents is List) {
      // Format 1 or 2: events is a list
      return rawEvents;
    } else if (rawEvents is Map<String, dynamic>) {
      // Format 3: events is a map of dateStr -> List of events
      List<dynamic> flattened = [];
      rawEvents.forEach((dateStr, eventsList) {
        if (eventsList is List) {
          flattened.addAll(eventsList);
        }
      });
      return flattened;
    } else {
      // Unknown format
      return [];
    }
  }

  Future<void> _loadEventsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('calendar_events');

    if (raw != null) {
      print('Loading events from storage: $raw');
      final Map<String, dynamic> data = jsonDecode(raw);

      // Load Daily Thirukural flag (default false if missing)
      final bool storedFlag = (data['daily_thirukural'] is bool)
          ? data['daily_thirukural'] as bool
          : _dailyThirukural; // preserve current state if missing


      dynamic rawEvents = data['events'];

// initialize upfront so it's always defined (empty by default)
      Map<DateTime, List<Map<String, dynamic>>> loadedEvents = {};

      if (rawEvents == null) {
        print("No 'events' key found.");
        final sdRaw = data['safety_dashboard'];
        Map<String, dynamic>? sd;
        bool sdEnabled = false;
        if (sdRaw is Map) {
          sd = sdRaw.cast<String, dynamic>();
          sdEnabled = (sd['enabled'] == true);
          print('SAFETY[storage] loaded enabled=$sdEnabled payload=$sd');
        }
        print('READ safety_dashboard from SharedPreferences? ${sdRaw is Map} enabled=$_safetyEnabled date=${_safetyDashboard?['date']}');
        setState(() {
          events = loadedEvents; // empty map
          _dailyThirukural = storedFlag;
          _safetyDashboard = sd;
          _safetyEnabled = sdEnabled;
        });
        return;
      }

      List<dynamic> eventsList = _normalizeEvents(rawEvents);

      DateTime parseAndNormalizeDate(String dateStr) {
        try {
          final parsed = DateTime.parse(dateStr);
          return DateTime(parsed.year, parsed.month, parsed.day);
        } catch (_) {
          return DateTime.now();
        }
      }

      // Group events by date string
      Map<String, List<dynamic>> groupedByDate = {};
      for (var event in eventsList) {
        final dateStr = event['date'] ?? '';
        if (dateStr.isEmpty) continue;
        groupedByDate.putIfAbsent(dateStr, () => []);
        groupedByDate[dateStr]!.add(event);
      }

      for (var entry in groupedByDate.entries) {
        final dateStr = entry.key;
        final eventGroup = entry.value;

        final normalizedDate = parseAndNormalizeDate(dateStr);

        List<Map<String, dynamic>> mergedImages = [];

        // Process each event's images
        for (var eventEntry in eventGroup) {
          List imagesList = eventEntry['images'] ?? [];

          for (var imageGroup in imagesList) {
            int? folderNum;
            final folderRaw = imageGroup['folder'];
            if (folderRaw is int) {
              folderNum = folderRaw;
            } else if (folderRaw is String) {
              folderNum = int.tryParse(folderRaw);
            }
            if (folderNum == null) continue;

            bool isTemplate = imageGroup.containsKey('template') || imageGroup.containsKey('mediaPaths');

            if (isTemplate) {
              // Offline mode: convert index-duration map images to mediaPaths & durations
              List<dynamic> imgs = imageGroup['images'] ?? [];
              final converted = await _convertImagesToTemplateData(imgs, folderNum, isOnline);

              if (converted['mediaPaths'] != null && (converted['mediaPaths'] as List).isNotEmpty) {
                mergedImages.add({
                  'template': imageGroup['template'] ?? '',
                  'mediaPaths': converted['mediaPaths'],
                  'durations': converted['durations'],
                  'text': imageGroup['text'] ?? '',
                  'scrollingText': imageGroup['scrollingText'] ?? false,
                  'folderNum': folderNum,
                });
              }
            } else {
              // Handle local format with images as {index: duration}
              List<dynamic> imgs = imageGroup['images'] ?? [];

              // Get all images for folder
              String? folderName = folderNumberToName[folderNum];
              List<String> allImages = [];

              if (folderNum == 13) {
                // Others folder - read files from disk
                allImages = await listOthersFolderFiles();
              } else if (folderName != null) {
                allImages = assetFolders[folderName] ?? [];
              }

              for (var img in imgs) {
                if (img is Map && img.isNotEmpty) {
                  var entry = img.entries.first;
                  int pos = 0;
                  if (entry.key is int) {
                    pos = entry.key as int;
                  } else if (entry.key is String) {
                    pos = int.tryParse(entry.key) ?? 0;
                  }
                  int duration = entry.value ?? 5;
                  String imgPath = (pos > 0 && pos <= allImages.length) ? allImages[pos - 1] : '';
                  if (imgPath.isEmpty) continue;

                  mergedImages.add({
                    'path': imgPath,
                    'name': imgPath.split(Platform.pathSeparator).last,
                    'duration_seconds': duration,
                    'folderNum': folderNum,
                  });
                }
              }
            }
          }
        }

        loadedEvents[normalizedDate] = mergedImages;
      }
      final sdRaw = data['safety_dashboard'];
      Map<String, dynamic>? sd;
      bool sdEnabled = false;
      if (sdRaw is Map) {
        sd = sdRaw.cast<String, dynamic>();
        sdEnabled = (sd['enabled'] == true);
      }
      print('Events loaded from storage, keys: ${loadedEvents.keys.map((d) => d.toIso8601String())}');
      setState(() {
        events = loadedEvents;
        _dailyThirukural = storedFlag;
        _safetyDashboard = sd;
        _safetyEnabled = sdEnabled;
      });

    } else {
      print('No saved events found in storage.');
      setState(() {
        events = {};
        _dailyThirukural = false;
      });
    }
  }

  Map<String, dynamic> convertOnlineToAppFormat(Map<String, dynamic> onlineData) {
    dynamic rawEvents = onlineData['events'];
    List<dynamic> rawEventsList = _normalizeEvents(rawEvents);

    List<Map<String, dynamic>> eventsList = [];

    // Group by date, merge images groups like above
    Map<String, List<dynamic>> groupedByDate = {};
    for (var event in rawEventsList) {
      final dateStr = event['date'] ?? '';
      if (dateStr.isEmpty) continue;
      groupedByDate.putIfAbsent(dateStr, () => []);
      groupedByDate[dateStr]!.add(event);
    }

    for (var entry in groupedByDate.entries) {
      final dateStr = entry.key;
      final eventGroup = entry.value;

      Map<int, List<Map<String, int>>> folderImagesMap = {};
      Map<int, Map<String, dynamic>> folderTemplatesMap = {};

      for (var event in eventGroup) {
        List imagesList = event['images'] ?? [];

        for (var imageObj in imagesList) {
          String folderName = imageObj['folder']?.toString() ?? '';
          List<dynamic> imgs = imageObj['images'] ?? [];

          int? folderNum = folderNameToNumber[folderName] ?? int.tryParse(folderName);

          if (folderNum == null) continue;

          folderImagesMap.putIfAbsent(folderNum, () => []);

          if (imageObj.containsKey('template') || imageObj.containsKey('text')) {
            folderTemplatesMap[folderNum] = {
              'template': imageObj['template'] ?? '',
              'text': imageObj['text'] ?? '',
              'scrollingText': imageObj['scrollingText'] ?? false,
            };
          }

          for (var img in imgs) {
            if (img is Map<String, dynamic>) {
              img.forEach((key, value) {
                folderImagesMap[folderNum]!.add({key: value});
              });
            }
          }
        }
      }

      List<Map<String, dynamic>> imagesGrouped = [];
      folderImagesMap.forEach((folderNum, images) {
        final templateInfo = folderTemplatesMap[folderNum];
        if (templateInfo != null) {
          imagesGrouped.add({
            'folder': folderNum,
            'images': images,
            'template': templateInfo['template'],
            'text': templateInfo['text'],
            'scrollingText': templateInfo['scrollingText'],
          });
        } else {
          imagesGrouped.add({
            'folder': folderNum,
            'images': images,
          });
        }
      });

      eventsList.add({
        'date': dateStr,
        'days_duration': eventGroup.first['days_duration'] ?? 1,
        'images': imagesGrouped,
      });
    }

    return {
      'events': eventsList,
      'daily_thirukural': (onlineData['daily_thirukural'] is bool)
          ? onlineData['daily_thirukural']
          : _dailyThirukural, // keep current if not provided
    };
  }

  Future<void> _fetchRemoteEvents() async {
    print('*** _fetchRemoteEvents called ***');
    print('Current mode is: Online');
    try {
      // Step 1: Fetch raw JSON events from server (events.json)
      final uri = Uri.parse('https://esheapp.in/kiosk/events.json');
      final httpClient = HttpClient();
      final request = await httpClient.getUrl(uri);
      final response = await request.close();

      if (response.statusCode != 200) {
        final responseBody = await response.transform(utf8.decoder).join();
        print('Error response (${response.statusCode}): $responseBody');
        throw Exception('Failed to load remote events: ${response.statusCode}');
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final rawEventsJson = jsonDecode(responseBody);

      print('Raw events JSON fetched: $rawEventsJson');

      // Step 2: Send raw JSON to fetch_images.php to get full image URLs
      final phpUri = Uri.parse('https://esheapp.in/kiosk/fetch_images.php');
      final phpRequestClient = HttpClient();

      final phpRequest = await phpRequestClient.postUrl(phpUri);

      // Send raw JSON as POST body, encoded as JSON string
      phpRequest.headers.set('Content-Type', 'application/json');
      phpRequest.write(jsonEncode(rawEventsJson));

      final phpResponse = await phpRequest.close();

      if (phpResponse.statusCode != 200) {
        final phpRespBody = await phpResponse.transform(utf8.decoder).join();
        print('PHP Error response (${phpResponse.statusCode}): $phpRespBody');
        throw Exception('Failed to fetch images from PHP: ${phpResponse.statusCode}');
      }

      final phpRespBody = await phpResponse.transform(utf8.decoder).join();
      final processedJson = jsonDecode(phpRespBody);

      print('Processed JSON from PHP: $processedJson');

      // Step 3: Use the processed JSON (with full URLs) to populate events map
      // Assuming processedJson is of the format {'events': [...]}
      List<dynamic> rawEvents = processedJson['events'] ?? [];
      if (rawEvents is! List) {
        print('Invalid processed events format from PHP');
        return;
      }

      DateTime normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);
      Map<DateTime, List<Map<String, dynamic>>> groupedEvents = {};

      for (var event in rawEvents) {
        if (event is! Map<String, dynamic>) continue;

        final dateStr = event['date'] ?? '';
        if (dateStr.isEmpty) continue;

        final int daysDuration = (event['days_duration'] is int && event['days_duration'] > 0)
            ? event['days_duration']
            : 1;

        DateTime startDate = DateTime.tryParse(dateStr) ?? DateTime.now();

        for (int i = 0; i < daysDuration; i++) {
          final dateToUse = normalizeDate(startDate.add(Duration(days: i)));

          List<Map<String, dynamic>> slideshowItems = [];

          List imagesGroups = event['images'] ?? [];

          for (var imageGroup in imagesGroups) {
            int? folderNum;
            final folderRaw = imageGroup['folder'];
            if (folderRaw is int) {
              folderNum = folderRaw;
            } else if (folderRaw is String) {
              folderNum = int.tryParse(folderRaw);
            }
            if (folderNum == null) continue;

            List<dynamic> imgs = imageGroup['images'] ?? [];

            bool isTemplate = imageGroup.containsKey('template') || imageGroup.containsKey('text');

            if (isTemplate) {
              List<String> mediaPaths = [];
              Map<String, int> durations = {};

              for (var img in imgs) {
                if (img is Map && img.isNotEmpty) {
                  // Always use 'url' field for the media path
                  String onlinePath = img['url'] ?? '';

                  // Duration from the first non-url entry value
                  int duration = img.values.firstWhere(
                        (v) => v is int,
                    orElse: () => 5,
                  ) as int;

                  if (onlinePath.isNotEmpty) {
                    mediaPaths.add(onlinePath);
                    durations[onlinePath] = duration;
                  }
                }
              }

              if (mediaPaths.isNotEmpty) {
                slideshowItems.add({
                  'template': imageGroup['template'] ?? '',
                  'mediaPaths': mediaPaths,
                  'durations': durations,
                  'text': imageGroup['text'] ?? '',
                  'scrollingText': imageGroup['scrollingText'] ?? false,
                  'folderNum': folderNum,
                });
              }
            } else {
              for (var img in imgs) {
                if (img is Map && img.isNotEmpty) {
                  String onlinePath = img['url'] ?? '';

                  int duration = img.values.firstWhere(
                        (v) => v is int,
                    orElse: () => 5,
                  ) as int;

                  if (onlinePath.isNotEmpty) {
                    slideshowItems.add({
                      'path': onlinePath,
                      'name': 'Image',
                      'duration_seconds': duration,
                      'folderNum': folderNum,
                    });
                  }
                }
              }
            }
          }

          groupedEvents.update(dateToUse, (existing) {
            existing.addAll(slideshowItems);
            return existing;
          }, ifAbsent: () => slideshowItems);
        }
      }

      print('Loaded remote events keys: ${groupedEvents.keys.map((e) => e.toIso8601String())}');

      setState(() {
        events = groupedEvents;
      });

      final prefs = await SharedPreferences.getInstance();
      final eventsListToSave = groupedEvents.entries.map((entry) {
        return {
          'date': entry.key.toIso8601String().split('T').first,
          'images': entry.value,
        };
      }).toList();

// --- daily_thirukural flag (preserve previous if server omits) ---
      bool existingFlag = _dailyThirukural;
      final prevRaw = prefs.getString('calendar_events');
      Map<String, dynamic>? prevMap;
      if (prevRaw != null) {
        try {
          prevMap = jsonDecode(prevRaw) as Map<String, dynamic>;
          if (prevMap['daily_thirukural'] is bool) {
            existingFlag = prevMap['daily_thirukural'] as bool;
          }
        } catch (_) {}
      }
      final remoteFlag = (processedJson['daily_thirukural'] is bool)
          ? processedJson['daily_thirukural'] as bool
          : existingFlag;

// --- safety_dashboard (use server if present, else keep previous) ---
      Map<String, dynamic>? prevSafety;
      if (prevMap != null && prevMap['safety_dashboard'] is Map) {
        prevSafety = (prevMap['safety_dashboard'] as Map).cast<String, dynamic>();
      }
      Map<String, dynamic>? remoteSafety;
      if (processedJson['safety_dashboard'] is Map) {
        remoteSafety = (processedJson['safety_dashboard'] as Map).cast<String, dynamic>();
      }
      final safetyToSave = remoteSafety ?? prevSafety;
      print('SAFETY[remote] received=${remoteSafety != null} saved=${safetyToSave != null} payload=$safetyToSave');

      final jsonToSave = jsonEncode({
        'events': eventsListToSave,
        'daily_thirukural': remoteFlag,
        if (safetyToSave != null) 'safety_dashboard': safetyToSave,
      });
      await prefs.setString('calendar_events', jsonToSave);

      setState(() {
        _dailyThirukural = remoteFlag;
        _safetyDashboard = safetyToSave;
        _safetyEnabled = (safetyToSave?['enabled'] == true);
      });

      print('Saved remote events to storage');
      _logSafetyDashboard('remote');

    } catch (e) {
      print('Error fetching remote events: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load remote events: $e')),
      );
    }

  }

  Future<void> _saveEventsToStorage() async {
    final prefs = await SharedPreferences.getInstance();

    final eventsListToSave = events.entries.map((entry) {
      return {
        'date': entry.key.toIso8601String().split('T').first,
        'images': entry.value,
      };
    }).toList();

    final mapToSave = <String, dynamic>{
      'events': eventsListToSave,
      'daily_thirukural': _dailyThirukural,
    };
    if (_safetyDashboard != null) mapToSave['safety_dashboard'] = _safetyDashboard;

    final jsonStr = jsonEncode(mapToSave);
    print('Saving events to storage: $jsonStr');
    await prefs.setString('calendar_events', jsonStr);
  }

  @override
  void dispose() {
    kioskServer.stop();
    _debugTimer?.cancel();
    _reloadTimer?.cancel();
    _onlineFetchTimer?.cancel();
    super.dispose();
  }

  void _startOnlineFetchTimer() {
    _onlineFetchTimer?.cancel();
    _onlineFetchTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _fetchRemoteEvents();
    });
  }

  Widget _buildModeToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('Mode: '),
        Switch(
          value: isOnline,
          onChanged: (val) async {
            setState(() {
              isOnline = val;
            });

            if (isOnline) {
              _startOnlineFetchTimer();
              _reloadTimer?.cancel();
            } else {
              _onlineFetchTimer?.cancel();
              _reloadTimer = Timer.periodic(const Duration(seconds: 5), (_) {
                _loadEventsFromStorage();
              });
            }

            await _loadEvents();
          },
        ),
        Text(isOnline ? 'Online' : 'Offline'),
      ],
    );
  }

  DateTime normalizeDate(DateTime date) =>
      DateTime(date.year, date.month, date.day);
  Widget buildImageWidget(String path, int folderNum) {
    if (folderNum == 13) {
      return Image.file(
        File(path),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.broken_image, size: 56),
      );
    } else if (path.startsWith('http://') || path.startsWith('https://')) {
      return Image.network(
        path,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.broken_image, size: 56),
      );
    } else {
      return Image.asset(
        path,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
        const Icon(Icons.broken_image, size: 56),
      );
    }
  }
  Widget buildMediaPreview(String path, int folderNum) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv'];
    bool isVideo = videoExtensions.any((ext) => path.toLowerCase().endsWith(ext));

    if (isVideo) {
      // For videos, use FutureBuilder with _buildThumbnail()
      return FutureBuilder<Widget>(
        future: _buildThumbnail(path, folderNum),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
            return SizedBox(width: 56, height: 56, child: snapshot.data);
          } else {
            return const SizedBox(
              width: 56,
              height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
        },
      );
    } else {
      // For images, decide based on folderNum and URL
      if (folderNum == 13) {
        return Image.file(
          File(path),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 56),
        );
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(
          path,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading network image: $path, error: $error');
            return const Icon(Icons.broken_image, size: 56);
          },
        );
      } else {
        return Image.asset(
          path,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('Error loading asset image: $path, error: $error');
            return const Icon(Icons.broken_image, size: 56);
          },
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kiosk Calendar")),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                _buildModeToggle(),
                _buildThirukuralToggle(),
                _safetyStatusRow(), // <--- add this line
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) => isSameDay(day, _focusedDay),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _focusedDay = selectedDay;
                    });
                    final normalizedDate = normalizeDate(selectedDay);
                    final dayEvents = events[normalizedDate] ?? [];
                    print('Current mode is: ${isOnline ? 'Online' : 'Offline'}');
                    print('Events for selected date ($normalizedDate):');
                    final safetySlides = _buildSafetySlidesFor(normalizeDate(selectedDay));
                    print('SAFETY[ui] slides for ${normalizeDate(selectedDay)}: ${safetySlides.length}');
                    for (final s in safetySlides) {
                      print('SAFETY[ui] ${s['template']} text="${s['text']}"');
                    }

                    if (dayEvents.isEmpty) {
                      print('  No events found.');
                    } else {
                      for (var event in dayEvents) {
                        if (event.containsKey('template')) {
                          print('  Template event: ${event['template']}');
                          final mediaPaths = (event['mediaPaths'] as List<dynamic>?)?.cast<String>() ?? [];
                          for (var mp in mediaPaths) {
                            print('    Media path: $mp');
                          }
                        } else if (event.containsKey('path')) {
                          final path = event['path'] ?? '';
                          final name = event['name'] ?? '';
                          print('  Media event: $name, Path: $path');
                        } else {
                          print('  Unknown event format: $event');
                        }
                      }
                    }
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  eventLoader: (day) {
                    final normalized = normalizeDate(day);
                    final dayEvents = events[normalized] ?? [];
                    // print('eventLoader called for $normalized, found ${dayEvents.length} events.');

                    return dayEvents;
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) => const SizedBox.shrink(),
                    defaultBuilder: (context, day, focusedDay) {
                      final nd = normalizeDate(day);
                      final hasEventOrSafety =
                          (this.events[nd]?.isNotEmpty ?? false) || _buildSafetySlidesFor(nd).isNotEmpty;

                      if (hasEventOrSafety) {
                        return Container(
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.4), shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: Text('${day.day}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                        );
                      }
                      return null;
                    },
                    todayBuilder: (context, day, focusedDay) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      );
                    },
                    selectedBuilder: (context, day, focusedDay) {
                      return Container(
                        decoration: const BoxDecoration(
                          color: Colors.deepOrange,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${day.day}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
                if (kioskIp != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Kiosk IP Address: $kioskIp',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 16),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.6,
                  ),
                  child: Column(
                    children: [
                      Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ElevatedButton.icon(
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text("Upload Data"),
                                onPressed: () async {
                                  final result = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) => const QrScannerPage()),
                                  );
                                  if (result != null && mounted) {
                                    try {
                                      final qrJson = result is String
                                          ? jsonDecode(result)
                                          : result;
                                      _addEventsFromQr(qrJson);
                                      await _saveEventsToStorage();
                                    } catch (e) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Invalid QR Data')));
                                    }
                                  }
                                },
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.slideshow),
                                label: const Text("Move to Kiosk"),
                                onPressed: () {
                                  final today = DateTime.now();
                                  final todayKey = DateTime(today.year, today.month, today.day);
                                  final todayEvents = <Map<String, dynamic>>[
                                    ...(events[todayKey] ?? []),
                                    ..._buildSafetySlidesFor(todayKey),
                                  ];
                                  print('SAFETY[kiosk] adding safety slides count=${_buildSafetySlidesFor(todayKey).length}');
                                  _logSafetyDashboard('kiosk');
                                  print('Moving to kiosk slideshow with ${todayEvents.length} events.');
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => SlideshowPage(
                                        slidesOrImages: todayEvents,
                                        showThirukural: _dailyThirukural,
                                        thirukuralAssetPath: 'assets/data/Thirukural.xlsx',
                                        thirukuralBackground: 'assets/backgrounds/thirukural.png',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.red, size: 32),
                                tooltip: 'Clear Day',
                                onPressed: () async {
                                  final dateKey = normalizeDate(_focusedDay);
                                  if ((events[dateKey]?.isEmpty ?? true)) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                          Text('No images to clear on this date.')),
                                    );
                                    return;
                                  }
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Clear Images?'),
                                      content: const Text(
                                          'Are you sure you want to clear all images for this date?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Clear')),
                                      ],
                                    ),
                                  );
                                  if (confirmed == true) {
                                    setState(() {
                                      events.remove(dateKey);
                                    });
                                    await _saveEventsToStorage();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                          Text('Images cleared for this date.')),
                                    );
                                  }
                                },
                              ),
                              const SizedBox(width: 10),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.delete_forever,
                                    color: Colors.red),
                                label: const Text("Clear Others Folder"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade300,
                                ),
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Clear Others Folder?'),
                                      content: const Text(
                                          'Are you sure you want to delete all files in the Others folder? This action cannot be undone.'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('Cancel')),
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('Delete')),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await clearOthersFolder();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content:
                                          Text('All files deleted from Others folder')),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildEventList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<Widget> _buildThumbnail(String path, int folderNum) async {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv'];
    bool isVideo = videoExtensions.any((ext) => path.toLowerCase().endsWith(ext));

    if (isVideo) {
      try {
        final Uint8List? thumbData = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 75,
        );
        if (thumbData != null) {
          return Image.memory(thumbData, fit: BoxFit.cover);
        } else {
          return const Icon(Icons.videocam_off, size: 56);
        }
      } catch (e) {
        print("Failed to generate thumbnail: $e");
        return const Icon(Icons.videocam_off, size: 56);
      }
    } else {
      if (folderNum == 13) {
        return Image.file(
          File(path),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image, size: 56),
        );
      } else {
        return Image.asset(
          path,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
          const Icon(Icons.broken_image, size: 56),
        );
      }
    }
  }

  Widget _buildEventList() {
    final normalizedDate = normalizeDate(_focusedDay);
    final dayEvents = events[normalizedDate] ?? [];
    final safetySlides = _buildSafetySlidesFor(normalizedDate);

    final displayItems = <Map<String, dynamic>>[
      ...dayEvents,
      ...safetySlides, // <- include safety slides!
    ];

    print('Building event list for $normalizedDate | events=${dayEvents.length} safety=${safetySlides.length} | total=${displayItems.length}');

    if (displayItems.isEmpty) {
      return const Center(child: Text('No events or safety slides for selected date.'));
    }

    Widget buildMediaPreview(String path, [int folderNum = 0]) {
      final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv'];
      final isVideo = videoExtensions.any((ext) => path.toLowerCase().endsWith(ext));
      if (isVideo) {
        return FutureBuilder<Widget>(
          future: _buildThumbnail(path, folderNum),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done && snapshot.hasData) {
              return SizedBox(width: 56, height: 56, child: snapshot.data);
            }
            return const SizedBox(
              width: 56, height: 56,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        );
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        return Image.network(path, width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 56));
      } else if (folderNum == 13) {
        return Image.file(File(path), width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 56));
      } else {
        return Image.asset(path, width: 56, height: 56, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 56));
      }
    }

    return ListView.builder(
      itemCount: displayItems.length,
      itemBuilder: (context, index) {
        final event = displayItems[index];

        if (event.containsKey('template')) {
          // NEW: handle dashboard slide specially
          if (event['template'] == 'dashboard') {
            final text = (event['text'] ?? '').toString();
            return Card(
              child: ListTile(
                leading: Image.asset(
                  "assets/backgrounds/dashboard.png",
                  width: 56,
                  height: 56,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 56),
                ),
                title: const Text('Safety Dashboard'),
                subtitle: Text(text),
              ),
            );
          }

          // EXISTING handling for other templates
          final mediaPaths = (event['mediaPaths'] as List<dynamic>?)?.cast<String>() ?? [];
          final text = (event['text'] ?? '').toString();
          final scrollingText = event['scrollingText'] == true;

          for (var path in mediaPaths) {
            print('Template media path: $path');
          }

          return Card(
            child: ListTile(
              leading: mediaPaths.isNotEmpty
                  ? buildMediaPreview(mediaPaths.first)
                  : const Icon(Icons.slideshow, size: 56),
              title: Text('Template: ${event['template']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (text.isNotEmpty) Text('Text: $text'),
                  if (scrollingText) const Text('Scrolling Text Enabled'),
                  Text('Media count: ${mediaPaths.length}'),
                ],
              ),
            ),
          );
        }
        else if (event.containsKey('path')) {
          final folderNum = event['folderNum'] ?? 0;
          final path = (event['path'] ?? '').toString();
          return Card(
            child: ListTile(
              leading: buildMediaPreview(path, folderNum),
              title: Text(event['name']?.toString() ?? ''),
              subtitle: Text("Duration: ${event['duration_seconds']} seconds"),
            ),
          );
        } else {
          return Card(
            child: ListTile(
              leading: const Icon(Icons.help_outline),
              title: Text(event.toString()),
            ),
          );
        }
      },
    );
  }

  void _handleNewData(Map<String, dynamic> data) async {
    print('onNewData keys: ${data.keys.toList()} safety?=${data['safety_dashboard'] is Map}');
// update the flag immediately if present
    if (data['daily_thirukural'] is bool) {
      setState(() { _dailyThirukural = data['daily_thirukural'] as bool; });
    }
// --- safety_dashboard support ---
    if (data['safety_dashboard'] is Map) {
      final sd = (data['safety_dashboard'] as Map).cast<String, dynamic>();
      setState(() {
        _safetyDashboard = sd;
        _safetyEnabled = (sd['enabled'] == true);
      });
      print('SAFETY[pushed] enabled=${_safetyEnabled} payload=${_safetyDashboard}');
      _logSafetyDashboard('pushed');

    }

    dynamic rawEvents = data['events'];
    if (rawEvents == null) return;

    List eventsList = _normalizeEvents(rawEvents);
    DateTime normalizeDate(DateTime date) => DateTime(date.year, date.month, date.day);

    // Use a temporary map to group and merge events by normalized date
    Map<DateTime, List<Map<String, dynamic>>> groupedEvents = {};

    for (var dayEvent in eventsList) {
      String dateStr = dayEvent['date'] ?? '';
      List images = dayEvent['images'] ?? [];

      DateTime date;
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        date = DateTime.now();
      }
      final normalizedDate = normalizeDate(date);

      List<Map<String, dynamic>> slideshowItems = [];

      for (var imageGroup in images) {
        int? folderNum;
        // Safely parse folderNum, handle if folder is string or int
        final folderRaw = imageGroup['folder'];
        if (folderRaw is int) {
          folderNum = folderRaw;
        } else if (folderRaw is String) {
          folderNum = int.tryParse(folderRaw);
        }
        if (folderNum == null) continue;

        String? folderName = folderNumberToName[folderNum];
        if (folderName == null) continue;

        // Get list of images for this folder
        List<String> allImages = folderNum == 13 ? await listOthersFolderFiles()
            : (assetFolders[folderName] ?? []);

        List<dynamic> imgs = imageGroup['images'] ?? [];

        bool isTemplate = imageGroup.containsKey('template') || imageGroup.containsKey('mediaPaths');

        if (isTemplate) {
          List<dynamic> imgs = imageGroup['images'] ?? [];
          final converted = await _convertImagesToTemplateData(imgs, folderNum, isOnline);

          slideshowItems.add({
            'template': imageGroup['template'] ?? '',
            'mediaPaths': converted['mediaPaths'] ?? [],
            'durations': converted['durations'] ?? {},
            'text': imageGroup['text'] ?? '',
            'scrollingText': imageGroup['scrollingText'] ?? false,
            'folderNum': folderNum,
          });
        } else {
          for (var img in imgs) {
            if (img is Map && img.isNotEmpty) {
              var entry = img.entries.first;

              int pos = 0;
              if (entry.key is int) {
                pos = entry.key as int;
              } else if (entry.key is String) {
                pos = int.tryParse(entry.key) ?? 0;
              }

              int duration = entry.value ?? 5;
              String imgPath = (pos > 0 && pos <= allImages.length) ? allImages[pos - 1] : '';
              if (imgPath.isEmpty) continue;

              slideshowItems.add({
                'path': imgPath,
                'name': imgPath.split(Platform.pathSeparator).last,
                'duration_seconds': duration,
                'folderNum': folderNum,
              });
            }
          }
        }
      }

      // Merge existing events for the date, avoid overwriting
      groupedEvents.update(normalizedDate, (existing) {
        existing.addAll(slideshowItems);
        return existing;
      }, ifAbsent: () => slideshowItems);
    }

    print('Events updated for multiple days (before setState): $groupedEvents');

    setState(() {
      events = groupedEvents;
    });

    // Save only in offline mode
    if (!isOnline) {
      final prefs = await SharedPreferences.getInstance();

      // Save as Map<String, dynamic> with date keys
      final eventsListToSave = groupedEvents.entries.map((entry) {
        return {
          'date': entry.key.toIso8601String().split('T').first,
          'images': entry.value,
        };
      }).toList();

// if the server pushed the flag, update it
      if (data['daily_thirukural'] is bool) {
        setState(() {
          _dailyThirukural = data['daily_thirukural'] as bool;
        });
      }

      final jsonToSave = jsonEncode({
        'events': eventsListToSave,
        'daily_thirukural': _dailyThirukural,
        if (_safetyDashboard != null) 'safety_dashboard': _safetyDashboard,
      });
      print('WROTE safety_dashboard to SharedPreferences? ${jsonToSave.contains('"safety_dashboard"')}');
      await prefs.setString('calendar_events', jsonToSave);
      await _loadEventsFromStorage();

      print('Saving events from new data to storage: $jsonToSave');
    }
  }

  void _addEventsFromQr(Map qrJson) async {
    if (qrJson['slides'] is! List || qrJson['days_duration'] == null) {
      print('Invalid QR structure: slides or days_duration missing');
      return;
    }

    final slides = qrJson['slides'] as List;
    final daysDuration = qrJson['days_duration'] as int;

    String? dateStr = qrJson['date'];
    DateTime startDate;
    if (dateStr != null) {
      try {
        startDate = DateTime.parse(dateStr);
      } catch (e) {
        print('Invalid date in QR, using today: $e');
        startDate = DateTime.now();
      }
    } else {
      print('No date in QR, using today');
      startDate = DateTime.now();
    }

    List<Map<String, dynamic>> slideshowItems = [];

    for (var slide in slides) {
      final templateId = slide['template_id'] ?? 0;
      final templateStr = templateIdToString[templateId] ?? '';
      final slideText = slide['text'] ?? '';
      final slideImagesList = slide['images'] as List<dynamic>? ?? [];

      List<String> mediaPaths = [];
      Map<String, int> durations = {};

      for (var folderBlock in slideImagesList) {
        final folderNum = folderBlock['folder'];
        final folderName = folderNumberToName[folderNum];
        if (folderName == null) {
          print('No folder name for number $folderNum');
          continue;
        }
        List<String> allImages = assetFolders[folderName] ?? [];

        final folderImages = folderBlock['images'] as List<dynamic>? ?? [];

        for (var img in folderImages) {
          if (img is Map && img.isNotEmpty) {
            var entry = img.entries.first;

            int pos;
            if (entry.key is int) {
              pos = entry.key as int;
            } else if (entry.key is String) {
              pos = int.tryParse(entry.key) ?? 0;
            } else {
              pos = 0;
            }

            int duration = entry.value;
            String imgPath =
            (pos > 0 && pos <= allImages.length) ? allImages[pos - 1] : '';
            if (imgPath == '') {
              print(
                  'WARNING: Could not reconstruct image path for folder $folderNum ($folderName), index $pos');
              continue;
            }
            mediaPaths.add(imgPath);
            durations[imgPath] = duration;
          } else {
            print('Invalid image entry: $img');
          }
        }
      }

      if (templateStr.isNotEmpty) {
        slideshowItems.add({
          'template': templateStr,
          'mediaPaths': mediaPaths,
          'text': slideText,
          'scrollingText': (templateStr == '70image30scrolltext'),
          'durations': durations,
        });
      } else {
        for (var imgPath in mediaPaths) {
          slideshowItems.add({
            'path': imgPath,
            'name': imgPath.split('/').last,
            'duration_seconds': durations[imgPath] ?? 5,
          });
        }
      }
    }

    for (int i = 0; i < daysDuration; i++) {
      final targetDateRaw = DateTime(startDate.year, startDate.month, startDate.day + i);
      final targetDate = DateTime(targetDateRaw.year, targetDateRaw.month, targetDateRaw.day);

      // Get existing events for the date or empty list
      final existingItems = events[targetDate] ?? [];

      // Merge new slideshow items with existing ones
      events[targetDate] = List.from(existingItems)..addAll(slideshowItems);

      print('Merged ${slideshowItems.length} slides/images to date: $targetDate');
    }

    setState(() {});

    // Save to storage and reload for UI update
    await _saveEventsToStorage();
    await _loadEventsFromStorage();
  }

  Future<void> clearOthersFolder() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final othersDir = Directory('${appDocDir.path}/Others');

    if (await othersDir.exists()) {
      final files = othersDir.listSync();
      for (final file in files) {
        if (file is File) {
          try {
            await file.delete();
            print('Deleted file: ${file.path}');
          } catch (e) {
            print('Failed to delete file: ${file.path}, error: $e');
          }
        }
      }
      print('Cleared all files in Others folder.');
    } else {
      print('Others folder does not exist.');
    }
  }
}
