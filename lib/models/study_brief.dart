import 'package:cloud_firestore/cloud_firestore.dart';

class StudyBrief {
  final String? id;
  final String ownerId;
  final String lessonId;
  final String content;
  final String eventHorizon;
  final String authorshipHorizon;
  final String model;
  final DateTime createdAt;
  final DateTime updatedAt;

  StudyBrief({
    this.id,
    required this.ownerId,
    required this.lessonId,
    this.content = '',
    this.eventHorizon = '',
    this.authorshipHorizon = '',
    this.model = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory StudyBrief.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StudyBrief(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      lessonId: data['lessonId'] ?? '',
      content: data['content'] ?? '',
      eventHorizon: data['eventHorizon'] ?? '',
      authorshipHorizon: data['authorshipHorizon'] ?? '',
      model: data['model'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'lessonId': lessonId,
        'content': content,
        'eventHorizon': eventHorizon,
        'authorshipHorizon': authorshipHorizon,
        'model': model,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  StudyBrief copyWith({
    String? id,
    String? content,
    String? eventHorizon,
    String? authorshipHorizon,
    String? model,
  }) {
    return StudyBrief(
      id: id ?? this.id,
      ownerId: ownerId,
      lessonId: lessonId,
      content: content ?? this.content,
      eventHorizon: eventHorizon ?? this.eventHorizon,
      authorshipHorizon: authorshipHorizon ?? this.authorshipHorizon,
      model: model ?? this.model,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
