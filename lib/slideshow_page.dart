import 'dart:async';
import 'package:flutter/material.dart';

class SlideshowPage extends StatefulWidget {
  final List<Map<String, dynamic>> slidesOrImages;
  // Each item can be either:
  // - Direct image: { "path": ..., "duration_seconds": ... }
  // - Slide: {
  //     "template": ..., "mediaPaths": [...], "text": ..., "scrollingText": bool,
  //     "durations": {path: duration, ...}
  //   }
  const SlideshowPage({super.key, required this.slidesOrImages});

  @override
  State<SlideshowPage> createState() => _SlideshowPageState();
}

class _SlideshowPageState extends State<SlideshowPage> {
  int _currentIndex = 0;
  bool _isFullscreen = false;
  Timer? _autoHideTimer;

  bool isTemplateItem(Map<String, dynamic> item) {
    return item.containsKey('template');
  }

  @override
  void initState() {
    super.initState();
    if (widget.slidesOrImages.isNotEmpty) {
      // Go fullscreen after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _isFullscreen = true;
          });
        }
      });
      _startSlideshow();
    }
  }

  void _startSlideshow() async {
    await Future.delayed(const Duration(seconds: 5));
    while (mounted && widget.slidesOrImages.isNotEmpty) {
      final currentItem = widget.slidesOrImages[_currentIndex];
      int durationSeconds = 5;

      if (isTemplateItem(currentItem)) {
        final durationsMap =
            currentItem['durations'] as Map<String, dynamic>? ?? {};
        if (durationsMap.isNotEmpty) {
          durationSeconds = durationsMap.values
              .map((v) => v as int)
              .reduce((a, b) => a > b ? a : b);
        }

        print(
          'Displaying Slide #$_currentIndex [Template Slide]: '
              'template=${currentItem['template']}, '
              'text="${currentItem['text']}", '
              'mediaPaths=${currentItem['mediaPaths']}',
        );

      } else {
        durationSeconds = currentItem['duration_seconds'] ?? 5;

        print(
          'Displaying Image #$_currentIndex [Direct Image]: '
              'path=${currentItem['path']}, '
              'name=${currentItem['name'] ?? ''}, '
              'duration=$durationSeconds',
        );
      }

      await Future.delayed(Duration(seconds: durationSeconds));
      if (!mounted) break;

      setState(() {
        _currentIndex = (_currentIndex + 1) % widget.slidesOrImages.length;
      });
    }
  }

  void _handleFullscreenToggle() {
    setState(() {
      _isFullscreen = false;
    });
    _autoHideTimer?.cancel();
    _autoHideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isFullscreen = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _autoHideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.slidesOrImages.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Kiosk Slideshow")),
        body: const Center(child: Text('No images for today.')),
      );
    }

    final currentItem = widget.slidesOrImages[_currentIndex];
    if (isTemplateItem(currentItem)) {
      return _buildTemplateSlide(context, currentItem);
    } else {
      return _buildDirectImageSlide(context, currentItem);
    }
  }

  Widget _buildTemplateSlide(BuildContext context, Map<String, dynamic> slide) {
    final template = slide['template'] as String? ?? '';
    final mediaPaths = (slide['mediaPaths'] as List<dynamic>?)?.cast<String>() ?? [];
    final text = slide['text'] as String? ?? '';
    final scrolling = slide['scrollingText'] as bool? ?? false;

    Widget mediaWidget;
    if (template == '70image30text' || template == '70image30scrolltext') {
      // One media, large top + text bottom with constrained height
      mediaWidget = SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            Expanded(
              flex: 7,
              child: mediaPaths.isNotEmpty
                  ? Image.asset(mediaPaths[0],
                  fit: BoxFit.cover, width: double.infinity)
                  : Container(color: Colors.grey),
            ),
            Expanded(
              flex: 3,
              child: Container(
                color: Colors.black87,
                padding: const EdgeInsets.all(16),
                width: double.infinity,
                child: scrolling
                    ? SingleChildScrollView(
                  child: Text(text,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18)),
                )
                    : Text(text,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 18)),
              ),
            ),
          ],
        ),
      );
    } else if (template == 'image-image' || template == 'video-image') {
      // Two media side by side
      mediaWidget = Row(
        children: [
          Expanded(
            child: mediaPaths.isNotEmpty
                ? Image.asset(mediaPaths[0], fit: BoxFit.cover)
                : Container(color: Colors.grey),
          ),
          Expanded(
            child: mediaPaths.length > 1
                ? Image.asset(mediaPaths[1], fit: BoxFit.cover)
                : Container(color: Colors.grey),
          ),
        ],
      );
    } else {
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
            onPressed: () {
              Navigator.of(context).pushNamed('/calendar');
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

  Widget _buildDirectImageSlide(BuildContext context, Map<String, dynamic> img) {
    if (_isFullscreen) {
      return Scaffold(
        body: GestureDetector(
          onTap: _handleFullscreenToggle,
          onDoubleTap: () => Navigator.of(context).maybePop(),
          child: Container(
            color: Colors.black,
            alignment: Alignment.center,
            child: Image.asset(
              img['path'] ?? '',
              fit: BoxFit.contain,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, color: Colors.white, size: 120),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kiosk Slideshow"),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Go to Calendar',
            onPressed: () {
              Navigator.of(context).pushNamed('/calendar');
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
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    img['path'] ?? '',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                    const Icon(Icons.broken_image, size: 120),
                  ),
                ),
              ),
              Text(
                img['name'] ?? '',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
