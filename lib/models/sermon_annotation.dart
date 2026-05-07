import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// One pen stroke on the canvas. Coordinates are normalized 0..1 within the
/// canvas size at capture time (see [SermonAnnotation.canvasWidth/Height]).
class InkStroke {
  final Color color;
  final double widthFactor;
  final List<StrokePoint> points;

  InkStroke({
    required this.color,
    this.widthFactor = 2.5,
    required this.points,
  });

  Map<String, dynamic> toMap() => {
        'color': '#${color.toARGB32().toRadixString(16).padLeft(8, '0')}',
        'widthFactor': widthFactor,
        'points': points.map((p) => p.toMap()).toList(),
      };

  factory InkStroke.fromMap(Map<String, dynamic> data) {
    final colorStr = (data['color'] as String?) ?? '#FFFF0000';
    final argb =
        int.parse(colorStr.replaceFirst('#', ''), radix: 16);
    return InkStroke(
      color: Color(argb),
      widthFactor: (data['widthFactor'] as num?)?.toDouble() ?? 2.5,
      points: (data['points'] as List<dynamic>? ?? [])
          .map((m) => StrokePoint.fromMap(m as Map<String, dynamic>))
          .toList(),
    );
  }
}

class StrokePoint {
  final double x;
  final double y;
  final double pressure;

  const StrokePoint(this.x, this.y, this.pressure);

  Map<String, dynamic> toMap() => {'x': x, 'y': y, 'p': pressure};

  factory StrokePoint.fromMap(Map<String, dynamic> data) => StrokePoint(
        (data['x'] as num).toDouble(),
        (data['y'] as num).toDouble(),
        (data['p'] as num?)?.toDouble() ?? 1.0,
      );
}

class SermonAnnotation {
  final String? id;
  final String ownerId;
  final String lessonId;
  final int version;
  final double canvasWidth;
  final double canvasHeight;
  final List<InkStroke> strokes;
  final DateTime createdAt;

  SermonAnnotation({
    this.id,
    required this.ownerId,
    required this.lessonId,
    required this.version,
    required this.canvasWidth,
    required this.canvasHeight,
    required this.strokes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  int get strokeCount => strokes.length;
  int get pointCount =>
      strokes.fold<int>(0, (acc, s) => acc + s.points.length);

  factory SermonAnnotation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SermonAnnotation(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      lessonId: data['lessonId'] ?? '',
      version: data['version'] ?? 1,
      canvasWidth: (data['canvasWidth'] as num?)?.toDouble() ?? 1.0,
      canvasHeight: (data['canvasHeight'] as num?)?.toDouble() ?? 1.0,
      strokes: (data['strokes'] as List<dynamic>? ?? [])
          .map((m) => InkStroke.fromMap(m as Map<String, dynamic>))
          .toList(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'lessonId': lessonId,
        'version': version,
        'canvasWidth': canvasWidth,
        'canvasHeight': canvasHeight,
        'strokes': strokes.map((s) => s.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
