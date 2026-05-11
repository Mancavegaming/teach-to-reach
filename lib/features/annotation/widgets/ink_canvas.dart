import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../models/sermon_annotation.dart';

/// A vertically-scrollable canvas: displays sermon text underneath an ink
/// overlay. The Listener wraps the scroll view from the outside so Apple
/// Pencil events are claimed before iPadOS routes them to the scroll view's
/// gesture recognizers.
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
  Size? _canvasSize;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.penMode) return;
    if (e.kind != PointerDeviceKind.stylus) return;
    setState(() {
      _currentPoints
        ..clear()
        ..add(_normalize(e.localPosition, e.pressure));
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!widget.penMode || _currentPoints.isEmpty) return;
    if (e.kind != PointerDeviceKind.stylus) return;
    setState(() {
      _currentPoints.add(_normalize(e.localPosition, e.pressure));
    });
  }

  void _onPointerUp(PointerUpEvent e) {
    if (!widget.penMode || _currentPoints.isEmpty) return;
    if (e.kind != PointerDeviceKind.stylus) return;
    final stroke = InkStroke(
      color: widget.inkColor,
      widthFactor: 2.6,
      points: List.of(_currentPoints),
    );
    setState(_currentPoints.clear);
    widget.onStrokeFinished(stroke);
  }

  StrokePoint _normalize(Offset pos, double pressure) {
    final size = _canvasSize ?? const Size(1, 1);
    final scrollOffset =
        _scrollController.hasClients ? _scrollController.offset : 0.0;
    return StrokePoint(
      pos.dx / size.width,
      (pos.dy + scrollOffset) / size.height,
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
            physics: _currentPoints.isNotEmpty
                ? const NeverScrollableScrollPhysics()
                : const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: viewportConstraints.maxHeight,
              ),
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
                      child: _CanvasMeasure(
                        onSize: (size) {
                          _canvasSize = size;
                          widget.onCanvasSizeChanged(size);
                        },
                        child: CustomPaint(
                          painter: _InkPainter(
                            strokes: List.of(widget.strokes),
                            inProgress: List.of(_currentPoints),
                            inProgressColor: widget.inkColor,
                            inProgressWidth: 2.6,
                          ),
                          size: Size.infinite,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CanvasMeasure extends StatefulWidget {
  final Widget child;
  final ValueChanged<Size> onSize;
  const _CanvasMeasure({required this.child, required this.onSize});

  @override
  State<_CanvasMeasure> createState() => _CanvasMeasureState();
}

class _CanvasMeasureState extends State<_CanvasMeasure> {
  Size? _last;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final size = Size(constraints.maxWidth, constraints.maxHeight);
      if (_last != size) {
        _last = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) widget.onSize(size);
        });
      }
      return widget.child;
    });
  }
}

class _InkPainter extends CustomPainter {
  final List<InkStroke> strokes;
  final List<StrokePoint> inProgress;
  final Color inProgressColor;
  final double inProgressWidth;

  _InkPainter({
    required this.strokes,
    required this.inProgress,
    required this.inProgressColor,
    required this.inProgressWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      _drawStroke(canvas, size, stroke.points, stroke.color, stroke.widthFactor);
    }
    if (inProgress.isNotEmpty) {
      _drawStroke(canvas, size, inProgress, inProgressColor, inProgressWidth);
    }
  }

  void _drawStroke(
    Canvas canvas,
    Size size,
    List<StrokePoint> points,
    Color color,
    double widthFactor,
  ) {
    if (points.isEmpty) return;
    if (points.length == 1) {
      final p = points.first;
      final paint = Paint()..color = color;
      canvas.drawCircle(
        Offset(p.x * size.width, p.y * size.height),
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
    path.moveTo(first.x * size.width, first.y * size.height);
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      path.lineTo(p.x * size.width, p.y * size.height);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _InkPainter old) => true;
}
