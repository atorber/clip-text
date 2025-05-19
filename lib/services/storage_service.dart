import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _fileName = 'recordings.json';
  static const String _transcriptFileName = 'transcripts.json';

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

  // 插入一条转写任务
  static Future<void> insertTranscript(Map<String, dynamic> transcript) async {
    final file = await _getTranscriptFile();
    List<Map<String, dynamic>> transcripts = await getAllTranscripts();
    transcripts.add(transcript);
    await file.writeAsString(jsonEncode(transcripts));
  }

  // 获取所有转写任务
  static Future<List<Map<String, dynamic>>> getAllTranscripts() async {
    try {
      final file = await _getTranscriptFile();
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

  // 获取转写任务本地文件对象
  static Future<File> _getTranscriptFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_transcriptFileName');
  }

  // 保存转文字API配置
  static Future<void> saveTranscribeApiConfig({required String appId, required String secretKey}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('transcribe_api_appid', appId);
    await prefs.setString('transcribe_api_secret', secretKey);
  }

  // 读取转文字API配置
  static Future<Map<String, String?>> getTranscribeApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'appId': prefs.getString('transcribe_api_appid'),
      'secretKey': prefs.getString('transcribe_api_secret'),
    };
  }

  // 根据orderId查找转写任务
  static Future<Map<String, dynamic>?> getTranscriptByOrderId(String orderId) async {
    final transcripts = await getAllTranscripts();
    try {
      return transcripts.firstWhere((e) => e['orderId'] == orderId);
    } catch (e) {
      return null;
    }
  }

  // 根据id删除转写任务
  static Future<void> deleteTranscriptById(String id) async {
    final file = await _getTranscriptFile();
    final list = await getAllTranscripts();
    list.removeWhere((e) => e['id'] == id);
    await file.writeAsString(jsonEncode(list));
  }
} 