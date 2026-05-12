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
  final DateTime? scheduledDate;
  final DateTime? scheduledEndDate;
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
    this.scheduledDate,
    this.scheduledEndDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  bool get isScheduled => scheduledDate != null;
  bool get isMultiWeek => scheduledEndDate != null;

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
      scheduledDate: (data['scheduledDate'] as Timestamp?)?.toDate(),
      scheduledEndDate: (data['scheduledEndDate'] as Timestamp?)?.toDate(),
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
        'scheduledDate':
            scheduledDate == null ? null : Timestamp.fromDate(scheduledDate!),
        'scheduledEndDate': scheduledEndDate == null
            ? null
            : Timestamp.fromDate(scheduledEndDate!),
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
    Object? scheduledDate = _sentinel,
    Object? scheduledEndDate = _sentinel,
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
      scheduledDate: identical(scheduledDate, _sentinel)
          ? this.scheduledDate
          : scheduledDate as DateTime?,
      scheduledEndDate: identical(scheduledEndDate, _sentinel)
          ? this.scheduledEndDate
          : scheduledEndDate as DateTime?,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  static const Object _sentinel = Object();
}
