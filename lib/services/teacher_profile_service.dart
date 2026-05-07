import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/teacher_profile.dart';

class TeacherProfileService extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  TeacherProfile? _profile;
  bool _isLoading = false;
  String? _error;

  TeacherProfile? get profile => _profile;
  bool get isLoading => _isLoading;
  String? get error => _error;

  CollectionReference get _collection =>
      _firestore.collection('teacher_profiles');

  Future<TeacherProfile> loadOrCreate(String ownerId,
      {String? email, String? displayName}) async {
    _isLoading = true;
    notifyListeners();
    try {
      final doc = await _collection.doc(ownerId).get();
      if (doc.exists) {
        _profile = TeacherProfile.fromFirestore(doc);
      } else {
        final fresh = TeacherProfile(
          ownerId: ownerId,
          email: email ?? '',
          displayName: displayName ?? '',
        );
        await _collection.doc(ownerId).set(fresh.toMap());
        _profile = fresh;
      }
    } catch (e) {
      debugPrint('Error loading teacher profile: $e');
      _error = 'Failed to load teacher profile';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return _profile!;
  }

  Future<bool> save(TeacherProfile profile) async {
    try {
      await _collection.doc(profile.ownerId).set(profile.toMap());
      _profile = profile;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving teacher profile: $e');
      return false;
    }
  }

  void clear() {
    _profile = null;
    _error = null;
    notifyListeners();
  }
}
