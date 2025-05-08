import 'package:path_provider/path_provider.dart';
import 'package:system_audio_recorder/system_audio_recorder.dart';

class Recording {
  final String id;
  final String filePath;
  final DateTime createdAt;
  final int size;
  final String? sourceApp; // 录音来源App包名或名称

  Recording({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.size,
    this.sourceApp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'size': size,
      'sourceApp': sourceApp,
    };
  }

  factory Recording.fromPluginMap(Map<String, dynamic> map) {
    return Recording(
      id: map['name'],
      filePath: map['name'],
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['lastModified']),
      size: map['size'] ?? 0,
      sourceApp: null,
    );
  }

  factory Recording.fromMap(Map<String, dynamic> map) {
    return Recording(
      id: map['id'],
      filePath: map['filePath'],
      createdAt: DateTime.parse(map['createdAt']),
      size: map['size'] ?? 0,
      sourceApp: map['sourceApp'],
    );
  }

  static Future<List<Recording>> getAllRecordingsFromPlugin() async {
    final dir = await getTemporaryDirectory();
    final list = await SystemAudioRecorder().listRecordings();
    return list.map((e) {
      final fileName = e['name'] as String;
      final fullPath = '${dir.path}/$fileName';
      return Recording(
        id: fileName,
        filePath: fullPath,
        createdAt: DateTime.fromMillisecondsSinceEpoch(e['lastModified']),
        size: e['size'] ?? 0,
        sourceApp: null,
      );
    }).toList();
  }
} 