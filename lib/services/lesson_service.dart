import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/lesson.dart';
import '../models/section.dart';
import '../models/study_brief.dart';

class LessonService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, List<Lesson>> _lessonsBySeries = {};
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Lesson> lessonsFor(String seriesId) =>
      List.unmodifiable(_lessonsBySeries[seriesId] ?? const []);

  CollectionReference get _lessons => _firestore.collection('lessons');
  CollectionReference get _sections => _firestore.collection('sections');
  CollectionReference get _briefs => _firestore.collection('study_briefs');

  Future<void> loadLessonsForSeries(String ownerId, String seriesId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _lessons
          .where('ownerId', isEqualTo: ownerId)
          .where('seriesId', isEqualTo: seriesId)
          .limit(500)
          .get();
      final list = snap.docs.map((d) => Lesson.fromFirestore(d)).toList();
      list.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      _lessonsBySeries[seriesId] = list;
    } catch (e) {
      debugPrint('Error loading lessons: $e');
      _error = 'Failed to load lessons';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> createLesson(Lesson lesson) async {
    try {
      final ref = await _lessons.add(lesson.toMap());
      final saved = lesson.copyWith(id: ref.id);
      final list = _lessonsBySeries.putIfAbsent(lesson.seriesId, () => []);
      list.add(saved);
      notifyListeners();
      return ref.id;
    } catch (e) {
      debugPrint('Error creating lesson: $e');
      return null;
    }
  }

  Future<bool> updateLesson(Lesson lesson) async {
    if (lesson.id == null) return false;
    try {
      await _lessons.doc(lesson.id).update(lesson.toMap());
      final list = _lessonsBySeries[lesson.seriesId];
      if (list != null) {
        final idx = list.indexWhere((l) => l.id == lesson.id);
        if (idx >= 0) list[idx] = lesson;
      }
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating lesson: $e');
      return false;
    }
  }

  Future<bool> deleteLesson(String seriesId, String lessonId) async {
    try {
      await _lessons.doc(lessonId).delete();
      _lessonsBySeries[seriesId]?.removeWhere((l) => l.id == lessonId);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting lesson: $e');
      return false;
    }
  }

  // ---- Sections ----

  Future<List<Section>> loadSections(String ownerId, String lessonId) async {
    try {
      final snap = await _sections
          .where('ownerId', isEqualTo: ownerId)
          .where('lessonId', isEqualTo: lessonId)
          .limit(200)
          .get();
      final list = snap.docs.map((d) => Section.fromFirestore(d)).toList();
      list.sort((a, b) => a.order.compareTo(b.order));
      return list;
    } catch (e) {
      debugPrint('Error loading sections: $e');
      return [];
    }
  }

  Future<String?> createSection(Section section) async {
    try {
      final ref = await _sections.add(section.toMap());
      return ref.id;
    } catch (e) {
      debugPrint('Error creating section: $e');
      return null;
    }
  }

  Future<bool> updateSection(Section section) async {
    if (section.id == null) return false;
    try {
      await _sections.doc(section.id).update(section.toMap());
      return true;
    } catch (e) {
      debugPrint('Error updating section: $e');
      return false;
    }
  }

  Future<bool> deleteSection(String sectionId) async {
    try {
      await _sections.doc(sectionId).delete();
      return true;
    } catch (e) {
      debugPrint('Error deleting section: $e');
      return false;
    }
  }

  // ---- Study Briefs ----

  Future<StudyBrief?> loadBriefForLesson(
      String ownerId, String lessonId) async {
    try {
      final snap = await _briefs
          .where('ownerId', isEqualTo: ownerId)
          .where('lessonId', isEqualTo: lessonId)
          .limit(1)
          .get();
      if (snap.docs.isEmpty) return null;
      return StudyBrief.fromFirestore(snap.docs.first);
    } catch (e) {
      debugPrint('Error loading study brief: $e');
      return null;
    }
  }

  Future<String?> saveBrief(StudyBrief brief) async {
    try {
      if (brief.id != null) {
        await _briefs.doc(brief.id).update(brief.toMap());
        return brief.id;
      }
      final ref = await _briefs.add(brief.toMap());
      return ref.id;
    } catch (e) {
      debugPrint('Error saving study brief: $e');
      return null;
    }
  }

  void clear() {
    _lessonsBySeries.clear();
    _error = null;
    notifyListeners();
  }
}
