import 'package:cloud_firestore/cloud_firestore.dart';

class ClassProfile {
  final String ownerId;
  final String className;
  final int ageRangeMin;
  final int ageRangeMax;
  final int typicalAttendance;
  final String spiritualMaturityNotes;
  final String knownChallenges;
  final String culturalContext;
  final DateTime createdAt;
  final DateTime updatedAt;

  ClassProfile({
    required this.ownerId,
    this.className = '',
    this.ageRangeMin = 11,
    this.ageRangeMax = 18,
    this.typicalAttendance = 0,
    this.spiritualMaturityNotes = '',
    this.knownChallenges = '',
    this.culturalContext = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory ClassProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ClassProfile(
      ownerId: data['ownerId'] ?? doc.id,
      className: data['className'] ?? '',
      ageRangeMin: data['ageRangeMin'] ?? 11,
      ageRangeMax: data['ageRangeMax'] ?? 18,
      typicalAttendance: data['typicalAttendance'] ?? 0,
      spiritualMaturityNotes: data['spiritualMaturityNotes'] ?? '',
      knownChallenges: data['knownChallenges'] ?? '',
      culturalContext: data['culturalContext'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'className': className,
        'ageRangeMin': ageRangeMin,
        'ageRangeMax': ageRangeMax,
        'typicalAttendance': typicalAttendance,
        'spiritualMaturityNotes': spiritualMaturityNotes,
        'knownChallenges': knownChallenges,
        'culturalContext': culturalContext,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  ClassProfile copyWith({
    String? className,
    int? ageRangeMin,
    int? ageRangeMax,
    int? typicalAttendance,
    String? spiritualMaturityNotes,
    String? knownChallenges,
    String? culturalContext,
  }) {
    return ClassProfile(
      ownerId: ownerId,
      className: className ?? this.className,
      ageRangeMin: ageRangeMin ?? this.ageRangeMin,
      ageRangeMax: ageRangeMax ?? this.ageRangeMax,
      typicalAttendance: typicalAttendance ?? this.typicalAttendance,
      spiritualMaturityNotes:
          spiritualMaturityNotes ?? this.spiritualMaturityNotes,
      knownChallenges: knownChallenges ?? this.knownChallenges,
      culturalContext: culturalContext ?? this.culturalContext,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
