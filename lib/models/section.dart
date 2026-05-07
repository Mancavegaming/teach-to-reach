import 'package:cloud_firestore/cloud_firestore.dart';

class Section {
  final String? id;
  final String ownerId;
  final String lessonId;
  final int order;
  final String title;
  final String content;
  final String speakerNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Section({
    this.id,
    required this.ownerId,
    required this.lessonId,
    required this.order,
    this.title = '',
    this.content = '',
    this.speakerNotes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Section.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Section(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      lessonId: data['lessonId'] ?? '',
      order: data['order'] ?? 0,
      title: data['title'] ?? '',
      content: data['content'] ?? '',
      speakerNotes: data['speakerNotes'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'lessonId': lessonId,
        'order': order,
        'title': title,
        'content': content,
        'speakerNotes': speakerNotes,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  Section copyWith({
    String? id,
    int? order,
    String? title,
    String? content,
    String? speakerNotes,
  }) {
    return Section(
      id: id ?? this.id,
      ownerId: ownerId,
      lessonId: lessonId,
      order: order ?? this.order,
      title: title ?? this.title,
      content: content ?? this.content,
      speakerNotes: speakerNotes ?? this.speakerNotes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
