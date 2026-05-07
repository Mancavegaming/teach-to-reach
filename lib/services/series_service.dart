import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/series.dart';

class SeriesService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Series> _series = [];
  bool _isLoading = false;
  String? _error;

  List<Series> get series => _series;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference get _collection => _firestore.collection('series');

  Future<void> load(String ownerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _collection
          .where('ownerId', isEqualTo: ownerId)
          .limit(200)
          .get();
      _series = snap.docs.map((d) => Series.fromFirestore(d)).toList();
      _series.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error loading series: $e');
      _error = 'Failed to load series';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> create(Series s) async {
    try {
      final ref = await _collection.add(s.toMap());
      _series.insert(0, s.copyWith(id: ref.id));
      notifyListeners();
      return ref.id;
    } catch (e) {
      debugPrint('Error creating series: $e');
      _error = 'Failed to create series';
      notifyListeners();
      return null;
    }
  }

  Future<bool> update(Series s) async {
    if (s.id == null) return false;
    try {
      await _collection.doc(s.id).update(s.toMap());
      final idx = _series.indexWhere((x) => x.id == s.id);
      if (idx >= 0) _series[idx] = s;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating series: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _collection.doc(id).delete();
      _series.removeWhere((s) => s.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting series: $e');
      return false;
    }
  }

  void clear() {
    _series = [];
    _error = null;
    notifyListeners();
  }
}
