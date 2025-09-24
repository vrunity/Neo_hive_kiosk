import 'package:flutter/material.dart';

class ScrollingText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final double velocity; // pixels per second

  const ScrollingText({
    Key? key,
    required this.text,
    this.style,
    this.velocity = 5000.0,
  }) : super(key: key);

  @override
  _ScrollingTextState createState() => _ScrollingTextState();
}

class _ScrollingTextState extends State<ScrollingText> with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late double _textWidth;
  late double _containerWidth;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScrolling();
    });
  }

  void _startScrolling() async {
    _containerWidth = context.size!.width;

    final textPainter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style ?? DefaultTextStyle.of(context).style),
      maxLines: 1,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    _textWidth = textPainter.size.width;

    final double distance = _textWidth + _containerWidth;
    final duration = Duration(milliseconds: ((distance / widget.velocity) * 1000).toInt());

    _animationController = AnimationController(vsync: this, duration: duration);

    _animationController.addListener(() {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_animationController.value * _scrollController.position.maxScrollExtent);
      }
    });

    _animationController.repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        height: (widget.style?.fontSize ?? DefaultTextStyle.of(context).style.fontSize ?? 14) * 1.2,
        child: ListView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            Text(widget.text, style: widget.style),
            const SizedBox(width: 50), // gap between repeated text
            Text(widget.text, style: widget.style),
          ],
        ),
      ),
    );
  }
}
