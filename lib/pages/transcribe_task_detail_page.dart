import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../services/storage_service.dart';
import '../services/chatgpt_service.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// 聊天消息类
class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final bool isMarkdown;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.isMarkdown = false,
  });
}

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
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _aiLoading = false;
  bool _showTranscriptText = true; // 控制转写文本显示
  bool _showAudioPlayer = true; // 控制音频播放器显示
  List<ChatMessage> _messages = []; // 聊天消息列表

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
        // 加载历史对话记录到聊天界面
        _loadChatHistoryToMessages();
      });
    }
  }

  // 加载历史对话记录到聊天界面
  Future<void> _loadChatHistoryToMessages() async {
    try {
      final history = await StorageService.getAiChatHistoryByTranscriptId(widget.orderId);
      setState(() {
        _messages.clear();
        for (final record in history) {
          final timestamp = DateTime.parse(record['timestamp']);
          // 添加用户消息
          _messages.add(ChatMessage(
            id: '${record['id']}_user',
            content: record['question'],
            isUser: true,
            timestamp: timestamp,
          ));
          // 添加AI回复
          _messages.add(ChatMessage(
            id: '${record['id']}_ai',
            content: record['answer'],
            isUser: false,
            timestamp: timestamp.add(Duration(seconds: 1)),
            isMarkdown: true,
          ));
        }
      });
      // 滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
    } catch (e) {
      print('[HISTORY] 加载历史记录失败: $e');
    }
  }

  // 滚动到底部
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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

  // 发送聊天消息
  Future<void> _sendChatMessage() async {
    print('[CHAT] 开始发送聊天消息');
    final messageText = _messageController.text.trim();
    print('[CHAT] 消息内容: "$messageText"');
    
    if (messageText.isEmpty) {
      print('[CHAT] 错误: 消息为空');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('请输入消息')),
      );
      return;
    }

    final transcriptText = _task!['text'] as String? ?? '';
    print('[CHAT] 转写文本状态: ${transcriptText.isEmpty ? "为空" : "长度${transcriptText.length}字符"}');
    
    if (transcriptText.trim().isEmpty) {
      print('[CHAT] 错误: 转写文本为空');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转写文本为空，无法进行AI对话')),
      );
      return;
    }

    // 添加用户消息到聊天界面
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMessage);
      _aiLoading = true;
    });

    // 清空输入框
    _messageController.clear();
    
    // 滚动到底部
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });

    try {
      print('[CHAT] 调用ChatGPT服务...');
      final response = await ChatGptService.chatWithTranscript(
        transcriptText: transcriptText,
        userPrompt: messageText,
      );
      
      print('[CHAT] ChatGPT服务调用成功');
      print('[CHAT] 收到AI回复，长度: ${response.length}字符');
      
      // 添加AI回复到聊天界面
      final aiMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: response,
        isUser: false,
        timestamp: DateTime.now(),
        isMarkdown: true,
      );

      setState(() {
        _messages.add(aiMessage);
        _aiLoading = false;
      });
      
      // 保存问答历史记录
      try {
        await StorageService.saveAiChatHistory(
          transcriptId: widget.orderId,
          question: messageText,
          answer: response,
          transcriptText: transcriptText,
        );
        print('[CHAT] 问答历史记录保存成功');
      } catch (e) {
        print('[CHAT] 问答历史记录保存失败: $e');
      }
      
      // 滚动到底部
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToBottom();
      });
      
      print('[CHAT] UI状态更新完成');
    } catch (e) {
      print('[CHAT] ChatGPT服务调用失败: $e');
      print('[CHAT] 错误类型: ${e.runtimeType}');
      
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
        _messageController.clear();
        _messages.clear();
        // 关闭AI对话时展开转写文本和音频播放器
        _showTranscriptText = true;
        _showAudioPlayer = true;
      } else {
        // 打开AI对话时检查配置
        _checkApiConfig();
        // 自动收起音频播放器和转写文本以节省空间
        _showAudioPlayer = false;
        if (_showTranscriptText) {
          _showTranscriptText = false;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('💡 已自动收起音频播放器和转写文本，专注AI对话'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        // 加载历史对话记录
        _loadChatHistoryToMessages();
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

  @override
  void dispose() {
    _player.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text('转写详情')),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_task == null) {
      return Scaffold(
        appBar: AppBar(title: Text('转写详情')),
        body: Center(child: Text('未找到任务')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('转写详情'),
        backgroundColor: Colors.blue[50],
        elevation: 0,
      ),
      body: Column(
          children: [
          // 顶部功能栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  spreadRadius: 1,
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: _buildBottomActionBar(),
          ),

          // 音频播放器区域（可折叠）
          if (_showAudioPlayer) ...[
            Container(
              width: double.infinity,
              color: Colors.blue[50],
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Card(
                elevation: 2,
                margin: EdgeInsets.zero,
                child: Column(
              children: [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.audiotrack, color: Colors.blue[700], size: 24),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '录音文件',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.blue[800],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  _task!['createdAt'] ?? '未知时间',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                ),
              ],
            ),
                          ),
                          // 收起按钮
                  IconButton(
                            icon: Icon(Icons.keyboard_arrow_up, color: Colors.blue[700]),
                    onPressed: () {
                      setState(() {
                                _showAudioPlayer = false;
                      });
                    },
                            tooltip: '收起音频播放器',
                  ),
              ],
            ),
                    ),
                    // 音频控制按钮
                    if (_audioReady) ...[
                      Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(25),
                  ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: Icon(Icons.play_arrow, color: Colors.green[700]),
                                onPressed: () => _player.play(),
                                tooltip: '播放',
                              ),
                              IconButton(
                                icon: Icon(Icons.pause, color: Colors.orange[700]),
                                onPressed: () => _player.pause(),
                                tooltip: '暂停',
                              ),
                              IconButton(
                                icon: Icon(Icons.stop, color: Colors.red[700]),
                                onPressed: () => _player.stop(),
                                tooltip: '停止',
                ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Container(
                          padding: EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Row(
                    children: [
                              Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                              SizedBox(width: 8),
                      Text(
                                '音频文件不可用',
                                style: TextStyle(color: Colors.red[700], fontSize: 14),
                      ),
                            ],
                              ),
                            ),
                          ),
                    ],
                  ],
                              ),
                            ),
                          ),
          ],

          // 主内容区域
                          Expanded(
            child: _showAiChat ? _buildChatInterface() : _buildTranscriptInterface(),
          ),
        ],
      ),
    );
  }

  // 构建转写文本界面
  Widget _buildTranscriptInterface() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
          // 转写状态指示器
                              Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
              color: _hasTranscriptText() ? Colors.green[50] : Colors.orange[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _hasTranscriptText() ? Colors.green[200]! : Colors.orange[200]!,
              ),
                                ),
                                child: Row(
              mainAxisSize: MainAxisSize.min,
                                  children: [
                Icon(
                  _hasTranscriptText() ? Icons.check_circle : Icons.pending,
                  size: 16,
                  color: _hasTranscriptText() ? Colors.green[700] : Colors.orange[700],
                ),
                                    SizedBox(width: 8),
                Text(
                  _hasTranscriptText() ? '转写完成' : '转写中...',
                  style: TextStyle(
                    color: _hasTranscriptText() ? Colors.green[700] : Colors.orange[700],
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                                      ),
                                  ],
                                ),
                              ),
          SizedBox(height: 12),

          // 转写内容区域
                              Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: _querying 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('正在获取转写结果...', style: TextStyle(color: Colors.grey[600])),
                      ],
                    ),
                  )
                : _hasTranscriptText()
                  ? Padding(
                      padding: EdgeInsets.all(16),
                      child: SingleChildScrollView(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                  Text(
                              '转写内容',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.grey[800],
                              ),
                            ),
                            SizedBox(height: 12),
                            SelectableText(
                              _task!['text'] ?? '',
                              style: TextStyle(
                                fontSize: 15,
                                height: 1.6,
                                color: Colors.grey[800],
                              ),
                                                  ),
                                                ],
                                              ),
                      ),
                    )
                  : Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(
                                                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                                                          children: [
                            Icon(Icons.description_outlined, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              '暂无转写结果',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                                                              ),
                                                            ),
                                                            SizedBox(height: 8),
                            Text(
                              '点击下方刷新按钮重新获取',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton.icon(
                              icon: Icon(Icons.refresh),
                              label: Text('刷新结果'),
                              onPressed: () => _queryTranscribeResult(_task!),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                    ),
                                                        ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
  }

  // 构建聊天界面
  Widget _buildChatInterface() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        children: [
          // 聊天标题栏
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue[50],
                                                  ),
                                                  child: Row(
                                                    children: [
                Icon(Icons.smart_toy, color: Colors.blue[700], size: 24),
                SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                      Text(
                        'AI智能对话',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.blue[800],
                        ),
                                                              ),
                      Text(
                        '${_messages.length ~/ 2}轮对话',
                        style: TextStyle(
                          color: Colors.blue[600],
                          fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                // 功能按钮
                IconButton(
                  icon: Icon(Icons.refresh, color: Colors.blue[700]),
                  onPressed: _loadChatHistoryToMessages,
                  tooltip: '刷新历史',
                                                        ),
                IconButton(
                  icon: Icon(Icons.clear_all, color: Colors.blue[700]),
                                                          onPressed: () {
                    setState(() {
                      _messages.clear();
                    });
                                                          },
                  tooltip: '清空对话',
                                                        ),
                                                      ],
                                                    ),
          ),

          // 聊天消息区域
                                                      Expanded(
            child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[300]),
                      SizedBox(height: 16),
                      Text(
                        '开始AI对话',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                                                        ),
                                                      ),
                      SizedBox(height: 8),
                      Text(
                        '向AI提问关于这段录音的任何问题',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                                                ),
                                              ),
                                            ],
                                          ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length + (_aiLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _aiLoading) {
                      return _buildTypingIndicator();
                    }
                    return _buildMessageBubble(_messages[index]);
                                      },
                                    ),
                              ),

          // 消息输入区域
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
                          ),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: _messageController,
                        decoration: InputDecoration(
                        hintText: '输入您的问题...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      maxLines: null,
                        enabled: !_aiLoading,
                      onSubmitted: (value) {
                        if (!_aiLoading && value.trim().isNotEmpty) {
                          _sendChatMessage();
                        }
                      },
                    ),
                  ),
                      ),
                SizedBox(width: 12),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _aiLoading ? Colors.grey[300] : Colors.blue,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: IconButton(
                              icon: _aiLoading 
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Icon(Icons.send, color: Colors.white),
                    onPressed: _aiLoading ? null : _sendChatMessage,
                  ),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  // 构建底部操作栏
  Widget _buildBottomActionBar() {
    return Row(
                          children: [
        // 音频播放器按钮（仅在隐藏时显示）
        if (!_showAudioPlayer) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
                            ),
            child: IconButton(
              icon: Icon(Icons.audiotrack, color: Colors.blue[700]),
                              onPressed: () {
                                setState(() {
                  _showAudioPlayer = true;
                                });
                              },
              tooltip: '显示音频播放器',
            ),
          ),
          SizedBox(width: 12),
        ],
        // 转写文本按钮
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(_showAiChat ? Icons.description : Icons.description_outlined),
            label: Text('原文本'),
            onPressed: () {
              setState(() {
                _showAiChat = false;
                _showAudioPlayer = true; // 切换到转写文本时显示音频播放器
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _showAiChat ? Colors.grey[200] : Colors.blue,
              foregroundColor: _showAiChat ? Colors.grey[700] : Colors.white,
              padding: EdgeInsets.symmetric(vertical: 12),
              elevation: _showAiChat ? 0 : 2,
            ),
          ),
                        ),
        SizedBox(width: 12),
        // AI对话按钮
        Expanded(
          child: ElevatedButton.icon(
            icon: Icon(_showAiChat ? Icons.smart_toy : Icons.smart_toy_outlined),
            label: Text('AI对话'),
            onPressed: _hasTranscriptText() ? _toggleAiChat : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _showAiChat ? Colors.blue : Colors.grey[200],
              foregroundColor: _showAiChat ? Colors.white : Colors.grey[700],
              padding: EdgeInsets.symmetric(vertical: 12),
              elevation: _showAiChat ? 2 : 0,
            ),
          ),
        ),
        SizedBox(width: 12),
        // 复制按钮
                        Container(
                          decoration: BoxDecoration(
            color: Colors.green[50],
                            borderRadius: BorderRadius.circular(8),
          ),
          child: IconButton(
            icon: Icon(Icons.copy, color: Colors.green[700]),
            onPressed: _hasTranscriptText() ? () {
              Clipboard.setData(ClipboardData(text: _task!['text'] ?? ''));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('转写内容已复制到剪贴板'),
                  duration: Duration(seconds: 2),
                ),
              );
            } : null,
            tooltip: '复制转写内容',
          ),
        ),
      ],
    );
  }

  // 检查是否有转写文本
  bool _hasTranscriptText() {
    return _task!['text'] != null && (_task!['text'] as String).trim().isNotEmpty;
  }

  // 构建聊天气泡
  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            // AI头像
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.blue[100],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.smart_toy, color: Colors.blue[700], size: 20),
            ),
            SizedBox(width: 8),
          ],
          // 消息气泡
          Flexible(
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: message.isUser ? Colors.blue[500] : Colors.grey[100],
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: Radius.circular(message.isUser ? 16 : 4),
                  bottomRight: Radius.circular(message.isUser ? 4 : 16),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 消息内容
                  SelectionArea(
                    child: message.isMarkdown && !message.isUser
                              ? MarkdownBlock(
                          data: message.content,
                                  config: MarkdownConfig(
                                    configs: [
                                      PConfig(
                                textStyle: TextStyle(
                                  fontSize: 14, 
                                  height: 1.5,
                                  color: message.isUser ? Colors.white : Colors.black87,
                                      ),
                              ),
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
                                      H1Config(
                                style: TextStyle(
                                  fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                  color: message.isUser ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      H2Config(
                                style: TextStyle(
                                  fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                  color: message.isUser ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      H3Config(
                                style: TextStyle(
                                  fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                  color: message.isUser ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : Text(
                          message.content,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: message.isUser ? Colors.white : Colors.black87,
                                ),
                          ),
                        ),
                        SizedBox(height: 8),
                  // 时间戳和操作按钮
                        Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                      Text(
                        '${message.timestamp.hour.toString().padLeft(2, '0')}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 11,
                          color: message.isUser ? Colors.white70 : Colors.grey[600],
                                ),
                              ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: message.content));
                                ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('消息已复制到剪贴板'),
                                  duration: Duration(seconds: 1),
                                ),
                                );
                              },
                            child: Icon(
                              Icons.copy,
                              size: 14,
                              color: message.isUser ? Colors.white70 : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                  ),
                    ],
                  ),
                ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 8),
            // 用户头像
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.green[100],
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.person, color: Colors.green[700], size: 20),
              ),
            ],
          ],
      ),
    );
  }

  // 构建输入中指示器
  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AI头像
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.blue[100],
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.smart_toy, color: Colors.blue[700], size: 20),
          ),
          SizedBox(width: 8),
          // 输入中气泡
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI正在思考',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 