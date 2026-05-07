import 'package:cloud_firestore/cloud_firestore.dart';

class TeacherProfile {
  final String ownerId;
  final String displayName;
  final String email;
  final String voicePersona;
  final String preferredTranslation;
  final String pastoralBackground;
  final DateTime createdAt;
  final DateTime updatedAt;

  TeacherProfile({
    required this.ownerId,
    this.displayName = '',
    this.email = '',
    this.voicePersona = '',
    this.preferredTranslation = 'KJV',
    this.pastoralBackground = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory TeacherProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TeacherProfile(
      ownerId: data['ownerId'] ?? doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      voicePersona: data['voicePersona'] ?? '',
      preferredTranslation: data['preferredTranslation'] ?? 'KJV',
      pastoralBackground: data['pastoralBackground'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'displayName': displayName,
        'email': email,
        'voicePersona': voicePersona,
        'preferredTranslation': preferredTranslation,
        'pastoralBackground': pastoralBackground,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  TeacherProfile copyWith({
    String? displayName,
    String? email,
    String? voicePersona,
    String? preferredTranslation,
    String? pastoralBackground,
  }) {
    return TeacherProfile(
      ownerId: ownerId,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      voicePersona: voicePersona ?? this.voicePersona,
      preferredTranslation: preferredTranslation ?? this.preferredTranslation,
      pastoralBackground: pastoralBackground ?? this.pastoralBackground,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
