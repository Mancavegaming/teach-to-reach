import 'package:cloud_firestore/cloud_firestore.dart';

class DoctrinalPositions {
  final String ownerId;
  final String coreTradition;
  final bool continuationist;
  final bool gospelCentered;
  final String preferredTranslation;
  final List<String> nonNegotiables;
  final List<String> pastoralEmphases;
  final List<String> avoidanceList;
  final String additionalNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  DoctrinalPositions({
    required this.ownerId,
    this.coreTradition = 'Baptist + Pentecostal/Charismatic',
    this.continuationist = true,
    this.gospelCentered = true,
    this.preferredTranslation = 'KJV',
    this.nonNegotiables = defaultNonNegotiables,
    this.pastoralEmphases = defaultPastoralEmphases,
    this.avoidanceList = defaultAvoidanceList,
    this.additionalNotes = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  static const List<String> defaultNonNegotiables = [
    'Inerrancy and inspiration of Scripture',
    'Trinity: one God in three persons',
    'Deity and bodily resurrection of Jesus Christ',
    'Salvation by grace through faith in Christ alone',
    'Bodily second coming of Christ',
  ];

  static const List<String> defaultPastoralEmphases = [
    'Believer\'s baptism by immersion',
    'Holy Spirit baptism and filling',
    'Spiritual gifts active for today',
    'Personal evangelism and disciple-making',
    'Prayer and dependence on the Holy Spirit',
  ];

  static const List<String> defaultAvoidanceList = [
    'Cessationism (do not teach gifts have ceased)',
    'Universalism or pluralism',
    'Prosperity gospel framing',
    'Critical/secular framing of biblical texts as myth',
    'Watering down sin or the call to repentance',
  ];

  factory DoctrinalPositions.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DoctrinalPositions(
      ownerId: data['ownerId'] ?? doc.id,
      coreTradition:
          data['coreTradition'] ?? 'Baptist + Pentecostal/Charismatic',
      continuationist: data['continuationist'] ?? true,
      gospelCentered: data['gospelCentered'] ?? true,
      preferredTranslation: data['preferredTranslation'] ?? 'KJV',
      nonNegotiables: List<String>.from(
          data['nonNegotiables'] ?? defaultNonNegotiables),
      pastoralEmphases: List<String>.from(
          data['pastoralEmphases'] ?? defaultPastoralEmphases),
      avoidanceList:
          List<String>.from(data['avoidanceList'] ?? defaultAvoidanceList),
      additionalNotes: data['additionalNotes'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ownerId': ownerId,
        'coreTradition': coreTradition,
        'continuationist': continuationist,
        'gospelCentered': gospelCentered,
        'preferredTranslation': preferredTranslation,
        'nonNegotiables': nonNegotiables,
        'pastoralEmphases': pastoralEmphases,
        'avoidanceList': avoidanceList,
        'additionalNotes': additionalNotes,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      };

  DoctrinalPositions copyWith({
    String? coreTradition,
    bool? continuationist,
    bool? gospelCentered,
    String? preferredTranslation,
    List<String>? nonNegotiables,
    List<String>? pastoralEmphases,
    List<String>? avoidanceList,
    String? additionalNotes,
  }) {
    return DoctrinalPositions(
      ownerId: ownerId,
      coreTradition: coreTradition ?? this.coreTradition,
      continuationist: continuationist ?? this.continuationist,
      gospelCentered: gospelCentered ?? this.gospelCentered,
      preferredTranslation: preferredTranslation ?? this.preferredTranslation,
      nonNegotiables: nonNegotiables ?? this.nonNegotiables,
      pastoralEmphases: pastoralEmphases ?? this.pastoralEmphases,
      avoidanceList: avoidanceList ?? this.avoidanceList,
      additionalNotes: additionalNotes ?? this.additionalNotes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}
