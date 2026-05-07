import 'package:cloud_firestore/cloud_firestore.dart';

class Series {
  final String? id;
  final String ownerId;
  final String title;
  final String description;
  final String ageGroup;
  final String targetAudience;
  final DateTime createdAt;
  final DateTime updatedAt;

  Series({
    this.id,
    required this.ownerId,
    required this.title,
    this.description = '',
    this.ageGroup = '6th-12th grade',
    this.targetAudience = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Series.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Series(
      id: doc.id,
      ownerId: data['ownerId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      ageGroup: data['ageGroup'] ?? '6th-12th grade',
      targetAudience: data['targetAudience'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'title': title,
        'description': description,
        'ageGroup': ageGroup,
        'targetAudience': targetAudience,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  Series copyWith({
    String? id,
    String? title,
    String? description,
    String? ageGroup,
    String? targetAudience,
  }) {
    return Series(
      id: id ?? this.id,
      ownerId: ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      ageGroup: ageGroup ?? this.ageGroup,
      targetAudience: targetAudience ?? this.targetAudience,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
