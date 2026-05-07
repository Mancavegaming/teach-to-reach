import 'package:cloud_firestore/cloud_firestore.dart';

enum VoiceContentType {
  sermon('Sermon'),
  lesson('Lesson'),
  devotional('Devotional'),
  blogPost('Blog post'),
  other('Other');

  final String displayName;
  const VoiceContentType(this.displayName);

  static VoiceContentType fromString(String? value) {
    if (value == null) return VoiceContentType.other;
    return VoiceContentType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => VoiceContentType.other,
    );
  }
}

class VoiceCorpusItem {
  final String? id;
  final String ownerId;
  final String title;
  final VoiceContentType contentType;
  final String bodyText;
  final DateTime? originalDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  VoiceCorpusItem({
    this.id,
    required this.ownerId,
    required this.title,
    this.contentType = VoiceContentType.sermon,
    this.bodyText = '',
    this.originalDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get wordCount =>
      bodyText.trim().isEmpty ? 0 : bodyText.trim().split(RegExp(r'\s+')).length;

  factory VoiceCorpusItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VoiceCorpusItem(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      contentType: VoiceContentType.fromString(data['contentType'] as String?),
      bodyText: data['bodyText'] ?? '',
      originalDate: (data['originalDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'title': title,
        'contentType': contentType.name,
        'bodyText': bodyText,
        'originalDate':
            originalDate != null ? Timestamp.fromDate(originalDate!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  VoiceCorpusItem copyWith({
    String? id,
    String? title,
    VoiceContentType? contentType,
    String? bodyText,
    DateTime? originalDate,
  }) {
    return VoiceCorpusItem(
      id: id ?? this.id,
      ownerId: ownerId,
      title: title ?? this.title,
      contentType: contentType ?? this.contentType,
      bodyText: bodyText ?? this.bodyText,
      originalDate: originalDate ?? this.originalDate,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
