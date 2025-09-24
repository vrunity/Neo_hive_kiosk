// kiosk_server.dart
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shared_preferences/shared_preferences.dart';

class KioskServer {
  final int port = 8080;
  late final HttpServer _server;

  final void Function(Map<String, dynamic>)? onNewData;

  KioskServer({this.onNewData});

  // -------- Logging (keep last 50 requests) --------
  static const int _maxLogs = 50;
  final List<Map<String, dynamic>> _logs = [];

  Map<String, dynamic> _headersToMap(Map<String, String> headers) =>
      headers.map((k, v) => MapEntry(k, v));

  String _truncate(String s, {int max = 20000}) =>
      s.length <= max ? s : (s.substring(0, max) + '…[truncated]');

  void _logRequest({
    required String method,
    required Uri uri,
    required Map<String, String> headers,
    required String body,
  }) {
    final now = DateTime.now().toIso8601String();
    final entry = {
      'time': now,
      'method': method,
      'path': uri.toString(),
      'headers': _headersToMap(headers),
      'body': _truncate(body),
      'bodyBytes': body.length,
    };

    // Console dump
    print('--- Incoming $method ${uri.toString()} at $now ---');
    print('Headers: ${jsonEncode(entry['headers'])}');
    print('Body (${entry['bodyBytes']} bytes): ${entry['body']}');
    print('----------------------------------------------------');

    // Keep a rolling buffer
    _logs.add(entry);
    if (_logs.length > _maxLogs) _logs.removeAt(0);
  }

  // -------- CORS --------
  static const Map<String, String> _corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Origin, Content-Type, X-Filename',
  };

  static Middleware get _corsMiddleware {
    return (Handler innerHandler) {
      return (Request request) async {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }
        final response = await innerHandler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

// ========= Replace the existing helper with this one =========
  Future<List<FileSystemEntity>> _listOthersSorted({bool natural = true}) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${appDocDir.path}/Others');
    if (!await dir.exists()) return const [];

    // Only files (skip folders), we’ll sort after we have the list
    final items = (await dir.list(recursive: false, followLinks: false).toList())
        .whereType<File>()
        .toList();

    // Natural compare so 2 < 10
    final _num = RegExp(r'(\d+)');
    int naturalCompare(String a, String b) {
      final A = a, B = b;
      final pa = _num.allMatches(A).toList(), pb = _num.allMatches(B).toList();
      int ia = 0, ib = 0, i = 0, j = 0;
      while (i < A.length && j < B.length) {
        final aHit = ia < pa.length && pa[ia].start == i;
        final bHit = ib < pb.length && pb[ib].start == j;
        if (aHit && bHit) {
          final na = int.parse(pa[ia].group(0)!);
          final nb = int.parse(pb[ib].group(0)!);
          if (na != nb) return na.compareTo(nb);
          i = pa[ia++].end;
          j = pb[ib++].end;
        } else {
          final ca = A.codeUnitAt(i), cb = B.codeUnitAt(j);
          if (ca != cb) return ca.compareTo(cb);
          i++; j++;
        }
      }
      return (A.length - i).compareTo(B.length - j);
    }

    String fileName(FileSystemEntity e) =>
        e.uri.pathSegments.isNotEmpty ? e.uri.pathSegments.last : e.path.split('/').last;

    // Sort by STEM (name without extension) first (natural), then by EXT, then by full name.
    items.sort((x, y) {
      final nx = fileName(x).toLowerCase();
      final ny = fileName(y).toLowerCase();

      final dx = nx.lastIndexOf('.');
      final dy = ny.lastIndexOf('.');

      final stemX = dx > 0 ? nx.substring(0, dx) : nx;
      final stemY = dy > 0 ? ny.substring(0, dy) : ny;

      final extX = dx > 0 ? nx.substring(dx + 1) : '';
      final extY = dy > 0 ? ny.substring(dy + 1) : '';

      // 1) by stem (natural)
      final stemCmp = natural ? naturalCompare(stemX, stemY) : stemX.compareTo(stemY);
      if (stemCmp != 0) return stemCmp;

      // 2) tie-break by extension (alphabetic)
      final extCmp = extX.compareTo(extY);
      if (extCmp != 0) return extCmp;

      // 3) final tie-break by full name (stable)
      return nx.compareTo(ny);
    });

    return items;
  }

  // -------- Start / Stop --------
  Future<void> start() async {
    final handler = (Request request) async {
      print('Incoming request: ${request.method} ${request.url.path}');
      try {
        if (request.method == 'OPTIONS') {
          return Response.ok('', headers: _corsHeaders);
        }

        // ---- GET /health (simple OK)
        if (request.method == 'GET' && request.url.path == 'health') {
          _logRequest(
            method: request.method,
            uri: request.requestedUri,
            headers: request.headers,
            body: '',
          );
          return Response.ok('OK', headers: _corsHeaders);
        }

        // ---- GET /_logs (recent logged requests)
        if (request.method == 'GET' && request.url.path == '_logs') {
          _logRequest(
            method: request.method,
            uri: request.requestedUri,
            headers: request.headers,
            body: '',
          );
          return Response.ok(
            jsonEncode({'count': _logs.length, 'logs': _logs}),
            headers: {
              ..._corsHeaders,
              'Content-Type': 'application/json',
            },
          );
        }

        // ---- GET /dump-storage (current SharedPreferences payload)
        if (request.method == 'GET' && request.url.path == 'dump-storage') {
          final prefs = await SharedPreferences.getInstance();
          final existingRaw = prefs.getString('calendar_events') ?? '{}';
          _logRequest(
            method: request.method,
            uri: request.requestedUri,
            headers: request.headers,
            body: '',
          );
          return Response.ok(
            existingRaw,
            headers: {
              ..._corsHeaders,
              'Content-Type': 'application/json',
            },
          );
        }

        // ---- GET /list-others -> sorted list of filenames in Others/
        if (request.method == 'GET' && request.url.path == 'list-others') {
          _logRequest(
            method: request.method,
            uri: request.requestedUri,
            headers: request.headers,
            body: '',
          );
          final entities = await _listOthersSorted(natural: true); // set false for plain alpha
          final files = entities
              .whereType<File>()
              .map((f) => f.uri.pathSegments.last)
              .toList();
          return Response.ok(
            jsonEncode({'files': files}),
            headers: {..._corsHeaders, 'Content-Type': 'application/json'},
          );
        }

        // ---- POST /upload (JSON event payload)
        if (request.method == 'POST' && request.url.path == 'upload') {
          final contentType = request.headers['content-type'] ?? '';
          if (!contentType.contains('application/json')) {
            _logRequest(
              method: request.method,
              uri: request.requestedUri,
              headers: request.headers,
              body: '(non-json)',
            );
            return Response(415, body: 'Unsupported Media Type', headers: _corsHeaders);
          }

          final payload = await request.readAsString();
          _logRequest(
            method: request.method,
            uri: request.requestedUri,
            headers: request.headers,
            body: payload,
          );

          print('Raw JSON payload:\n$payload');
          final Map<String, dynamic> jsonData = jsonDecode(payload);

          // ----- Load previous storage
          final prefs = await SharedPreferences.getInstance();
          final existingRaw = prefs.getString('calendar_events');
          Map<String, dynamic> existingData = {};
          if (existingRaw != null) {
            try {
              existingData = jsonDecode(existingRaw);
            } catch (_) {
              existingData = {};
            }
          }

          // ----- Start from previous events (list of {'date': 'YYYY-MM-DD', 'images': [...]})
          List<dynamic> existingEvents =
          (existingData['events'] is List) ? (existingData['events'] as List) : <dynamic>[];

          // Reindex by date for merging/overwriting that date
          final Map<String, Map<String, dynamic>> eventsByDate = {};
          for (final ev in existingEvents) {
            if (ev is Map && ev['date'] != null) {
              eventsByDate[ev['date'].toString()] = Map<String, dynamic>.from(ev);
            }
          }

          // ----- New incoming events (optional)
          final List incomingEventsList =
          (jsonData['events'] is List) ? (jsonData['events'] as List) : const [];

          for (final ev in incomingEventsList) {
            if (ev is! Map) continue;

            final String? dateStr = ev['date']?.toString();
            if (dateStr == null || dateStr.isEmpty) continue;

            final int daysDuration =
            (ev['days_duration'] is int && ev['days_duration'] > 0) ? ev['days_duration'] : 1;

            final DateTime startDate = DateTime.tryParse(dateStr) ?? DateTime.now();

            for (int i = 0; i < daysDuration; i++) {
              final String isoDate =
                  startDate.add(Duration(days: i)).toIso8601String().split('T').first;

              // Store the event for that exact date. We keep whatever "images" the client sent
              // (including empty []), so the app knows the date exists even if no images.
              final Map<String, dynamic> copy = Map<String, dynamic>.from(ev);
              copy['date'] = isoDate;
              eventsByDate[isoDate] = copy;
            }
          }

          final List<Map<String, dynamic>> mergedEvents = eventsByDate.values
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
            ..sort((a, b) => a['date'].toString().compareTo(b['date'].toString()));

          // ----- daily_thirukural flag (preserve previous if not provided)
          final bool? incomingThirukural =
          (jsonData['daily_thirukural'] is bool) ? jsonData['daily_thirukural'] as bool : null;
          final bool existingThirukural =
          (existingData['daily_thirukural'] is bool) ? existingData['daily_thirukural'] as bool : false;
          final bool thirukuralFlag = incomingThirukural ?? existingThirukural;

          // ----- safety_dashboard (preserve previous if not provided)
          Map<String, dynamic>? safetyIncoming;
          if (jsonData['safety_dashboard'] is Map) {
            safetyIncoming = (jsonData['safety_dashboard'] as Map).cast<String, dynamic>();
          }
          Map<String, dynamic>? safetyExisting;
          if (existingData['safety_dashboard'] is Map) {
            safetyExisting = (existingData['safety_dashboard'] as Map).cast<String, dynamic>();
          }
          final Map<String, dynamic>? safetyToSave = safetyIncoming ?? safetyExisting;

          // ----- Build final object to persist and to push to UI
          final mergedData = <String, dynamic>{
            'events': mergedEvents,
            'daily_thirukural': thirukuralFlag,
            if (safetyToSave != null) 'safety_dashboard': safetyToSave,
          };

          await prefs.setString('calendar_events', jsonEncode(mergedData));

          print('Data received and merged successfully:');
          print(jsonEncode(mergedData));

          // Forward EVERYTHING (including safety_dashboard) to the app
          onNewData?.call(mergedData);

          return Response.ok(
            jsonEncode({'status': 'success', 'message': 'Data received and merged'}),
            headers: {
              ..._corsHeaders,
              'Content-Type': 'application/json',
            },
          );
        }

        // ---- POST /upload-file (binary)
        if (request.method == 'POST' && request.url.path == 'upload-file') {
          final filenameHeader = request.headers['X-Filename'];
          final bodyBytes = await request.read().fold<List<int>>(
            <int>[],
                (b, d) {
              b.addAll(d);
              return b;
            },
          );

          _logRequest(
            method: request.method,
            uri: request.requestedUri,
            headers: request.headers,
            body: '[binary ${bodyBytes.length} bytes; filename=${filenameHeader ?? '(missing)'}]',
          );

          if (filenameHeader == null || filenameHeader.isEmpty) {
            return Response(400, body: 'Missing X-Filename header', headers: _corsHeaders);
          }

          final filename = Uri.decodeComponent(filenameHeader);
          final appDocDir = await getApplicationDocumentsDirectory();
          final directory = Directory('${appDocDir.path}/Others');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          final file = File('${directory.path}/$filename');
          await file.writeAsBytes(bodyBytes);
          print('Saved uploaded file to: ${file.path}');

          return Response.ok(
            jsonEncode({'status': 'success', 'message': 'File uploaded'}),
            headers: {
              ..._corsHeaders,
              'Content-Type': 'application/json',
            },
          );
        }

        // ---- 404
        _logRequest(
          method: request.method,
          uri: request.requestedUri,
          headers: request.headers,
          body: '',
        );
        return Response.notFound('Not Found', headers: _corsHeaders);
      } catch (e, stack) {
        print('Error processing request: $e\n$stack');
        return Response.internalServerError(body: 'Internal Server Error', headers: _corsHeaders);
      }
    };

    final pipeline = const Pipeline().addMiddleware(_corsMiddleware).addHandler(handler);
    _server = await shelf_io.serve(pipeline, '0.0.0.0', port);
    print('Kiosk HTTP server running at http://${_server.address.address}:$port');
  }

  Future<void> stop() async {
    await _server.close(force: true);
  }
}

// -------- Utility to clear Others folder (optional) --------
Future<void> clearOthersFolder() async {
  final appDocDir = await getApplicationDocumentsDirectory();
  final othersDir = Directory('${appDocDir.path}/Others');

  if (await othersDir.exists()) {
    try {
      final files = othersDir.listSync();
      for (final file in files) {
        if (file is File) {
          await file.delete();
          print('Deleted file: ${file.path}');
        }
      }
      print('All files deleted in Others folder.');
    } catch (e) {
      print('Error deleting files in Others folder: $e');
    }
  } else {
    print('Others folder does not exist.');
  }
}
