import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../models/sermon_annotation.dart';

/// Renders sermon text + ink overlay to one or more PNG tiles for vision input.
///
/// Layout matches `InkCanvas` exactly: 40px horizontal padding, 32px top,
/// 80px bottom, 22pt body text at line height 1.55, content centered with
/// max width 900. Strokes are positioned by the same normalized coordinates
/// they were captured with, so they overlay the text in the same place the
/// user saw on screen.
///
/// For long sermons the canvas is sliced into multiple page-tiles. Each tile
/// is sized comfortably under Anthropic's per-image limits (long edge ≤ 8000
/// px, file ≤ 5 MB) and gets a "Page N of M" label baked in so Claude can
/// reassemble them in order.
class AnnotationRenderer {
  static const double _hPadding = 40;
  static const double _topPadding = 32;
  static const double _bottomPadding = 80;
  static const double _maxContentWidth = 900;
  static const double _fontSize = 22;
  static const double _lineHeight = 1.55;

  /// Renders the sermon + strokes into one or more PNG tiles, top-to-bottom.
  /// Each tile is at most [maxTileWidth] x [maxTileHeight] output pixels.
  static Future<List<Uint8List>> renderTiles({
    required String text,
    required List<InkStroke> strokes,
    required double canvasWidth,
    required double canvasHeight,
    double pixelRatio = 2.0,
    double maxTileWidth = 1568,
    double maxTileHeight = 2000,
  }) async {
    final scale = math.min(pixelRatio, maxTileWidth / canvasWidth);
    final outW = canvasWidth * scale;
    final outH = canvasHeight * scale;

    final usableContentWidth =
        (canvasWidth - _hPadding * 2).clamp(0, _maxContentWidth).toDouble();
    final textBlockWidth = usableContentWidth * scale;
    final textLeft = ((canvasWidth - usableContentWidth) / 2)
            .clamp(_hPadding, double.infinity) *
        scale;

    final paragraphStyle = ui.ParagraphStyle(
      textDirection: ui.TextDirection.ltr,
      fontSize: _fontSize * scale,
      height: _lineHeight,
    );

    final tileCount = math.max(1, (outH / maxTileHeight).ceil());
    final tiles = <Uint8List>[];

    for (var i = 0; i < tileCount; i++) {
      final tileTop = i * maxTileHeight;
      final tileBottom = math.min(tileTop + maxTileHeight, outH);
      final tileHeight = tileBottom - tileTop;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // White background.
      canvas.drawRect(
        Rect.fromLTWH(0, 0, outW, tileHeight),
        Paint()..color = Colors.white,
      );

      // Render the full content shifted so the slice [tileTop..tileBottom]
      // lands at [0..tileHeight] of the tile. Clip so only the slice paints.
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, outW, tileHeight));
      canvas.translate(0, -tileTop);

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
            (stroke.widthFactor *
                    scale *
                    (p.pressure == 0 ? 1 : p.pressure))
                .clamp(1.0, 14.0),
            Paint()..color = stroke.color,
          );
          continue;
        }

        final path = Path();
        final first = stroke.points.first;
        path.moveTo(first.x * outW, first.y * outH);
        for (var k = 1; k < stroke.points.length; k++) {
          final p = stroke.points[k];
          path.lineTo(p.x * outW, p.y * outH);
        }
        canvas.drawPath(path, paint);
      }

      canvas.restore();

      // Page label in tile-local coords (after restore).
      if (tileCount > 1) {
        final labelText = 'Page ${i + 1} of $tileCount';
        final labelStyle = ui.ParagraphStyle(
          textDirection: ui.TextDirection.ltr,
          fontSize: 18,
          textAlign: TextAlign.right,
        );
        final labelBuilder = ui.ParagraphBuilder(labelStyle)
          ..pushStyle(ui.TextStyle(
            color: const Color(0xFF888888),
            fontSize: 18,
          ))
          ..addText(labelText);
        final labelParagraph = labelBuilder.build()
          ..layout(ui.ParagraphConstraints(width: outW - 24));
        canvas.drawParagraph(labelParagraph, const Offset(12, 8));
      }

      final picture = recorder.endRecording();
      final image =
          await picture.toImage(outW.round(), tileHeight.round());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      tiles.add(byteData!.buffer.asUint8List());
    }

    _ignore(_bottomPadding);
    return tiles;
  }

  static void _ignore(Object? _) {}
}
