import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  bool _scanned = false;
  Map<String, dynamic>? _parsedJson;
  String? _rawValue;
  String? _error;

  void _handleDetect(BarcodeCapture capture) {
    if (_scanned) return; // Prevent multiple triggers
    final barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        final raw = barcode.rawValue!;
        print('Scanned QR raw value: ${raw.length > 200 ? raw.substring(0, 200) + '...' : raw}');
        setState(() {
          _scanned = true;
          _rawValue = raw;
        });
        try {
          final parsed = jsonDecode(raw);
          print("Parsed QR JSON:\n$parsed");  // <-- Add this line to see full decoded data in console/log
          setState(() {
            _parsedJson = parsed;
          });
        } catch (e) {
          setState(() {
            _error =
            "Scanned data is not valid JSON!\n"
                "Error: $e\n"
                "First 200 chars: ${raw.length > 200 ? raw.substring(0, 200) + '...' : raw}";
          });
        }
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan QR Code')),
      body: _scanned
          ? _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
          : _parsedJson != null
          ? _buildParsedResult()
          : const Center(child: Text("No data"))
          : MobileScanner(onDetect: _handleDetect),
    );
  }

  Widget _buildParsedResult() {
    final slides = _parsedJson?['slides'] as List<dynamic>? ?? [];
    final days = _parsedJson?['days_duration'];
    final date = _parsedJson?['date'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: [
          const Text("Decoded QR Data", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          if (date != null)
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 2),
              child: Text("Date: $date", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ),
          if (days != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8.0, top: 2),
              child: Text("Days duration: $days", style: const TextStyle(fontSize: 16)),
            ),
          ...slides.map((slide) {
            final templateId = slide['template_id'] ?? 'Unknown';
            final text = slide['text'] ?? '';
            final scrolling = slide['scrolling'] ?? false;
            final folderImages = slide['images'] as List<dynamic>? ?? [];

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Template ID: $templateId", style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text("Text: $text"),
                    Text("Scrolling: ${scrolling ? "Yes" : "No"}"),
                    const SizedBox(height: 8),
                    ...folderImages.map((folder) {
                      final folderNum = folder['folder'];
                      final images = folder['images'] as List<dynamic>? ?? [];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Folder #$folderNum", style: const TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          ...images.map((img) {
                            if (img is Map && img.isNotEmpty) {
                              final entry = img.entries.first;
                              return Text('  Image #${entry.key}: ${entry.value} sec');
                            }
                            return const SizedBox();
                          }).toList(),
                          const SizedBox(height: 10),
                        ],
                      );
                    }).toList(),
                  ],
                ),
              ),
            );
          }).toList(),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _parsedJson),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
