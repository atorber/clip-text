import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _fileName = 'recordings.json';
  static const String _transcriptFileName = 'transcripts.json';
  static const String _aiChatHistoryFileName = 'ai_chat_history.json';

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

  // 保存ChatGPT API配置
  static Future<void> saveChatGptApiConfig({
    required String apiKey,
    String? baseUrl,
    String? model,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chatgpt_api_key', apiKey);
    await prefs.setString('chatgpt_base_url', baseUrl ?? 'https://api.openai.com');
    await prefs.setString('chatgpt_model', model ?? 'gpt-3.5-turbo');
  }

  // 读取ChatGPT API配置
  static Future<Map<String, String?>> getChatGptApiConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'apiKey': prefs.getString('chatgpt_api_key'),
      'baseUrl': prefs.getString('chatgpt_base_url'),
      'model': prefs.getString('chatgpt_model'),
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

  // 根据orderId更新转写任务内容
  static Future<void> updateTranscriptByOrderId(String orderId, Map<String, dynamic> updateFields) async {
    final file = await _getTranscriptFile();
    final list = await getAllTranscripts();
    final idx = list.indexWhere((e) => e['orderId'] == orderId);
    if (idx != -1) {
      list[idx].addAll(updateFields);
      await file.writeAsString(jsonEncode(list));
    }
  }

  // ==================== AI问答历史记录管理 ====================
  
  // 保存AI问答记录
  static Future<void> saveAiChatHistory({
    required String transcriptId,
    required String question,
    required String answer,
    required String transcriptText,
  }) async {
    final file = await _getAiChatHistoryFile();
    List<Map<String, dynamic>> history = await getAllAiChatHistory();
    
    final record = {
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
      'transcriptId': transcriptId,
      'question': question,
      'answer': answer,
      'transcriptText': transcriptText,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    history.add(record);
    await file.writeAsString(jsonEncode(history));
  }

  // 获取所有AI问答历史记录
  static Future<List<Map<String, dynamic>>> getAllAiChatHistory() async {
    try {
      final file = await _getAiChatHistoryFile();
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

  // 根据转写ID获取相关的问答历史
  static Future<List<Map<String, dynamic>>> getAiChatHistoryByTranscriptId(String transcriptId) async {
    final allHistory = await getAllAiChatHistory();
    return allHistory.where((record) => record['transcriptId'] == transcriptId).toList();
  }

  // 获取AI问答历史文件对象
  static Future<File> _getAiChatHistoryFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_aiChatHistoryFileName');
  }

  // 根据ID删除问答记录
  static Future<void> deleteAiChatHistoryById(String id) async {
    final file = await _getAiChatHistoryFile();
    final list = await getAllAiChatHistory();
    list.removeWhere((e) => e['id'] == id);
    await file.writeAsString(jsonEncode(list));
  }

  // 清空某个转写任务的所有问答历史
  static Future<void> clearAiChatHistoryByTranscriptId(String transcriptId) async {
    final file = await _getAiChatHistoryFile();
    final list = await getAllAiChatHistory();
    list.removeWhere((e) => e['transcriptId'] == transcriptId);
    await file.writeAsString(jsonEncode(list));
  }
} 