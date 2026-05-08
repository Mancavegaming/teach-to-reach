import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/sermon_annotation.dart';

/// Renders sermon text + ink overlay to a PNG. Used to feed annotations into
/// Claude's vision endpoint.
///
/// Layout matches `InkCanvas` exactly: 40px horizontal padding, 32px top,
/// 80px bottom, 22pt body text at line height 1.55, content centered with
/// max width 900. Strokes are positioned by the same normalized coordinates
/// they were captured with, so they overlay the text in the same place the
/// user saw on screen.
class AnnotationRenderer {
  static const double _hPadding = 40;
  static const double _topPadding = 32;
  static const double _bottomPadding = 80;
  static const double _maxContentWidth = 900;
  static const double _fontSize = 22;
  static const double _lineHeight = 1.55;

  /// Renders to a PNG. [pixelRatio] controls output resolution; 2.0 is a good
  /// balance of legibility and file size for vision input.
  static Future<Uint8List> render({
    required String text,
    required List<InkStroke> strokes,
    required double canvasWidth,
    required double canvasHeight,
    double pixelRatio = 2.0,
  }) async {
    // Bytes go to Anthropic; clamp to a reasonable max.
    const maxOutputWidth = 1568.0;
    final scale =
        canvasWidth * pixelRatio > maxOutputWidth ? maxOutputWidth / canvasWidth : pixelRatio;
    final outW = canvasWidth * scale;
    final outH = canvasHeight * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // White page so handwriting reads clearly.
    canvas.drawRect(
      Rect.fromLTWH(0, 0, outW, outH),
      Paint()..color = Colors.white,
    );

    // Sermon text — match InkCanvas layout pixel-for-pixel.
    final usableContentWidth = (canvasWidth - _hPadding * 2).clamp(0, _maxContentWidth);
    final textBlockWidth = usableContentWidth.toDouble() * scale;
    final textLeft = ((canvasWidth - usableContentWidth) / 2).clamp(_hPadding, double.infinity) *
        scale;

    final paragraphStyle = ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      fontSize: _fontSize * scale,
      height: _lineHeight,
    );
    final paragraphBuilder = ui.ParagraphBuilder(paragraphStyle)
      ..pushStyle(ui.TextStyle(
        color: const Color(0xFF111111),
        fontSize: _fontSize * scale,
        height: _lineHeight,
      ))
      ..addText(text);
    final paragraph = paragraphBuilder.build()
      ..layout(ui.ParagraphConstraints(width: textBlockWidth));
    canvas.drawParagraph(paragraph, Offset(textLeft, _topPadding * scale));

    // Ink strokes on top — positions are normalized to (0..1, 0..1) of the
    // capture-time canvas, so multiply by current output dims.
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = (stroke.widthFactor * scale).clamp(1.0, 14.0);

      if (stroke.points.length == 1) {
        final p = stroke.points.first;
        canvas.drawCircle(
          Offset(p.x * outW, p.y * outH),
          (stroke.widthFactor * scale * (p.pressure == 0 ? 1 : p.pressure)).clamp(1.0, 14.0),
          Paint()..color = stroke.color,
        );
        continue;
      }

      final path = Path();
      final first = stroke.points.first;
      path.moveTo(first.x * outW, first.y * outH);
      for (var i = 1; i < stroke.points.length; i++) {
        final p = stroke.points[i];
        path.lineTo(p.x * outW, p.y * outH);
      }
      canvas.drawPath(path, paint);
    }

    // Suppress unused-warning helper — kept for future when we render bottom
    // markers/footers explicitly.
    _ignore(_bottomPadding);

    final picture = recorder.endRecording();
    final image = await picture.toImage(outW.round(), outH.round());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  static void _ignore(Object? _) {}
}
