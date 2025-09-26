import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import 'services/thirukural_service.dart';


// =========================================================================
// MODIFICATION: Updated Responsive helpers for large Kiosk screens.
// - Changed `base` from 390 (mobile) to 1080 (portrait kiosk).
// - Widened clamp range to allow for more significant scaling on 4K displays.
// =========================================================================
class RS {
  static Size size(BuildContext c) => MediaQuery.of(c).size;
  static double sw(BuildContext c, [double pct = 1]) => size(c).width * pct;
  static double sh(BuildContext c, [double pct = 1]) => size(c).height * pct;

  /// Scale font by shortest side.
  /// `base` is now 1080, a common width for portrait HD/4K content.
  static double sp(BuildContext c, double v, {double base = 1080}) {
    final s = size(c).shortestSide;
    // Allow scaling up to 4x for high-res screens.
    return v * (s / base).clamp(0.9, 4.0);
  }

  /// Scale pixel offsets/padding by width.
  static double dp(BuildContext c, double v, {double base = 1080}) {
    final w = size(c).width;
    // Allow scaling up to 4x for high-res screens.
    return v * (w / base).clamp(0.9, 4.0);
  }
}

class AutoScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity; // px/sec

  const AutoScrollingText({
    Key? key,
    required this.text,
    this.style,
    this.velocity = 100.0, // Increased default velocity for larger screens
  }) : super(key: key);

  @override
  _AutoScrollingTextState createState() => _AutoScrollingTextState();
}
class SafetyDashboard extends StatelessWidget {
  const SafetyDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // TODO: replace with your real dashboard UI
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Text(
          'Safety Dashboard',
          style: Theme.of(context)
              .textTheme
              .displaySmall // Use a larger theme style
              ?.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _AutoScrollingTextState extends State<AutoScrollingText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  double _textWidth = 0;
  double _screenWidth = 0;
  bool _animationReady = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(_afterLayout);
  }

  void _afterLayout(Duration _) {
    final tp = TextPainter(
      text: TextSpan(
        text: widget.text,
        style: widget.style ?? DefaultTextStyle.of(context).style,
      ),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    )..layout();

    _textWidth = tp.size.width;
    _screenWidth = MediaQuery.of(context).size.width;

    if (_textWidth <= _screenWidth) {
      // No need to scroll if text fits
      return;
    }

    final total = _screenWidth + _textWidth;
    final duration =
    Duration(milliseconds: ((total / widget.velocity) * 1000).toInt());

    _controller = AnimationController(vsync: this, duration: duration)
      ..repeat();
    setState(() => _animationReady = true);
  }

  @override
  void dispose() {
    if (_animationReady) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If text fits or animation isn't ready, just display it centered.
    if (!_animationReady || _textWidth <= _screenWidth) {
      return SizedBox(
        width: double.infinity,
        child: Text(widget.text, style: widget.style, textAlign: TextAlign.center),
      );
    }
    return ClipRect(
      child: SizedBox(
        height: (widget.style?.fontSize ??
            DefaultTextStyle.of(context).style.fontSize ??
            14) *
            1.5,
        width: double.infinity,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (_, child) {
            final x =
                _screenWidth - (_controller.value * (_screenWidth + _textWidth));
            return Transform.translate(offset: Offset(x, 0), child: child);
          },
          child: Text(widget.text, style: widget.style, maxLines: 1),
        ),
      ),
    );
  }
}

class SlideshowPage extends StatefulWidget {
  final List<Map<String, dynamic>> slidesOrImages;

  // Thirukural
  final bool showThirukural;
  final String thirukuralAssetPath; // Excel
  final String? thirukuralBackground; // PNG/JPG asset (optional)

  // Safety Dashboard
  final bool includeSafetyDashboard;

  const SlideshowPage({
    super.key,
    required this.slidesOrImages,
    this.showThirukural = false,
    this.thirukuralAssetPath = 'assets/data/Thirukural.xlsx',
    this.thirukuralBackground,
    this.includeSafetyDashboard = false,
  });

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  int _currentIndex = 0;
  bool _isFullscreen = false;
  Timer? _autoHideTimer;
  final _rng = Random();

  final _thirukuralService = ThirukuralService();
  List<Map<String, dynamic>> _slides = [];

  VideoPlayerController? _videoController;
  String? _currentVideoPath;

  // ---------- helpers ----------
  bool isTemplateItem(Map<String, dynamic> item) => item.containsKey('template');
  bool _isNetwork(String p) =>
      p.startsWith('http://') || p.startsWith('https://');

  bool isVideoFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return ['.mp4', '.mov', '.avi', '.mkv'].contains(ext);
  }

  Alignment _toAlignment(String s) {
    switch (s) {
      case 'topLeft':
        return Alignment.topLeft;
      case 'topCenter':
        return Alignment.topCenter;
      case 'topRight':
        return Alignment.topRight;
      case 'centerLeft':
        return Alignment.centerLeft;
      case 'centerRight':
        return Alignment.centerRight;
      case 'bottomLeft':
        return Alignment.bottomLeft;
      case 'bottomCenter':
        return Alignment.bottomCenter;
      case 'bottomRight':
        return Alignment.bottomRight;
      case 'center':
      default:
        return Alignment.center;
    }
  }

  TextAlign _toTextAlign(String s) {
    switch (s) {
      case 'left':
        return TextAlign.left;
      case 'right':
        return TextAlign.right;
      case 'center':
      default:
        return TextAlign.center;
    }
  }

  Color _hexToColor(String hex) {
    var h = hex.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }

  FontWeight _toFontWeight(dynamic w) {
    if (w == null) return FontWeight.w600;
    final s = w.toString().toLowerCase();
    switch (s) {
      case 'w100':
        return FontWeight.w100;
      case 'w200':
        return FontWeight.w200;
      case 'w300':
        return FontWeight.w300;
      case 'w400':
      case 'normal':
        return FontWeight.w400;
      case 'w500':
        return FontWeight.w500;
      case 'w600':
        return FontWeight.w600;
      case 'w700':
      case 'bold':
        return FontWeight.w700;
      case 'w800':
        return FontWeight.w800;
      case 'w900':
        return FontWeight.w900;
      default:
        return FontWeight.w600;
    }
  }

  List<String> _splitKuralByWords(String kural,
      {int first = 4, int second = 3}) {
    final words =
    kural.split(RegExp(r'\s+')).where((w) => w.trim().isNotEmpty).toList();
    if (words.isEmpty) return [''];
    final l1 = words.take(first).join(' ');
    final l2 = words.skip(first).take(second).join(' ');
    final rest = words.skip(first + second).join(' ');
    final line2 = (l2.isEmpty ? rest : (rest.isEmpty ? l2 : '$l2 $rest')).trim();
    return [l1.trim(), line2];
  }

  // ---------- lifecycle ----------
  @override
  void initState() {
    super.initState();
    _slides = List<Map<String, dynamic>>.from(widget.slidesOrImages);

    // Optionally add the Safety Dashboard as a slide (explicit 5s)
    if (widget.includeSafetyDashboard) {
      _slides.add({
        'template': 'safety-dashboard',
        'durations': {'dashboard': 5}, // explicit; loop also defaults to 5s
        'folderNum': 0,
      });
    }

    if (_slides.isNotEmpty) {
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) setState(() => _isFullscreen = true);
      });
    }

    _maybeInjectThirukuralSlide().then((_) {
      if (mounted && _slides.isNotEmpty) _startSlideshow();
    });
  }

  @override
  void dispose() {
    _slideshowActive = false;     // NEW
    _autoHideTimer?.cancel();
    // Stop and dispose video safely
    _videoController?.pause();
    _videoController?.dispose();
    super.dispose();
  }

  // ---------- thirukural ----------
  Future<void> _maybeInjectThirukuralSlide() async {
    if (!widget.showThirukural) return;

    try {
      await _thirukuralService.loadFromAsset(widget.thirukuralAssetPath);
      final entry = _thirukuralService.randomEntry();

      // Classic 4/3 split for the couplet
      final parts = _splitKuralByWords(entry.tamilKural, first: 4, second: 3);
      final l1 = parts.isNotEmpty ? parts[0] : '';
      final l2 = parts.length > 1 ? parts[1] : '';

      const thiruSeconds = 10;

      // =================================================================
      // MODIFICATION: Increased font sizes for kiosk readability.
      // =================================================================
      final slide = {
        'template': 'kural-cells',
        'mediaPaths': widget.thirukuralBackground != null
            ? [widget.thirukuralBackground!]
            : <String>[],
        'durations': {'image': thiruSeconds, 'text': thiruSeconds},
        'folderNum': 0,
        'dim': 0.35,
        'panelHeightPct': 0.40,
        'cells': [
          {
            'text': entry.title,
            'align': 'topCenter',
            'dx': 0,
            'dy': 30, // More space from top
            'widthPct': 0.92,
            'fontSize': 42, // Increased
            'weight': 'w700',
            'textAlign': 'center',
            'color': '#FFFFFF',
            'shadow': true,
          },
          {
            'text': l1,
            'align': 'center',
            'dx': 0,
            'dy': -40, // Adjusted
            'widthPct': 0.96,
            'fontSize': 36, // Increased
            'weight': 'w900',
            'textAlign': 'center',
            'color': '#FFFFFF',
            'shadow': true,
          },
          {
            'text': l2,
            'align': 'center',
            'dx': 0,
            'dy': 40, // Adjusted
            'widthPct': 0.96,
            'fontSize': 36, // Increased
            'weight': 'w900',
            'textAlign': 'center',
            'color': '#FFFFFF',
            'shadow': true,
          },
          {
            'text': entry.tamilMeaning,
            'align': 'bottomCenter',
            'dx': 0,
            'dy': -250, // Adjusted for larger fonts
            'widthPct': 0.85,
            'fontSize': 32, // Increased
            'weight': 'w600',
            'textAlign': 'justify',
            'color': '#FFFFFF',
            'shadow': true,
            'lineHeight': 1.4,
            'maxLines': 10,
          },
          {
            'text': entry.englishMeaning,
            'align': 'bottomCenter',
            'dx': 0,
            'dy': -100, // Adjusted
            'widthPct': 0.90,
            'fontSize': 30, // Increased
            'weight': 'w600',
            'textAlign': 'justify',
            'color': '#FFFFFF',
            'shadow': true,
            'lineHeight': 1.4,
            'maxLines': 4,
          },
        ],
      };

      _slides.add(slide);
      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  // ---------- video ----------
  Future<void> _initializeVideo(String path) async {
    if (_currentVideoPath == path) return;

    try {
      if (_videoController != null) {
        await _videoController!.dispose();
        _videoController = null;
      }

      if (_isNetwork(path)) {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(path));
      } else if (File(path).existsSync()) {
        _videoController = VideoPlayerController.file(File(path));
      } else {
        _videoController = VideoPlayerController.asset(path);
      }

      await _videoController!.initialize();
      await _videoController!.setLooping(false); // do not loop between slides
      await _videoController!.play();

      _videoController!.addListener(() {
        final v = _videoController!.value;
        // debug if needed
        // print('isPlaying=${v.isPlaying} pos=${v.position}');
      });

      _currentVideoPath = path;
      if (mounted) {
        setState(() {}); // rebuild VideoPlayer with the new ValueKey
      }
    } catch (e) {
      // ignore
    }
  }
  Future<void> _stopAndDisposeVideo() async {
    final c = _videoController;
    if (c == null) return;
    try {
      if (c.value.isInitialized) {
        await c.pause();
        await c.seekTo(Duration.zero);
      }
      await c.dispose();
    } catch (_) {
      // ignore
    } finally {
      _videoController = null;
      _currentVideoPath = null;
    }
  }
  bool _slideshowActive = false;

  Future<void> _cancelSlideshow() async {
    _slideshowActive = false;
    await _stopAndDisposeVideo(); // make sure audio stops too
  }

  // ---------- slideshow loop ----------
  void _startSlideshow() async {
    _slideshowActive = true; // NEW: mark running
    await Future.delayed(const Duration(seconds: 5));
    while (mounted && _slides.isNotEmpty && _slideshowActive) { // NEW: check flag
      final currentItem = _slides[_currentIndex];

      // Duration
      int durationSeconds = 5;
      if (isTemplateItem(currentItem)) {
        final durationsMap =
            currentItem['durations'] as Map<String, dynamic>? ?? {};
        if (durationsMap.isNotEmpty) {
          durationSeconds = durationsMap.values
              .map((v) => v as int)
              .reduce((a, b) => a > b ? a : b);
        }
      } else {
        durationSeconds = currentItem['duration_seconds'] ?? 5;
      }

      // Find a video path (template or direct)
      String? videoPath;
      if (isTemplateItem(currentItem)) {
        final mediaPaths =
            (currentItem['mediaPaths'] as List?)?.cast<String>() ?? const [];
        videoPath = mediaPaths.firstWhere(
              (p) => isVideoFile(p),
          orElse: () => '',
        );
        if (videoPath.isEmpty) videoPath = null;
      } else {
        final pth = currentItem['path'] as String? ?? '';
        if (isVideoFile(pth)) videoPath = pth;
      }

      if (videoPath != null) {
        await _initializeVideo(videoPath);
      } else {
        if (_videoController != null) {
          await _videoController!.pause();
          await _videoController!.dispose();
          _videoController = null;
          _currentVideoPath = null;
        }
      }

      await Future.delayed(Duration(seconds: durationSeconds));
      if (!mounted || !_slideshowActive) break;

// Always stop audio/video from the slide we are leaving.
      await _stopAndDisposeVideo();

      setState(() {
        _currentIndex = (_currentIndex + 1) % _slides.length;
      });
    }
  }

  // ---------- UI helpers ----------
  void _handleFullscreenToggle() {
    setState(() => _isFullscreen = false);
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _isFullscreen = true);
    });
  }

  /// Centralized media builder.
  /// Handles fullscreen aspect ratio enforcement.
  Widget _buildMediaWidget(
      String path,
      int folderNum, {
        BoxFit fit = BoxFit.cover,
      }) {
    // VIDEO
    if (isVideoFile(path)) {
      final c = _videoController;
      if (c != null && c.value.isInitialized && c.value.size.width > 0 && c.value.size.height > 0) {
        return FittedBox(
          fit: fit,
          child: SizedBox(
            width: c.value.size.width,
            height: c.value.size.height,
            child: VideoPlayer(
              c,
              key: ValueKey<String>(_currentVideoPath ?? ''),
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    // IMAGE
    Widget imageWidget;
    if (_isNetwork(path)) {
      imageWidget = Image.network(
        path,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 120),
      );
    } else if (folderNum == 11 || File(path).isAbsolute) {
      imageWidget = Image.file(
        File(path),
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 120),
      );
    } else {
      imageWidget = Image.asset(
        path,
        fit: fit,
        errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 120),
      );
    }
    return imageWidget;
  }

  Future<Widget> _buildThumbnail(String path, int folderNum) async {
    if (isVideoFile(path)) {
      try {
        final thumb = await VideoThumbnail.thumbnailData(
          video: path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 128,
          quality: 75,
        );
        if (thumb != null) return Image.memory(thumb, fit: BoxFit.cover);
      } catch (_) {}
      return const Icon(Icons.videocam_off, size: 56);
    } else {
      if (_isNetwork(path)) {
        return Image.network(
          path,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, size: 56),
        );
      } else if (folderNum == 11 || File(path).isAbsolute) {
        return Image.file(
          File(path),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, size: 56),
        );
      } else {
        return Image.asset(
          path,
          width: 56,
          height: 56,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
          const Icon(Icons.broken_image, size: 56),
        );
      }
    }
  }

  // ---------- build ----------
  @override
  Widget build(BuildContext context) {
    // Force text scale to 1.0 to prevent OS-level font size changes
    final normalized = MediaQuery.of(context).copyWith(textScaleFactor: 1.0);
    return MediaQuery(
      data: normalized,
      child: Builder(
        builder: (context) {
          if (_slides.isEmpty) {
            return Scaffold(
              appBar: AppBar(
                title: const Text('Kiosk Slideshow'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.calendar_today),
                    tooltip: 'Go to Calendar',
                    onPressed: () async {
                      await _cancelSlideshow();
                      if (!mounted) return;
                      await Navigator.of(context).pushNamed('/calendar');
                    },
                  ),
                ],
              ),
              body: const Center(
                child: Text(
                  'No events scheduled for today.',
                  style: TextStyle(fontSize: 32, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final currentItem = _slides[_currentIndex];
          final folderNum = currentItem['folderNum'] ?? 0;

          if (isTemplateItem(currentItem)) {
            return _buildTemplateSlide(context, currentItem, folderNum);
          } else {
            return _buildDirectMediaSlide(context, currentItem, folderNum);
          }
        },
      ),
    );
  }

  Widget _buildTemplateSlide(
      BuildContext context, Map<String, dynamic> slide, int folderNum) {
    final template = slide['template'] as String? ?? '';
    final mediaPaths =
        (slide['mediaPaths'] as List<dynamic>?)?.cast<String>() ?? [];
    final text = slide['text'] as String? ?? '';
    final scrolling = slide['scrollingText'] as bool? ?? false;

    Widget mediaWidget;

    if (template == 'safety-dashboard') {
      mediaWidget = const SizedBox.expand(child: SafetyDashboard());
    } else if (template == '70image30text' || template == '70image30scrolltext') {
      // =================================================================
      // MODIFICATION: Changed flex factors for better vertical balance
      // and increased font size and padding.
      // =================================================================
      mediaWidget = SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            Expanded(
              flex: 8, // Gave more space to the image
              child: mediaPaths.isNotEmpty
                  ? SizedBox.expand( // Ensure it fills the space
                child: _buildMediaWidget(mediaPaths[0], folderNum, fit: BoxFit.fill),
              )
                  : Container(color: Colors.grey),
            ),
            Expanded(
              flex: 2, // Gave more space to the text panel
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                width: double.infinity,
                alignment: Alignment.center,
                child: scrolling
                    ? AutoScrollingText(
                  text: text,
                  style: TextStyle(color: Colors.white, fontSize: RS.sp(context, 36)),
                  velocity: 120.0,
                )
                    : Text(
                  text,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: RS.sp(context, 36)),
                ),
              ),
            ),
          ],
        ),
      );
    } else if (template == 'image-image' || template == 'video-image') {
      mediaWidget = Row(
        children: [
          Expanded(
            child: mediaPaths.isNotEmpty
                ? _buildMediaWidget(mediaPaths[0], folderNum, fit: BoxFit.cover)
                : Container(color: Colors.grey),
          ),
          Expanded(
            child: mediaPaths.length > 1
                ? _buildMediaWidget(mediaPaths[1], folderNum, fit: BoxFit.cover)
                : Container(color: Colors.grey),
          ),
        ],
      );
    } else if (template == 'kural-overlay') {
      final overlay = (slide['overlay'] as Map<String, dynamic>?) ?? {};
      final align = _toAlignment((overlay['align'] ?? 'center') as String);

      final dxPctRaw = overlay['dxPct'] as num?;
      final dyPctRaw = overlay['dyPct'] as num?;
      final dxAbs = ((overlay['dx'] ?? 0) as num).toDouble();
      final dyAbs = ((overlay['dy'] ?? 0) as num).toDouble();
      final dx = dxPctRaw != null ? RS.sw(context, dxPctRaw.toDouble())
          : RS.dp(context, dxAbs);
      final dy = dyPctRaw != null ? RS.sh(context, dyPctRaw.toDouble())
          : RS.dp(context, dyAbs);

      final pad = RS.dp(context, ((overlay['padding'] ?? 48) as num).toDouble()); // Increased padding
      final maxWidthPct =
      ((overlay['maxWidthPct'] ?? 0.92) as num).toDouble().clamp(0.0, 1.0);
      // =================================================================
      // MODIFICATION: Increased base font size for the overlay.
      // =================================================================
      final fontSize = RS.sp(context, ((overlay['fontSize'] ?? 56) as num).toDouble());

      final color = _hexToColor((overlay['color'] ?? '#FFFFFF') as String);
      final shadow = (overlay['shadow'] ?? true) as bool;
      final textAlign =
      _toTextAlign((overlay['textAlign'] ?? 'center') as String);
      final dim = ((overlay['dim'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);


      mediaWidget = LayoutBuilder(
        builder: (context, constraints) {
          final maxW = constraints.maxWidth * maxWidthPct;
          return Stack(
            children: [
              Positioned.fill(
                child: mediaPaths.isNotEmpty
                    ? _buildMediaWidget(mediaPaths[0], folderNum, fit: BoxFit.cover)
                    : Container(color: Colors.black),
              ),
              if (dim > 0)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(color: Colors.black.withOpacity(dim)),
                  ),
                ),
              Positioned.fill(
                child: Align(
                  alignment: align,
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxW),
                      child: Padding(
                        padding: EdgeInsets.all(pad),
                        child: Text(
                          text,
                          textAlign: textAlign,
                          style: TextStyle(
                            color: color,
                            fontSize: fontSize,
                            height: 1.4, // Increased line height
                            fontWeight: FontWeight.bold, // Bolder
                            shadows: shadow
                                ? const [
                              Shadow(
                                  blurRadius: 12, // Stronger shadow
                                  color: Colors.black87,
                                  offset: Offset(2, 2)),
                            ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else if (template == 'kural-cells') {
      // Background + optional bottom gradient panel + multiple text cells
      final dim = ((slide['dim'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);
      final panelHeightPct =
      ((slide['panelHeightPct'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);
      final cells =
          (slide['cells'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

      mediaWidget = LayoutBuilder(
        builder: (context, constraints) {
          final List<Widget> children = [];

          // Background image
          children.add(
            Positioned.fill(
              child: mediaPaths.isNotEmpty
                  ? _buildMediaWidget(mediaPaths[0], folderNum, fit: BoxFit.cover)
                  : Container(color: Colors.black),
            ),
          );

          // Optional: full-screen dim instead of gradient
          if (dim > 0) {
            children.add(Positioned.fill(
                child: IgnorePointer(
                    child: Container(color: Colors.black.withOpacity(dim))
                )
            ));
          }

          // Text cells
          for (final cell in cells) {
            final txt = (cell['text'] ?? '').toString();
            if (txt.trim().isEmpty) continue;

            final align = _toAlignment((cell['align'] ?? 'center') as String);

            final dxPctRaw = cell['dxPct'] as num?;
            final dyPctRaw = cell['dyPct'] as num?;
            final dxAbs = ((cell['dx'] ?? 0) as num).toDouble();
            final dyAbs = ((cell['dy'] ?? 0) as num).toDouble();
            final dx = dxPctRaw != null ? RS.sw(context, dxPctRaw.toDouble())
                : RS.dp(context, dxAbs);
            final dy = dyPctRaw != null ? RS.sh(context, dyPctRaw.toDouble())
                : RS.dp(context, dyAbs);

            final widthPx = (cell['width'] as num?)?.toDouble();
            final widthPct = ((cell['widthPct'] ?? cell['maxWidthPct'] ?? 1.0) as num)
                .toDouble()
                .clamp(0.0, 1.0);
            final heightPx = (cell['height'] as num?)?.toDouble();
            final heightPct =
            ((cell['heightPct'] ?? 0.0) as num).toDouble().clamp(0.0, 1.0);

            final w = widthPx ?? (constraints.maxWidth * widthPct);
            final h = heightPx ?? (heightPct > 0 ? constraints.maxHeight * heightPct : null);

            final pad = RS.dp(context, ((cell['padding'] ?? 16) as num).toDouble());
            // Font sizes are now taken directly from the map, allowing per-cell control.
            // The values were increased in the _maybeInjectThirukuralSlide method.
            final fontSize = RS.sp(context, ((cell['fontSize'] ?? 28) as num).toDouble());

            final weight = _toFontWeight(cell['weight']);
            final color = _hexToColor((cell['color'] ?? '#FFFFFF') as String);
            final shadow = (cell['shadow'] ?? true) as bool;
            final textAlign = _toTextAlign((cell['textAlign'] ?? 'center') as String);
            final lineHeight = ((cell['lineHeight'] ?? 1.35) as num).toDouble();
            final maxLines = (cell['maxLines'] as int?);

            children.add(
              Positioned.fill(
                child: Align(
                  alignment: align,
                  child: Transform.translate(
                    offset: Offset(dx, dy),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: w),
                      child: SizedBox(
                        width: w,
                        height: h,
                        child: Padding(
                          padding: EdgeInsets.all(pad),
                          child: Text(
                            txt,
                            textAlign: textAlign,
                            maxLines: maxLines,
                            overflow: maxLines != null
                                ? TextOverflow.ellipsis
                                : TextOverflow.visible,
                            style: TextStyle(
                              color: color,
                              fontSize: fontSize,
                              height: lineHeight,
                              fontWeight: weight,
                              shadows: shadow
                                  ? const [
                                Shadow(
                                    blurRadius: 10,
                                    color: Colors.black87,
                                    offset: Offset(2, 2)),
                              ]
                                  : null,
                            ),
                            softWrap: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          return Stack(children: children);
        },
      );
    }    // --- Safety dashboard rendered over a background image ---
    else if (template == 'dashboard') {
      // Background image path (fallback to your asset if none provided)
      final bgPath = mediaPaths.isNotEmpty
          ? mediaPaths.first
          : 'assets/backgrounds/dashboard.png';

      // Optional: read scrolling flag if you want continuous scroll
      final scrolling = slide['scrollingText'] == true;
      final text = (slide['text'] ?? '').toString();

      // =================================================================
      // MODIFICATION: Increased font size for dashboard text.
      // =================================================================
      final textWidget = scrolling
          ? AutoScrollingText(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: RS.sp(context, 32),
          height: 1.4,
        ),
        velocity: 100,
      )
          : SingleChildScrollView(
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: RS.sp(context, 32),
            height: 1.4,
          ),
        ),
      );

      mediaWidget = Stack(
        children: [
          // Background
          Positioned.fill(
            child: _buildMediaWidget(
              bgPath,
              slide['folderNum'] ?? 0,
              fit: BoxFit.cover,
            ),
          ),
          // Right-side dark panel with stats text
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Container
                ( // panel
                width: RS.sw(context, 0.45),
                margin: EdgeInsets.all(RS.dp(context, 32)),
                padding: EdgeInsets.all(RS.dp(context, 32)),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65), // Slightly more opaque
                  borderRadius: BorderRadius.circular(24),
                ),
                child: textWidget,
              ),
            ),
          ),
        ],
      );
    }
    else {
      mediaWidget = const Center(child: Text('Unknown template'));
    }

    if (_isFullscreen) {
      return Scaffold(
        body: GestureDetector(
          onTap: _handleFullscreenToggle,
          onDoubleTap: () => Navigator.of(context).maybePop(),
          child: Container(color: Colors.black, child: mediaWidget),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kiosk Slideshow'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Go to Calendar',
            onPressed: () async {
              await _cancelSlideshow();
              if (!mounted) return;
              await Navigator.of(context).pushNamed('/calendar');
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          _autoHideTimer?.cancel();
          _autoHideTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _isFullscreen = true);
          });
        },
        child: mediaWidget,
      ),
    );
  }

  Widget _buildDirectMediaSlide(
      BuildContext context,
      Map<String, dynamic> media,
      int folderNum,
      ) {
    final String path = media['path'] as String? ?? '';

    if (_isFullscreen) {
      return Scaffold(
        backgroundColor: Colors.black, // black behind everything
        body: GestureDetector(
          onTap: _handleFullscreenToggle,
          onDoubleTap: () => Navigator.of(context).maybePop(),
          child: SizedBox.expand(
            child: _buildMediaWidget(
              path,
              folderNum,
              fit: BoxFit.cover, // Ensures image covers the entire screen
            ),
          ),
        ),
      );
    }

    // Non-fullscreen: previous layout with title etc.
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kiosk Slideshow"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Go to Calendar',
            onPressed: () async {
              await _cancelSlideshow();
              if (!mounted) return;
              await Navigator.of(context).pushNamed('/calendar');
            },
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () {
          _autoHideTimer?.cancel();
          _autoHideTimer = Timer(const Duration(seconds: 5), () {
            if (mounted) setState(() => _isFullscreen = true);
          });
        },
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(24.0), // Increased padding
                  child: _buildMediaWidget(path, folderNum, fit: BoxFit.contain), // Shows full image
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Text(
                  media['name'] ?? '',
                  style: TextStyle(fontSize: RS.sp(context, 40), fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}