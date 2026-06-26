import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class QwenAsrService {
  static const String defaultBaseUrl = 'https://dashscope.aliyuncs.com/api/v1';
  static const String defaultModel = 'qwen3-asr-flash';
  static const int maxAudioBytes = 10 * 1024 * 1024;

  static const String defaultSystemPrompt =
      '请将音频完整转写为文字，忠实还原说话内容，不要总结、不要改写、不要添加或省略内容。';

  /// 使用通义千问 ASR 将本地音频文件转为文本。
  static Future<String> transcribeAudioFile({
    required String audioPath,
    String? apiKey,
    String? baseUrl,
    String? model,
    String? systemPrompt,
  }) async {
    final config = await StorageService.getTranscribeApiConfig();
    final resolvedApiKey = (apiKey ?? config['qwenApiKey'])?.trim();
    final resolvedBaseUrl = (baseUrl ?? config['qwenBaseUrl'] ?? defaultBaseUrl).trim();
    final resolvedModel = (model ?? config['qwenModel'] ?? defaultModel).trim();

    if (resolvedApiKey == null || resolvedApiKey.isEmpty) {
      throw Exception('请先在设置中填写通义千问 API Key');
    }

    final file = File(audioPath);
    if (!await file.exists()) {
      throw Exception('音频文件不存在: $audioPath');
    }

    final fileBytes = await file.readAsBytes();
    if (fileBytes.length > maxAudioBytes) {
      throw Exception(
        '音频文件过大（${(fileBytes.length / (1024 * 1024)).toStringAsFixed(1)} MB），'
        '通义千问 ASR 限制 ${maxAudioBytes ~/ (1024 * 1024)} MB',
      );
    }

    final mimeType = _mimeTypeForPath(audioPath);
    final audioDataUrl =
        'data:$mimeType;base64,${base64Encode(fileBytes)}';

    final requestUrl =
        '$resolvedBaseUrl/services/aigc/multimodal-generation/generation';
    final requestBody = {
      'model': resolvedModel,
      'input': {
        'messages': [
          {
            'role': 'system',
            'content': [
              {'text': systemPrompt ?? defaultSystemPrompt},
            ],
          },
          {
            'role': 'user',
            'content': [
              {'audio': audioDataUrl},
            ],
          },
        ],
      },
      'parameters': {
        'result_format': 'message',
        'asr_options': {
          'language': 'zh',
          'enable_itn': false,
        },
      },
    };

    print('[QwenASR] 请求 URL: $requestUrl');
    print('[QwenASR] 模型: $resolvedModel, 音频大小: ${fileBytes.length} bytes');

    final response = await http.post(
      Uri.parse(requestUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $resolvedApiKey',
      },
      body: jsonEncode(requestBody),
    );

    print('[QwenASR] 响应状态码: ${response.statusCode}');

    Map<String, dynamic> responseData;
    try {
      responseData = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('通义千问 ASR 响应解析失败 (${response.statusCode})');
    }

    if (response.statusCode != 200) {
      final message = responseData['message'] ??
          responseData['code'] ??
          response.body;
      throw Exception('通义千问 ASR 错误 (${response.statusCode}): $message');
    }

    final text = _extractText(responseData);
    if (text.trim().isEmpty) {
      throw Exception('通义千问 ASR 未返回有效文本');
    }
    return text.trim();
  }

  static String _extractText(Map<String, dynamic> responseData) {
    final output = responseData['output'];
    if (output is! Map<String, dynamic>) {
      throw Exception('通义千问 ASR 响应格式错误: 缺少 output');
    }

    final choices = output['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('通义千问 ASR 响应格式错误: 缺少 choices');
    }

    final message = choices.first['message'];
    if (message is! Map<String, dynamic>) {
      throw Exception('通义千问 ASR 响应格式错误: 缺少 message');
    }

    final content = message['content'];
    if (content is! List || content.isEmpty) {
      throw Exception('通义千问 ASR 响应格式错误: 缺少 content');
    }

    final first = content.first;
    if (first is Map<String, dynamic>) {
      final text = first['text'];
      if (text is String) {
        return text;
      }
    }

    throw Exception('通义千问 ASR 响应格式错误: 无法提取 text');
  }

  static String _mimeTypeForPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.amr')) return 'audio/amr';
    if (lower.endsWith('.ogg')) return 'audio/ogg';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return 'audio/wav';
  }
}
