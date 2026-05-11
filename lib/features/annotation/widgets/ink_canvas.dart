import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/sermon_annotation.dart';

/// A vertically-scrollable canvas: displays sermon text underneath an ink
/// overlay. In pen mode the outer Listener captures every pointer (including
/// Apple Pencil, which iPadOS otherwise routes to the scroll view's gesture
/// recognizers before any inner widget can see it).
class InkCanvas extends StatefulWidget {
  final String text;
  final List<InkStroke> strokes;
  final Color inkColor;
  final bool penMode;
  final ValueChanged<InkStroke> onStrokeFinished;
  final ValueChanged<Size> onCanvasSizeChanged;

  const InkCanvas({
    super.key,
    required this.text,
    required this.strokes,
    required this.inkColor,
    required this.penMode,
    required this.onStrokeFinished,
    required this.onCanvasSizeChanged,
  });

  @override
  State<InkCanvas> createState() => _InkCanvasState();
}

class _InkCanvasState extends State<InkCanvas> {
  final List<StrokePoint> _currentPoints = [];
  final ScrollController _scrollController = ScrollController();
  Size? _contentSize;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.penMode || _contentSize == null) return;
    setState(() {
      _currentPoints
        ..clear()
        ..add(_normalize(e.localPosition, e.pressure));
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.penMode || _currentPoints.isEmpty) return;
    setState(() {
      _currentPoints.add(_normalize(e.localPosition, e.pressure));
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!widget.penMode || _currentPoints.isEmpty) return;
    final stroke = InkStroke(
      color: widget.inkColor,
      widthFactor: 2.6,
      points: List.of(_currentPoints),
    );
    setState(_currentPoints.clear);
    widget.onStrokeFinished(stroke);
  }

  /// Converts a viewport-local pointer position into content-space normalized
  /// coordinates (0..1 of the full scrollable content).
  StrokePoint _normalize(Offset viewportPos, double pressure) {
    final size = _contentSize ?? const Size(1, 1);
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    final contentY = viewportPos.dy + scrollOffset;
    return StrokePoint(
      viewportPos.dx / size.width,
      contentY / size.height,
      pressure == 0 ? 1.0 : pressure,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, viewportConstraints) {
        return Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: widget.penMode ? _onPointerDown : null,
          onPointerMove: widget.penMode ? _onPointerMove : null,
          onPointerUp: widget.penMode ? _onPointerUp : null,
          onPointerCancel: widget.penMode
              ? (_) => setState(_currentPoints.clear)
              : null,
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: widget.penMode
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
              child: _MeasuredContent(
                onSize: (size) {
                  if (_contentSize == null ||
                      (size.width - _contentSize!.width).abs() > 1 ||
                      (size.height - _contentSize!.height).abs() > 1) {
                    _contentSize = size;
                    widget.onCanvasSizeChanged(size);
                  }
                },
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(40, 32, 40, 80),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 900),
                          child: Text(
                            widget.text,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              height: 1.55,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedBuilder(
                          animation: _scrollController,
                          builder: (context, _) {
                            return CustomPaint(
                              painter: _InkPainter(
                                strokes: widget.strokes,
                                inProgress: _currentPoints,
                                inProgressColor: widget.inkColor,
                                inProgressWidth: 2.6,
                                contentSize:
                                    _contentSize ?? const Size(1, 1),
                                scrollOffset: _scrollController.hasClients
                                    ? _scrollController.offset
                                    : 0.0,
                              ),
                              size: Size.infinite,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MeasuredContent extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSize;
  const _MeasuredContent({required this.child, required this.onSize});

  @override
  State<_MeasuredContent> createState() => _MeasuredContentState();
}

class _MeasuredContentState extends State<_MeasuredContent> {
  final GlobalKey _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _key.currentContext;
      if (ctx == null) return;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box != null && box.hasSize) {
        widget.onSize(box.size);
      }
    });
    return KeyedSubtree(key: _key, child: widget.child);
  }
}

class _InkPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final List<StrokePoint> inProgress;
  final Color inProgressColor;
  final double inProgressWidth;
  final Size contentSize;
  final double scrollOffset;

  _InkPainter({
    required this.strokes,
    required this.inProgress,
    required this.inProgressColor,
    required this.inProgressWidth,
    required this.contentSize,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // The painter sits inside the scroll content (via Positioned.fill in the
    // Stack), so its origin already moves with scroll. But because we draw
    // here based on the viewport-anchored Listener, the painter is actually
    // the SAME size as the content (Stack child of Positioned.fill fills the
    // Stack). Stroke points are normalized in content-space, so we render
    // directly against `contentSize` without applying scrollOffset — the
    // CustomPaint translates with the content automatically.
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke.points, stroke.color, stroke.widthFactor);
    }
    if (inProgress.isNotEmpty) {
      _drawStroke(canvas, inProgress, inProgressColor, inProgressWidth);
    }
  }

  void _drawStroke(
    Canvas canvas,
    List<StrokePoint> points,
    Color color,
    double widthFactor,
  ) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      final p = points.first;
      final paint = Paint()..color = color;
      canvas.drawCircle(
        Offset(p.x * contentSize.width, p.y * contentSize.height),
        widthFactor * (p.pressure == 0 ? 1 : p.pressure),
        paint,
      );
      return;
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = widthFactor;

    final path = Path();
    final first = points.first;
    path.moveTo(first.x * contentSize.width, first.y * contentSize.height);
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      path.lineTo(p.x * contentSize.width, p.y * contentSize.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) =>
      old.strokes != strokes ||
      old.inProgress != inProgress ||
      old.inProgressColor != inProgressColor ||
      old.inProgressWidth != inProgressWidth ||
      old.contentSize != contentSize ||
      old.scrollOffset != scrollOffset;
}
