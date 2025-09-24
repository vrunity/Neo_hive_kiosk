import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;
import 'package:excel/excel.dart';

class ThirukuralEntry {
  final String title;
  final String tamilKural;
  final String tamilMeaning;
  final String englishKural;
  final String englishMeaning;

  ThirukuralEntry({
    required this.title,
    required this.tamilKural,
    required this.tamilMeaning,
    required this.englishKural,
    required this.englishMeaning,
  });

  bool get isEmptyRow =>
      (title.trim().isEmpty) &&
          (tamilKural.trim().isEmpty) &&
          (tamilMeaning.trim().isEmpty) &&
          (englishKural.trim().isEmpty) &&
          (englishMeaning.trim().isEmpty);
}

class ThirukuralService {
  final _rng = Random();
  final List<ThirukuralEntry> _cache = [];
  String? _loadedAsset;

  bool get isLoaded => _cache.isNotEmpty;
  List<ThirukuralEntry> get all => List.unmodifiable(_cache);

  /// Load excel from assets.
  ///
  /// - [assetPath] : assets/data/Thirukural.xlsx
  /// - [sheetName] : optional; if null the first sheet is used
  /// - [maxRows]   : optional absolute cap on how many data rows to read
  /// - [stopAfterNEmptyRows] : stop scanning once this many consecutive empty rows are seen
  Future<void> loadFromAsset(
      String assetPath, {
        String? sheetName,
        int? maxRows,
        int stopAfterNEmptyRows = 25,
      }) async {
    // Avoid reloading the same asset unless forced
    if (_loadedAsset == assetPath && _cache.isNotEmpty) return;

    _cache.clear();
    _loadedAsset = assetPath;

    final bytes = await rootBundle.load(assetPath);
    final excel = Excel.decodeBytes(bytes.buffer.asUint8List());

    final table = (sheetName != null && excel.tables.containsKey(sheetName))
        ? excel.tables[sheetName]!
        : excel.tables[excel.tables.keys.first]!;

    if (table.rows.isEmpty) return;

    // Find the header row (allowing a few top rows to be non-data)
    final headerRowIndex = _findHeaderRowIndex(table);
    if (headerRowIndex == -1) return;

    final header = table.rows[headerRowIndex]
        .map((c) => _normHeader((c?.value ?? '').toString()))
        .toList();

    final idxTitle          = _findHeaderIndex(header, const ['title']);
    final idxTamilKural     = _findHeaderIndex(header, const ['tamil kural', 'kural (ta)', 'kural tamil', 'tamil-couplet', 'tamil couplet', 'kural']);
    final idxTamilMeaning   = _findHeaderIndex(header, const ['tamil meaning', 'meaning (ta)', 'explanation (ta)']);
    final idxEnglishKural   = _findHeaderIndex(header, const ['english kural', 'kural (en)', 'english couplet']);
    final idxEnglishMeaning = _findHeaderIndex(header, const ['english meaning', 'meaning (en)', 'translation', 'explanation (en)']);

    int empties = 0;
    int added   = 0;

    for (int r = headerRowIndex + 1; r < table.rows.length; r++) {
      if (maxRows != null && added >= maxRows) break;

      final row = table.rows[r];
      String at(int i) {
        if (i < 0 || i >= row.length) return '';
        final v = row[i]?.value;
        if (v == null) return '';
        return v.toString().trim();
      }

      final entry = ThirukuralEntry(
        title:           at(idxTitle),
        tamilKural:      at(idxTamilKural),
        tamilMeaning:    at(idxTamilMeaning),
        englishKural:    at(idxEnglishKural),
        englishMeaning:  at(idxEnglishMeaning),
      );

      // Stop early on consecutive empties (prevents trailing blank rows)
      if (entry.isEmptyRow) {
        empties++;
        if (empties >= stopAfterNEmptyRows) break;
        continue;
      }
      empties = 0;

      // Optionally skip rows with no Tamil kural at all
      if (entry.tamilKural.trim().isEmpty) continue;

      _cache.add(entry);
      added++;
    }
  }

  /// Return a random entry from the loaded cache.
  ThirukuralEntry randomEntry() {
    if (_cache.isEmpty) {
      throw StateError('ThirukuralService not loaded or excel empty.');
    }
    return _cache[_rng.nextInt(_cache.length)];
  }

  /// Fetch by index (safe).
  ThirukuralEntry? byIndex(int index) {
    if (index < 0 || index >= _cache.length) return null;
    return _cache[index];
  }

  /// Utility: split a Tamil kural into (first/second) word counts.
  /// Example: splitTamilKural(text, first: 4, second: 3)
  List<String> splitTamilKural(String kural, {int first = 4, int second = 3}) {
    final words = kural.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
    if (words.isEmpty) return [''];
    final l1 = words.take(first).join(' ');
    final l2 = words.skip(first).take(second).join(' ');
    final rest = words.skip(first + second).join(' ');
    final line2 = (l2.isEmpty ? rest : (rest.isEmpty ? l2 : '$l2 $rest')).trim();
    return [l1.trim(), line2];
  }

  // ---------- helpers ----------

  // Normalize header cell text: lowercase, collapse spaces/underscores/dashes.
  String _normHeader(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), ' ').trim();

  // Find first row that "looks like" a header by containing at least one of our keys.
  int _findHeaderRowIndex(Sheet sheet) {
    final rowsToScan = sheet.rows.length.clamp(0, 10); // top 10 rows is enough
    for (int r = 0; r < rowsToScan; r++) {
      final normalized = sheet.rows[r]
          .map((c) => _normHeader((c?.value ?? '').toString()))
          .toList();
      final hasAnyKnownHeader = [
        'title',
        'tamil kural',
        'tamil meaning',
        'english kural',
        'english meaning',
      ].any((k) => normalized.contains(k));
      if (hasAnyKnownHeader) return r;
    }
    // Fallback to first row
    return sheet.rows.isNotEmpty ? 0 : -1;
  }

  // Find a column index using a list of acceptable header names (normalized).
  int _findHeaderIndex(List<String> normalizedHeaderRow, List<String> candidates) {
    for (final c in candidates.map(_normHeader)) {
      final idx = normalizedHeaderRow.indexOf(c);
      if (idx != -1) return idx;
    }
    return -1; // not found
  }
}
