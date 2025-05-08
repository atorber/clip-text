import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const String _fileName = 'recordings.json';

  // 插入一条录音记录
  static Future<void> insertRecording(Map<String, dynamic> rec) async {
    final file = await _getLocalFile();
    List<Map<String, dynamic>> recordings = await getAllRecordings();
    recordings.add(rec);
    await file.writeAsString(jsonEncode(recordings));
  }

  // 获取所有录音记录
  static Future<List<Map<String, dynamic>>> getAllRecordings() async {
    try {
      final file = await _getLocalFile();
      if (!await file.exists()) {
        return [];
      }
      String contents = await file.readAsString();
      List<dynamic> jsonList = jsonDecode(contents);
      return jsonList.cast<Map<String, dynamic>>();
    } catch (e) {
      return [];
    }
  }

  // 获取本地文件对象
  static Future<File> _getLocalFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }
} 