class Recording {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final String? sourceApp; // 录音来源App包名或名称

  Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    this.sourceApp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'sourceApp': sourceApp,
    };
  }

  factory Recording.fromMap(Map<String, dynamic> map) {
    return Recording(
      id: map['id'],
      filePath: map['filePath'],
      createdAt: DateTime.parse(map['createdAt']),
      sourceApp: map['sourceApp'],
    );
  }
} 