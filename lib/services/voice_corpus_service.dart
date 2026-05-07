import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/voice_corpus_item.dart';

class VoiceCorpusService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<VoiceCorpusItem> _items = [];
  bool _isLoading = false;
  String? _error;

  List<VoiceCorpusItem> get items => _items;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get totalWordCount =>
      _items.fold<int>(0, (acc, entry) => acc + entry.wordCount);

  CollectionReference get _collection =>
      _firestore.collection('voice_corpus');

  Future<void> load(String ownerId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final snap = await _collection
          .where('ownerId', isEqualTo: ownerId)
          .limit(500)
          .get();
      _items = snap.docs.map((d) => VoiceCorpusItem.fromFirestore(d)).toList();
      _items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } catch (e) {
      debugPrint('Error loading voice corpus: $e');
      _error = 'Failed to load voice corpus';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> create(VoiceCorpusItem item) async {
    try {
      final ref = await _collection.add(item.toMap());
      _items.insert(0, item.copyWith(id: ref.id));
      notifyListeners();
      return ref.id;
    } catch (e) {
      debugPrint('Error creating voice item: $e');
      return null;
    }
  }

  Future<bool> update(VoiceCorpusItem item) async {
    if (item.id == null) return false;
    try {
      await _collection.doc(item.id).update(item.toMap());
      final idx = _items.indexWhere((i) => i.id == item.id);
      if (idx >= 0) _items[idx] = item;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error updating voice item: $e');
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _collection.doc(id).delete();
      _items.removeWhere((i) => i.id == id);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error deleting voice item: $e');
      return false;
    }
  }

  void clear() {
    _items = [];
    _error = null;
    notifyListeners();
  }
}
