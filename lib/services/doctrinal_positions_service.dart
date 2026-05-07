import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/doctrinal_positions.dart';

class DoctrinalPositionsService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DoctrinalPositions? _positions;
  bool _isLoading = false;
  String? _error;

  DoctrinalPositions? get positions => _positions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference get _collection =>
      _firestore.collection('doctrinal_positions');

  Future<DoctrinalPositions> loadOrCreate(String ownerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final doc = await _collection.doc(ownerId).get();
      if (doc.exists) {
        _positions = DoctrinalPositions.fromFirestore(doc);
      } else {
        final fresh = DoctrinalPositions(ownerId: ownerId);
        await _collection.doc(ownerId).set(fresh.toMap());
        _positions = fresh;
      }
    } catch (e) {
      debugPrint('Error loading doctrinal positions: $e');
      _error = 'Failed to load doctrinal positions';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _positions!;
  }

  Future<bool> save(DoctrinalPositions positions) async {
    try {
      await _collection.doc(positions.ownerId).set(positions.toMap());
      _positions = positions;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving doctrinal positions: $e');
      return false;
    }
  }

  void clear() {
    _positions = null;
    _error = null;
    notifyListeners();
  }
}
