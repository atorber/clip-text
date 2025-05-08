import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class AudioService {
  static Future<String> getNewRecordingFilePath() async {
    final dir = await getApplicationDocumentsDirectory();
    final uuid = Uuid().v4();
    return '${dir.path}/recording_$uuid.aac'; // 可根据实际录音格式调整
  }

  static Future<void> deleteRecordingFile(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await file.delete();
    }
  }
} 