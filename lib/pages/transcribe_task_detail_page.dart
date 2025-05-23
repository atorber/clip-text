import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../services/storage_service.dart';
import '../services/chatgpt_service.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TranscribeTaskDetailPage extends StatefulWidget {
  final String orderId;
  final bool autoStartAiChat; // 是否自动开启AI对话
  const TranscribeTaskDetailPage({Key? key, required this.orderId, this.autoStartAiChat = false}) : super(key: key);

  @override
  State<TranscribeTaskDetailPage> createState() => _TranscribeTaskDetailPageState();
}

class _TranscribeTaskDetailPageState extends State<TranscribeTaskDetailPage> {
  Map? _task;
  bool _loading = true;
  late AudioPlayer _player;
  bool _audioReady = false;
  bool _querying = false;
  
  // AI对话相关状态
  bool _showAiChat = false;
  final _promptController = TextEditingController();
  bool _aiLoading = false;
  String _aiResponse = '';
  bool _showTranscriptText = true; // 控制转写文本显示
  bool _useMarkdownRender = true; // 控制是否使用markdown渲染
  bool _showChatHistory = false; // 控制历史记录显示
  List<Map<String, dynamic>> _chatHistory = []; // 历史问答记录

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _loadTask();
    
    // 如果设置了自动开启AI对话，则在加载完成后自动开启
    if (widget.autoStartAiChat) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _showAiChat = true;
          // 自动收起转写文本以节省空间
          _showTranscriptText = false;
        });
        // 检查API配置
        _checkApiConfig();
      });
    }
  }

  Future<void> _loadTask() async {
    final task = await StorageService.getTranscriptByOrderId(widget.orderId);
    bool audioReady = false;
    if (task != null && task['recordingId'] != null) {
      try {
        await _player.setFilePath(task['recordingId']);
        audioReady = true;
      } catch (e) {
        audioReady = false;
      }
    }
    setState(() {
      _task = task;
      _loading = false;
      _audioReady = audioReady;
    });
    if (task != null && (task['text'] == null || (task['text'] as String).trim().isEmpty)) {
      _queryTranscribeResult(task);
    }
  }

  Future<void> _queryTranscribeResult(Map task) async {
    setState(() { _querying = true; });
    try {
      final config = await StorageService.getTranscribeApiConfig();
      final appId = config['appId']?.trim();
      final secretKey = config['secretKey']?.trim();
      if (appId == null || appId.isEmpty || secretKey == null || secretKey.isEmpty) {
        throw Exception('请先在设置中填写转文字API的APPID和SecretKey');
      }
      final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final md5Str = md5.convert(utf8.encode(appId + ts.toString())).toString();
      final hmacSha1 = Hmac(sha1, utf8.encode(secretKey));
      final signaBytes = hmacSha1.convert(utf8.encode(md5Str)).bytes;
      final signa = base64.encode(signaBytes);
      final queryParams = {
        'appId': appId,
        'signa': signa,
        'ts': ts.toString(),
        'orderId': task['orderId'],
      };
      final uri = Uri.https('raasr.xfyun.cn', '/v2/api/getResult', queryParams);
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == '000000' && json['descInfo'] == 'success') {
          final orderResultStr = json['content']['orderResult'];
          if (orderResultStr is String && orderResultStr.isNotEmpty) {
            final text = _parseIflytekOrderResult(orderResultStr);
            if (text.trim().isNotEmpty) {
              final updated = Map<String, dynamic>.from(task);
              updated['text'] = text;
              await StorageService.updateTranscriptByOrderId(task['orderId'], {'text': text});
              setState(() {
                _task = updated;
              });
            }
          } else {
            // 结果为空
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('暂无结果，请稍后刷新')),
            );
          }
        } else if (json['code'] == '26620') {
          // 任务未完成
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('任务未完成，请稍后再试')),
          );
        } else {
          // 其他错误
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('查询失败: \\${json['descInfo'] ?? json['failed'] ?? json['desc']}')),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('HTTP错误: \\${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('查询异常: \\${e.toString()}')),
      );
    } finally {
      setState(() { _querying = false; });
    }
  }

  String _parseIflytekOrderResult(String orderResultStr) {
    try {
      final orderResult = jsonDecode(orderResultStr);
      final lattice = orderResult['lattice'];
      String text = '';
      for (final i in lattice) {
        final json1best = jsonDecode(i['json_1best']);
        final st = json1best['st'];
        final rt = st['rt'];
        for (final j in rt) {
          final ws = j['ws'];
          for (final k in ws) {
            final cw = k['cw'];
            for (final l in cw) {
              final w = l['w'];
              text += w;
            }
          }
        }
      }
      return text;
    } catch (e) {
      return '';
    }
  }

  // AI对话方法
  Future<void> _sendAiMessage() async {
    print('[UI] 开始发送AI消息');
    print('[UI] 提示词内容: "${_promptController.text.trim()}"');
    
    if (_promptController.text.trim().isEmpty) {
      print('[UI] 错误: 提示词为空');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入提示词')),
      );
      return;
    }

    final transcriptText = _task!['text'] as String? ?? '';
    print('[UI] 转写文本状态: ${transcriptText.isEmpty ? "为空" : "长度${transcriptText.length}字符"}');
    
    if (transcriptText.trim().isEmpty) {
      print('[UI] 错误: 转写文本为空');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转写文本为空，无法进行AI对话')),
      );
      return;
    }

    print('[UI] 设置加载状态');
    setState(() {
      _aiLoading = true;
      _aiResponse = '';
    });

    try {
      print('[UI] 调用ChatGPT服务...');
      final response = await ChatGptService.chatWithTranscript(
        transcriptText: transcriptText,
        userPrompt: _promptController.text.trim(),
      );
      
      print('[UI] ChatGPT服务调用成功');
      print('[UI] 收到AI回复，长度: ${response.length}字符');
      
      // 保存问答历史记录
      try {
        await StorageService.saveAiChatHistory(
          transcriptId: widget.orderId,
          question: _promptController.text.trim(),
          answer: response,
          transcriptText: transcriptText,
        );
        print('[UI] 问答历史记录保存成功');
        
        // 如果历史记录界面是打开的，自动刷新
        if (_showChatHistory) {
          _loadChatHistory();
        }
      } catch (e) {
        print('[UI] 问答历史记录保存失败: $e');
      }
      
      setState(() {
        _aiResponse = response;
        _aiLoading = false;
      });
      
      print('[UI] UI状态更新完成');
    } catch (e) {
      print('[UI] ChatGPT服务调用失败: $e');
      print('[UI] 错误类型: ${e.runtimeType}');
      
      setState(() {
        _aiLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI对话失败: ${e.toString()}')),
      );
    }
  }

  void _toggleAiChat() {
    setState(() {
      _showAiChat = !_showAiChat;
      if (!_showAiChat) {
        _promptController.clear();
        _aiResponse = '';
        // 关闭AI对话时展开转写文本
        _showTranscriptText = true;
      } else {
        // 打开AI对话时检查配置
        _checkApiConfig();
        // 自动收起转写文本以节省空间
        if (_showTranscriptText) {
          _showTranscriptText = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💡 已自动收起转写文本以节省空间，可点击箭头重新展开'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    });
  }

  Future<void> _checkApiConfig() async {
    print('[CONFIG] 检查API配置...');
    try {
      final config = await StorageService.getChatGptApiConfig();
      final apiKey = config['apiKey']?.trim();
      final baseUrl = config['baseUrl']?.trim() ?? 'https://api.openai.com';
      final model = config['model']?.trim() ?? 'gpt-3.5-turbo';
      
      print('[CONFIG] =================== API配置状态 ===================');
      print('[CONFIG] API Key: ${apiKey != null && apiKey.isNotEmpty ? "已配置 (${apiKey.length}字符)" : "❌ 未配置"}');
      print('[CONFIG] Base URL: $baseUrl');
      print('[CONFIG] Model: $model');
      print('[CONFIG] ================================================');
      
      if (apiKey == null || apiKey.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ 请先在设置中配置OpenAI API Key'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ API配置正常，可以开始AI对话'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('[CONFIG] 配置检查失败: $e');
    }
  }

  // 加载历史问答记录
  Future<void> _loadChatHistory() async {
    print('[HISTORY] 开始加载历史问答记录...');
    try {
      final history = await StorageService.getAiChatHistoryByTranscriptId(widget.orderId);
      setState(() {
        _chatHistory = history.reversed.toList(); // 最新的在前面
      });
      print('[HISTORY] 加载完成，共${history.length}条记录');
    } catch (e) {
      print('[HISTORY] 加载失败: $e');
    }
  }

  // 切换历史记录显示状态
  void _toggleChatHistory() {
    setState(() {
      _showChatHistory = !_showChatHistory;
    });
    if (_showChatHistory) {
      _loadChatHistory();
    }
  }

  // 删除单条历史记录
  Future<void> _deleteHistoryRecord(String id) async {
    try {
      await StorageService.deleteAiChatHistoryById(id);
      _loadChatHistory(); // 重新加载
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('历史记录已删除')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('删除失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _testApiConnection() async {
    print('[TEST] 开始测试API连接...');
    
    setState(() {
      _aiLoading = true;
      _aiResponse = '';
    });

    try {
      final response = await ChatGptService.chatWithTranscript(
        transcriptText: "这是一个测试文本。",
        userPrompt: "请回复\"测试成功\"",
      );
      
      setState(() {
        _aiResponse = '🎉 API连接测试成功！\n\nAI回复: $response';
        _aiLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ API连接测试成功'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        _aiResponse = '❌ API连接测试失败\n\n错误信息: $e';
        _aiLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ API连接测试失败'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _player.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return Center(child: CircularProgressIndicator());
    if (_task == null) return Center(child: Text('未找到任务'));
    return Scaffold(
      appBar: AppBar(title: Text('转写详情')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            Text('录音文件: ${_task!['recordingId']}', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('任务ID: ${_task!['orderId'] ?? ''}'),
            SizedBox(height: 4),
            Text('创建时间: ${_task!['createdAt'] ?? ''}'),
            SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.play_arrow),
                  onPressed: _audioReady ? () => _player.play() : null,
                ),
                IconButton(
                  icon: Icon(Icons.pause),
                  onPressed: _audioReady ? () => _player.pause() : null,
                ),
                IconButton(
                  icon: Icon(Icons.stop),
                  onPressed: _audioReady ? () => _player.stop() : null,
                ),
              ],
            ),
            if (!_audioReady)
              Text('音频文件不存在或已被删除', style: TextStyle(color: Colors.red)),
            SizedBox(height: 16),
            // 转写文本标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('转写文本:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (_task!['text'] != null && (_task!['text'] as String).trim().isNotEmpty)
                  IconButton(
                    icon: Icon(_showTranscriptText ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down),
                    onPressed: () {
                      setState(() {
                        _showTranscriptText = !_showTranscriptText;
                      });
                    },
                    tooltip: _showTranscriptText ? '收起转写文本' : '展开转写文本',
                  ),
              ],
            ),
            SizedBox(height: 8),
            // 转写文本内容
            if (_showTranscriptText) ...[
              _querying
                  ? Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('正在查询转写结果...')])
                  : (( _task!['text'] == null || (_task!['text'] as String).trim().isEmpty )
                      ? ElevatedButton.icon(
                          icon: Icon(Icons.refresh),
                          label: Text('刷新结果'),
                          onPressed: _querying ? null : () => _queryTranscribeResult(_task!),
                        )
                      : SelectableText(_task!['text'] ?? '')
                    ),
              SizedBox(height: 8),
              ElevatedButton.icon(
                icon: Icon(Icons.copy),
                label: Text('复制文本'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: _task!['text'] ?? ''));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制到剪贴板')));
                },
              ),
            ] else ...[
              // 收起状态显示文本预览
              if (_task!['text'] != null && (_task!['text'] as String).trim().isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Text(
                    '${(_task!['text'] as String).length > 50 ? (_task!['text'] as String).substring(0, 50) + "..." : _task!['text']}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ),
            ],
            SizedBox(height: 8),
            // AI对话按钮
            if (_task!['text'] != null && (_task!['text'] as String).trim().isNotEmpty)
              ElevatedButton.icon(
                icon: Icon(_showAiChat ? Icons.close : Icons.chat),
                label: Text(_showAiChat ? '关闭AI对话' : 'AI对话'),
                onPressed: _toggleAiChat,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showAiChat ? Colors.grey : Colors.blue,
                ),
              ),
            // AI对话界面
            if (_showAiChat) ...[
              SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI对话',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 12),
                      // 功能按钮区域
                      Row(
                        children: [
                          // 历史记录按钮
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(_showChatHistory ? Icons.history_toggle_off : Icons.history),
                              label: Text(_showChatHistory ? '隐藏历史' : '查看历史'),
                              onPressed: _toggleChatHistory,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _showChatHistory ? Colors.grey : Colors.indigo,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          // API测试按钮
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(Icons.wifi_protected_setup),
                              label: Text('测试连接'),
                              onPressed: _aiLoading ? null : _testApiConnection,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple,
                              ),
                            ),
                          ),
                          SizedBox(width: 6),
                          // 快速展开/收起转写文本按钮
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: Icon(_showTranscriptText ? Icons.visibility_off : Icons.visibility),
                              label: Text(_showTranscriptText ? '收起' : '原文'),
                              onPressed: () {
                                setState(() {
                                  _showTranscriptText = !_showTranscriptText;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.teal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      // 历史记录显示区域
                      if (_showChatHistory) ...[
                        Container(
                          height: 300,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[300]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.history, size: 16),
                                    SizedBox(width: 8),
                                    Text('历史问答记录 (${_chatHistory.length}条)', 
                                      style: TextStyle(fontWeight: FontWeight.bold)),
                                    Spacer(),
                                    if (_chatHistory.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.refresh, size: 16),
                                        onPressed: _loadChatHistory,
                                        tooltip: '刷新',
                                      ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: _chatHistory.isEmpty
                                  ? Center(child: Text('暂无历史记录'))
                                  : ListView.separated(
                                      padding: EdgeInsets.all(8),
                                      itemCount: _chatHistory.length,
                                      separatorBuilder: (context, index) => Divider(height: 1),
                                      itemBuilder: (context, index) {
                                        final record = _chatHistory[index];
                                        final timestamp = DateTime.parse(record['timestamp']);
                                        return Container(
                                          padding: EdgeInsets.all(8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(Icons.question_answer, size: 14, color: Colors.blue),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    '${timestamp.month}/${timestamp.day} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey),
                                                  ),
                                                  Spacer(),
                                                  IconButton(
                                                    icon: Icon(Icons.copy, size: 16, color: Colors.green),
                                                    onPressed: () {
                                                      Clipboard.setData(ClipboardData(
                                                        text: '问: ${record['question']}\n\n答: ${record['answer']}'
                                                      ));
                                                      ScaffoldMessenger.of(context).showSnackBar(
                                                        SnackBar(content: Text('问答内容已复制到剪贴板')),
                                                      );
                                                    },
                                                    tooltip: '复制',
                                                  ),
                                                  IconButton(
                                                    icon: Icon(Icons.delete, size: 16, color: Colors.red),
                                                    onPressed: () => _deleteHistoryRecord(record['id']),
                                                    tooltip: '删除',
                                                  ),
                                                ],
                                              ),
                                              SizedBox(height: 4),
                                              GestureDetector(
                                                onTap: () {
                                                  // 点击后显示完整内容
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text('完整问答内容'),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Container(
                                                              padding: EdgeInsets.all(8),
                                                              decoration: BoxDecoration(
                                                                color: Colors.blue[50],
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: SelectableText(
                                                                '问: ${record['question']}',
                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                              ),
                                                            ),
                                                            SizedBox(height: 8),
                                                            Container(
                                                              padding: EdgeInsets.all(8),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green[50],
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: SelectableText(
                                                                '答: ${record['answer']}',
                                                                style: TextStyle(fontSize: 14),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: Text('关闭'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Clipboard.setData(ClipboardData(
                                                              text: '问: ${record['question']}\n\n答: ${record['answer']}'
                                                            ));
                                                            Navigator.pop(context);
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('问答内容已复制到剪贴板')),
                                                            );
                                                          },
                                                          child: Text('复制'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '问: ${record['question']}',
                                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                                        ),
                                                      ),
                                                      Icon(Icons.touch_app, size: 12, color: Colors.grey),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              GestureDetector(
                                                onTap: () {
                                                  // 点击后显示完整内容
                                                  showDialog(
                                                    context: context,
                                                    builder: (context) => AlertDialog(
                                                      title: Text('完整问答内容'),
                                                      content: SingleChildScrollView(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Container(
                                                              padding: EdgeInsets.all(8),
                                                              decoration: BoxDecoration(
                                                                color: Colors.blue[50],
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: SelectableText(
                                                                '问: ${record['question']}',
                                                                style: TextStyle(fontWeight: FontWeight.w500),
                                                              ),
                                                            ),
                                                            SizedBox(height: 8),
                                                            Container(
                                                              padding: EdgeInsets.all(8),
                                                              decoration: BoxDecoration(
                                                                color: Colors.green[50],
                                                                borderRadius: BorderRadius.circular(4),
                                                              ),
                                                              child: SelectableText(
                                                                '答: ${record['answer']}',
                                                                style: TextStyle(fontSize: 14),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () => Navigator.pop(context),
                                                          child: Text('关闭'),
                                                        ),
                                                        TextButton(
                                                          onPressed: () {
                                                            Clipboard.setData(ClipboardData(
                                                              text: '问: ${record['question']}\n\n答: ${record['answer']}'
                                                            ));
                                                            Navigator.pop(context);
                                                            ScaffoldMessenger.of(context).showSnackBar(
                                                              SnackBar(content: Text('问答内容已复制到剪贴板')),
                                                            );
                                                          },
                                                          child: Text('复制'),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                                child: Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.green[50],
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          '答: ${record['answer'].length > 100 ? record['answer'].substring(0, 100) + "..." : record['answer']}',
                                                          style: TextStyle(fontSize: 13),
                                                        ),
                                                      ),
                                                      Icon(Icons.touch_app, size: 12, color: Colors.grey),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                      ],
                      SizedBox(height: 12),
                      TextField(
                        controller: _promptController,
                        decoration: InputDecoration(
                          hintText: '请输入您的问题或要求（例如：总结这段内容、提取关键信息等）',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        enabled: !_aiLoading,
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: _aiLoading 
                                ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : Icon(Icons.send),
                              label: Text(_aiLoading ? '处理中...' : '发送'),
                              onPressed: _aiLoading ? null : _sendAiMessage,
                            ),
                          ),
                          SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: _aiLoading ? null : () {
                              _promptController.clear();
                              setState(() => _aiResponse = '');
                            },
                            tooltip: '清空',
                          ),
                        ],
                      ),
                      if (_aiResponse.isNotEmpty) ...[
                        SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'AI回复:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton.icon(
                              icon: Icon(_useMarkdownRender ? Icons.text_fields : Icons.wysiwyg),
                              label: Text(_useMarkdownRender ? '纯文本' : 'Markdown'),
                              onPressed: () {
                                setState(() {
                                  _useMarkdownRender = !_useMarkdownRender;
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: SelectionArea(
                            child: _useMarkdownRender 
                              ? MarkdownBlock(
                                  data: _aiResponse,
                                  config: MarkdownConfig(
                                    configs: [
                                      // 段落配置
                                      PConfig(
                                        textStyle: const TextStyle(fontSize: 14, height: 1.5),
                                      ),
                                      // 代码块配置
                                      PreConfig(
                                        textStyle: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 13,
                                          color: Colors.green,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        padding: const EdgeInsets.all(8),
                                      ),
                                      // 标题配置
                                      H1Config(
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      H2Config(
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      H3Config(
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                                  _aiResponse,
                                  style: const TextStyle(fontSize: 14, height: 1.5),
                                ),
                          ),
                        ),
                        SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: Icon(Icons.copy),
                                label: Text('复制AI回复'),
                                onPressed: () {
                                  // 复制原始markdown文本
                                  Clipboard.setData(ClipboardData(text: _aiResponse));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('AI回复已复制到剪贴板（原始Markdown格式）')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            ElevatedButton.icon(
                              icon: Icon(Icons.text_fields),
                              label: Text('复制纯文本'),
                              onPressed: () {
                                // 移除markdown格式符号，复制纯文本
                                final plainText = _stripMarkdown(_aiResponse);
                                Clipboard.setData(ClipboardData(text: plainText));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('AI回复已复制到剪贴板（纯文本格式）')),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _stripMarkdown(String markdown) {
    // 移除markdown格式符号，转换为纯文本
    String text = markdown;
    
    // 移除代码块
    text = text.replaceAll(RegExp(r'```[\s\S]*?```'), '');
    text = text.replaceAll(RegExp(r'`[^`]*`'), '');
    
    // 移除链接 [text](url) -> text
    text = text.replaceAll(RegExp(r'\[([^\]]*)\]\([^)]*\)'), r'$1');
    
    // 移除图片 ![alt](url) -> alt
    text = text.replaceAll(RegExp(r'!\[([^\]]*)\]\([^)]*\)'), r'$1');
    
    // 移除标题符号
    text = text.replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '');
    
    // 移除粗体和斜体
    text = text.replaceAll(RegExp(r'\*\*([^*]*)\*\*'), r'$1');
    text = text.replaceAll(RegExp(r'\*([^*]*)\*'), r'$1');
    text = text.replaceAll(RegExp(r'__([^_]*)__'), r'$1');
    text = text.replaceAll(RegExp(r'_([^_]*)_'), r'$1');
    
    // 移除删除线
    text = text.replaceAll(RegExp(r'~~([^~]*)~~'), r'$1');
    
    // 移除列表符号
    text = text.replaceAll(RegExp(r'^[\s]*[-*+]\s+', multiLine: true), '');
    text = text.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');
    
    // 移除引用符号
    text = text.replaceAll(RegExp(r'^>\s*', multiLine: true), '');
    
    // 清理多余的空行
    text = text.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    text = text.trim();
    
    return text;
  }
} 