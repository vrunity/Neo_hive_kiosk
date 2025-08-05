import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'qr_scanner_page.dart';
import 'slideshow_page.dart';

class CalendarKioskApp extends StatefulWidget {
  const CalendarKioskApp({super.key});
  @override
  State<CalendarKioskApp> createState() => _CalendarKioskAppState();
}

const Map<String, List<String>> assetFolders = {
  'Confined Space': [
    'assets/Confined Space/confined space entry.jpg',
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
  ],
  'Hight work': [
    'assets/Hight work/fall production.jpg',
    'assets/Hight work/fall production - 2.jpg',
    'assets/Hight work/ladder safety.jpg',
    'assets/Hight work/suspended load.jpg',
    'assets/Hight work/suspended load 2.jpg',
  ],
  'Labours Day': [
    'assets/Labours Day/May 1.jpg',
  ],
  'Material Handling': [
    'assets/Material Handling/over load.jpg',
    'assets/Material Handling/Safe lifting.jpg',
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
  'Womens safety': [
    'assets/Womens safety/women 2.jpg',
    'assets/Womens safety/Womens day.jpg',
    'assets/Womens safety/Womens day 2.jpg',
    'assets/Womens safety/Womens day 3.jpg',
  ],
};

// Map folder numbers to names, must match QR generator
const Map<int, String> folderNumberToName = {
  1: 'Confined Space',
  2: 'First Aid',
  3: 'Forklift',
  4: 'Hight work',
  5: 'Labours Day',
  6: 'Material Handling',
  7: 'MSDS',
  8: 'Near misses',
  9: 'PPE',
  10: 'Womens safety',
};
const Map<int, String> templateIdToString = {
  1: '70image30text',
  2: '70image30scrolltext',
  3: 'image-image',
  4: 'video-image',
};

class _CalendarKioskAppState extends State<CalendarKioskApp> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  Map<DateTime, List<Map<String, dynamic>>> events = {};

  @override
  void initState() {
    super.initState();
    _loadEventsFromStorage();
  }

  Future<void> _loadEventsFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('calendar_events');
    if (raw != null) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        events = decoded.map((k, v) => MapEntry(
          DateTime.parse(k),
          List<Map<String, dynamic>>.from(
              (v as List).map((e) => Map<String, dynamic>.from(e))),
        ));
      });
    }
  }

  Future<void> _saveEventsToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final saveMap = events.map((k, v) => MapEntry(k.toIso8601String(), v));
    await prefs.setString('calendar_events', jsonEncode(saveMap));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kiosk Calendar")),
      body: Column(
        children: [
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
            },
            onFormatChanged: (format) {
              setState(() {
                _calendarFormat = format;
              });
            },
            eventLoader: (day) => events[DateTime(day.year, day.month, day.day)] ?? [],
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                return const SizedBox.shrink();
              },
              defaultBuilder: (context, day, focusedDay) {
                final hasEvent = this.events[DateTime(day.year, day.month, day.day)]?.isNotEmpty ?? false;
                if (hasEvent) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.qr_code_scanner),
                label: const Text("Upload Data"),
                onPressed: () async {
                  final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const QrScannerPage()),
                  );
                  if (result != null && mounted) {
                    try {
                      final qrJson = result is String ? jsonDecode(result) : result;
                      _addEventsFromQr(qrJson);
                      await _saveEventsToStorage();
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Invalid QR Data')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(width: 18),
              ElevatedButton.icon(
                icon: const Icon(Icons.slideshow),
                label: const Text("Move to Kiosk"),
                onPressed: () {
                  final today = DateTime.now();
                  final todayKey = DateTime(today.year, today.month, today.day);
                  final todayEvents = events[todayKey] ?? [];
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SlideshowPage(slidesOrImages: todayEvents),
                    ),
                  );
                },
              ),
              const SizedBox(width: 18),
              IconButton(
                icon: const Icon(Icons.delete_forever, color: Colors.red, size: 32),
                tooltip: 'Clear Day', // Optional: shows a hint on long press
                onPressed: () async {
                  final dateKey = DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day);
                  if ((events[dateKey]?.isEmpty ?? true)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No images to clear on this date.')),
                    );
                    return;
                  }
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear Images?'),
                      content: const Text('Are you sure you want to clear all images for this date?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    setState(() {
                      events.remove(dateKey);
                    });
                    await _saveEventsToStorage();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Images cleared for this date.')),
                    );
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _buildEventList(),
          ),
        ],
      ),
    );
  }

  Widget _buildEventList() {
    final dayEvents = events[DateTime(_focusedDay.year, _focusedDay.month, _focusedDay.day)] ?? [];
    if (dayEvents.isEmpty) {
      return const Center(child: Text('No events for selected date.'));
    }
    return ListView.builder(
      itemCount: dayEvents.length,
      itemBuilder: (context, index) {
        final event = dayEvents[index];

        // For template slides:
        if (event.containsKey('template')) {
          final mediaPaths = (event['mediaPaths'] as List<dynamic>?)?.cast<String>() ?? [];
          final text = event['text'] ?? '';
          final durations = event['durations'] as Map<String, dynamic>? ?? {};

          return Card(
            child: ListTile(
              leading: mediaPaths.isNotEmpty
                  ? Image.asset(
                mediaPaths[0],
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 56),
              )
                  : const Icon(Icons.image_not_supported, size: 56),
              title: Text('Template: ${event['template']}'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Text: $text'),
                  Text('Durations: ${durations.values.join(", ")} seconds'),
                ],
              ),
            ),
          );
        }

        // For direct images:
        else {
          return Card(
            child: ListTile(
              leading: Image.asset(
                event['path'] ?? '',
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image, size: 56),
              ),
              title: Text(event['name'] ?? ''),
              subtitle: Text("Duration: ${event['duration_seconds']} seconds"),
            ),
          );
        }
      },
    );
  }




  /// Rebuild event list from QR JSON using per-folder index!
  void _addEventsFromQr(Map qrJson) {
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

      // Collect media paths and durations for this slide
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
            String indexStr = entry.key.toString();
            int pos = int.tryParse(indexStr) ?? 0;
            int duration = entry.value;
            String imgPath = (pos > 0 && pos <= allImages.length) ? allImages[pos - 1] : '';
            if (imgPath == '') {
              print('WARNING: Could not reconstruct image path for folder $folderNum ($folderName), index $pos');
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
        // Template slide, add one slide object
        slideshowItems.add({
          'template': templateStr,
          'mediaPaths': mediaPaths,
          'text': slideText,
          'scrollingText': (templateStr == '70image30scrolltext'),
          'durations': durations,
        });
      } else {
        // No template: treat each image as a direct image slide
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
      final targetDate = DateTime(startDate.year, startDate.month, startDate.day + i);
      events[targetDate] = List.from(slideshowItems);
      print('Assigned ${slideshowItems.length} slides/images to date: $targetDate');
    }

    setState(() {});
  }
}
