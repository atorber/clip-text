class Transcript {
  final String id;
  final String recordingId;
  final String text;
  final DateTime createdAt;

  Transcript({
    required this.id,
    required this.recordingId,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recordingId': recordingId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Transcript.fromMap(Map<String, dynamic> map) {
    return Transcript(
      id: map['id'],
      recordingId: map['recordingId'],
      text: map['text'],
      createdAt: DateTime.parse(map['createdAt']),
    );
  }
} 