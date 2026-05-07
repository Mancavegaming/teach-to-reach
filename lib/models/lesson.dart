import 'package:cloud_firestore/cloud_firestore.dart';

class Lesson {
  final String? id;
  final String ownerId;
  final String seriesId;
  final String title;
  final String scriptureReference;
  final String summary;
  final String bigIdea;
  final String finalizedSermonText;
  final int targetDurationMinutes;
  final bool isFinalized;
  final DateTime createdAt;
  final DateTime updatedAt;

  Lesson({
    this.id,
    required this.ownerId,
    required this.seriesId,
    required this.title,
    this.scriptureReference = '',
    this.summary = '',
    this.bigIdea = '',
    this.finalizedSermonText = '',
    this.targetDurationMinutes = 30,
    this.isFinalized = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Lesson.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Lesson(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      seriesId: data['seriesId'] ?? '',
      title: data['title'] ?? '',
      scriptureReference: data['scriptureReference'] ?? '',
      summary: data['summary'] ?? '',
      bigIdea: data['bigIdea'] ?? '',
      finalizedSermonText: data['finalizedSermonText'] ?? '',
      targetDurationMinutes: data['targetDurationMinutes'] ?? 30,
      isFinalized: data['isFinalized'] ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'seriesId': seriesId,
        'title': title,
        'scriptureReference': scriptureReference,
        'summary': summary,
        'bigIdea': bigIdea,
        'finalizedSermonText': finalizedSermonText,
        'targetDurationMinutes': targetDurationMinutes,
        'isFinalized': isFinalized,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  Lesson copyWith({
    String? id,
    String? title,
    String? scriptureReference,
    String? summary,
    String? bigIdea,
    String? finalizedSermonText,
    int? targetDurationMinutes,
    bool? isFinalized,
  }) {
    return Lesson(
      id: id ?? this.id,
      ownerId: ownerId,
      seriesId: seriesId,
      title: title ?? this.title,
      scriptureReference: scriptureReference ?? this.scriptureReference,
      summary: summary ?? this.summary,
      bigIdea: bigIdea ?? this.bigIdea,
      finalizedSermonText: finalizedSermonText ?? this.finalizedSermonText,
      targetDurationMinutes: targetDurationMinutes ?? this.targetDurationMinutes,
      isFinalized: isFinalized ?? this.isFinalized,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
