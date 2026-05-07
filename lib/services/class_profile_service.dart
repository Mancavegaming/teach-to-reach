import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/class_profile.dart';

class ClassProfileService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ClassProfile? _profile;
  bool _isLoading = false;
  String? _error;

  ClassProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference get _collection =>
      _firestore.collection('class_profiles');

  Future<ClassProfile> loadOrCreate(String ownerId) async {
    _isLoading = true;
    notifyListeners();
    try {
      final doc = await _collection.doc(ownerId).get();
      if (doc.exists) {
        _profile = ClassProfile.fromFirestore(doc);
      } else {
        final fresh = ClassProfile(ownerId: ownerId);
        await _collection.doc(ownerId).set(fresh.toMap());
        _profile = fresh;
      }
    } catch (e) {
      debugPrint('Error loading class profile: $e');
      _error = 'Failed to load class profile';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _profile!;
  }

  Future<bool> save(ClassProfile profile) async {
    try {
      await _collection.doc(profile.ownerId).set(profile.toMap());
      _profile = profile;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving class profile: $e');
      return false;
    }
  }

  void clear() {
    _profile = null;
    _error = null;
    notifyListeners();
  }
}
