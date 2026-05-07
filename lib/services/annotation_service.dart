import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/sermon_annotation.dart';

class AnnotationService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<SermonAnnotation>> _byLesson = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Returns the list of annotations for [lessonId], newest version first.
  List<SermonAnnotation> versionsFor(String lessonId) =>
      List.unmodifiable(_byLesson[lessonId] ?? const []);

  SermonAnnotation? latestFor(String lessonId) {
    final list = _byLesson[lessonId];
    return (list == null || list.isEmpty) ? null : list.first;
  }

  CollectionReference get _collection =>
      _firestore.collection('sermon_annotations');

  Future<void> loadForLesson(String ownerId, String lessonId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _collection
          .where('ownerId', isEqualTo: ownerId)
          .where('lessonId', isEqualTo: lessonId)
          .limit(50)
          .get();
      final list =
          snap.docs.map((d) => SermonAnnotation.fromFirestore(d)).toList();
      list.sort((a, b) => b.version.compareTo(a.version));
      _byLesson[lessonId] = list;
    } catch (e) {
      debugPrint('Error loading annotations: $e');
      _error = 'Failed to load annotations';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Saves [annotation] as a new version. The version number is computed as
  /// (current max for that lesson) + 1.
  Future<String?> saveNewVersion(SermonAnnotation annotation) async {
    try {
      final existing = _byLesson[annotation.lessonId] ?? const [];
      final nextVersion = existing.isEmpty
          ? 1
          : existing.map((a) => a.version).reduce((a, b) => a > b ? a : b) + 1;
      final toWrite = SermonAnnotation(
        ownerId: annotation.ownerId,
        lessonId: annotation.lessonId,
        version: nextVersion,
        canvasWidth: annotation.canvasWidth,
        canvasHeight: annotation.canvasHeight,
        strokes: annotation.strokes,
      );
      final ref = await _collection.add(toWrite.toMap());
      final saved = SermonAnnotation(
        id: ref.id,
        ownerId: toWrite.ownerId,
        lessonId: toWrite.lessonId,
        version: toWrite.version,
        canvasWidth: toWrite.canvasWidth,
        canvasHeight: toWrite.canvasHeight,
        strokes: toWrite.strokes,
        createdAt: toWrite.createdAt,
      );
      final list = _byLesson.putIfAbsent(annotation.lessonId, () => []);
      list.insert(0, saved);
      notifyListeners();
      return ref.id;
    } catch (e) {
      debugPrint('Error saving annotation: $e');
      _error = 'Failed to save annotation';
      notifyListeners();
      return null;
    }
  }

  Future<bool> delete(String annotationId, String lessonId) async {
    try {
      await _collection.doc(annotationId).delete();
      _byLesson[lessonId]?.removeWhere((a) => a.id == annotationId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting annotation: $e');
      return false;
    }
  }

  void clear() {
    _byLesson.clear();
    _error = null;
    notifyListeners();
  }
}
