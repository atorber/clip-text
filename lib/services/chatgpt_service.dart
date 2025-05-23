import 'dart:convert';
import 'package:http/http.dart' as http;
import 'storage_service.dart';

class ChatGptService {
  static Future<String> chatWithTranscript({
    required String transcriptText,
    required String userPrompt,
  }) async {
    print('[ChatGPT] 开始AI对话请求');
    print('[ChatGPT] 转写文本长度: ${transcriptText.length}');
    print('[ChatGPT] 用户提示词: $userPrompt');
    
    try {
      final config = await StorageService.getChatGptApiConfig();
      final apiKey = config['apiKey']?.trim();
      final baseUrl = config['baseUrl']?.trim() ?? 'https://api.openai.com';
      final model = config['model']?.trim() ?? 'gpt-3.5-turbo';

      print('[ChatGPT] API配置加载完成');
      print('[ChatGPT] Base URL: $baseUrl');
      print('[ChatGPT] Model: $model');
      print('[ChatGPT] API Key状态: ${apiKey != null && apiKey.isNotEmpty ? "已配置 (${apiKey.length}字符)" : "未配置"}');

      if (apiKey == null || apiKey.isEmpty) {
        print('[ChatGPT] 错误: API Key未配置');
        throw Exception('请先在设置中配置OpenAI API Key');
      }

      // 构建对话内容
      final systemPrompt = '你是一个专业的AI助手。用户会提供一段语音转写的文本内容，然后对这段内容提出问题或要求进行处理。请根据用户的要求对文本内容进行分析、总结、问答或其他处理。';
      final userMessage = '转写文本内容：\n\n$transcriptText\n\n用户要求：$userPrompt';

      final requestBody = {
        'model': model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.7,
        'max_tokens': 2000,
      };

      final requestUrl = '$baseUrl/v1/chat/completions';
      print('[ChatGPT] 请求URL: $requestUrl');
      print('[ChatGPT] 请求体大小: ${jsonEncode(requestBody).length} 字符');
      print('[ChatGPT] 发送请求...');

      final response = await http.post(
        Uri.parse(requestUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      );

      print('[ChatGPT] 收到响应');
      print('[ChatGPT] 响应状态码: ${response.statusCode}');
      print('[ChatGPT] 响应头: ${response.headers}');
      print('[ChatGPT] 响应体大小: ${response.body.length} 字符');

      if (response.statusCode == 200) {
        print('[ChatGPT] API调用成功');
        final responseData = jsonDecode(response.body);
        
        print('[ChatGPT] 解析响应数据...');
        print('[ChatGPT] 响应结构: ${responseData.keys.toList()}');
        
        if (responseData.containsKey('usage')) {
          final usage = responseData['usage'];
          print('[ChatGPT] Token使用情况: $usage');
        }
        
        final choices = responseData['choices'] as List;
        print('[ChatGPT] 选择数量: ${choices.length}');
        
        if (choices.isNotEmpty) {
          final content = choices[0]['message']['content'] as String;
          print('[ChatGPT] AI回复长度: ${content.length} 字符');
          print('[ChatGPT] AI回复预览: ${content.length > 100 ? content.substring(0, 100) + "..." : content}');
          return content;
        } else {
          print('[ChatGPT] 错误: 响应中没有选择');
          throw Exception('API返回数据格式错误');
        }
      } else {
        print('[ChatGPT] API调用失败');
        print('[ChatGPT] 错误响应体: ${response.body}');
        
        try {
          final errorData = jsonDecode(response.body);
          final errorMessage = errorData['error']['message'] ?? 'API调用失败';
          print('[ChatGPT] 错误详情: $errorMessage');
          throw Exception('OpenAI API错误 (${response.statusCode}): $errorMessage');
        } catch (e) {
          print('[ChatGPT] 无法解析错误响应: $e');
          throw Exception('OpenAI API错误 (${response.statusCode}): 无法解析错误信息');
        }
      }
    } catch (e) {
      print('[ChatGPT] 异常: $e');
      print('[ChatGPT] 异常类型: ${e.runtimeType}');
      rethrow;
    }
  }
} 