import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'settings_page.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import '../main.dart';
import 'transcribe_task_detail_page.dart';

class SubmitTranscribeTaskPage extends StatefulWidget {
  final String audioPath;
  const SubmitTranscribeTaskPage({Key? key, required this.audioPath}) : super(key: key);

  @override
  State<SubmitTranscribeTaskPage> createState() => _SubmitTranscribeTaskPageState();
}

class _SubmitTranscribeTaskPageState extends State<SubmitTranscribeTaskPage> {
  int? _fileSize;
  Duration? _duration;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInfo();
  }

  Future<void> _loadInfo() async {
    setState(() => _loading = true);
    final file = File(widget.audioPath);
    int? size;
    Duration? duration;
    if (await file.exists()) {
      size = await file.length();
      try {
        final player = AudioPlayer();
        await player.setFilePath(widget.audioPath);
        duration = player.duration;
        await player.dispose();
      } catch (e) {
        duration = null;
      }
    }
    setState(() {
      _fileSize = size;
      _duration = duration;
      _loading = false;
    });
  }

  String _formatSize(int? size) {
    if (size == null) return '--';
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDuration(Duration? d) {
    if (d == null) return '--';
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours.toString().padLeft(2, '0')}:' : ''}$m:$s';
  }

  // 讯飞录音文件转写API签名生成
  String _getSigna(String appId, String secretKey, int ts) {
    final md5Str = md5.convert(utf8.encode(appId + ts.toString())).toString();
    final hmacSha1 = Hmac(sha1, utf8.encode(secretKey));
    final signaBytes = hmacSha1.convert(utf8.encode(md5Str)).bytes;
    return base64.encode(signaBytes);
  }

  // 上传音频文件，返回orderId
  Future<String> _uploadAudioFile({
    required String appId,
    required String secretKey,
    required String audioPath,
    int? duration, // 单位秒，可选
  }) async {
    final ts = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final signa = _getSigna(appId, secretKey, ts);
    final file = File(audioPath);
    final fileName = audioPath.split('/').last;
    final fileBytes = await file.readAsBytes();
    final queryParams = {
      'appId': appId,
      'signa': signa,
      'ts': ts.toString(),
      'fileName': fileName,
      'fileSize': fileBytes.length.toString(),
      'duration': (duration ?? 2000).toString(),
    };
    final uri = Uri.https('raasr.xfyun.cn', '/v2/api/upload', queryParams);
    print('[上传] $uri');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/octet-stream'},
      body: fileBytes,
    );
    print('[上传返回] ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['code'] == '000000' && json['descInfo'] == 'success') {
        final orderId = json['content']['orderId'] ?? '';
        return orderId;
      } else {
        throw Exception('上传失败: ${json['descInfo'] ?? json['failed'] ?? json['desc']}');
      }
    } else {
      throw Exception('HTTP错误: ${response.statusCode}');
    }
  }



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('提交转写任务')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('音频文件路径：', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text(widget.audioPath, style: TextStyle(color: Colors.grey)),
                  SizedBox(height: 16),
                  Text('文件大小：${_formatSize(_fileSize)}'),
                  SizedBox(height: 8),
                  Text('音频时长：${_formatDuration(_duration)}'),
                  SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      final config = await StorageService.getTranscribeApiConfig();
                      final appId = config['appId']?.trim();
                      final secretKey = config['secretKey']?.trim();
                      if (appId == null || appId.isEmpty || secretKey == null || secretKey.isEmpty) {
                        final goSetting = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text('未设置API信息'),
                            content: Text('请先在设置中填写转文字API的APPID和SecretKey'),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消')),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: Text('去设置')),
                            ],
                          ),
                        );
                        if (goSetting == true && mounted) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsPage()));
                        }
                        return;
                      }
                      try {
                        if (!mounted) return;
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (_) => Center(child: CircularProgressIndicator()),
                        );
                        // 步骤1：上传音频获取orderId
                        final orderId = await _uploadAudioFile(
                          appId: appId,
                          secretKey: secretKey,
                          audioPath: widget.audioPath,
                          duration: _duration?.inSeconds,
                        );
                        // 步骤2：轮询获取转写结果（可选，后续实现）
                        // 保存转写任务到文本库，初始text为空
                        final transcript = {
                          'id': DateTime.now().millisecondsSinceEpoch.toString(),
                          'recordingId': widget.audioPath,
                          'text': '',
                          'createdAt': DateTime.now().toIso8601String(),
                          'orderId': orderId,
                        };
                        await StorageService.insertTranscript(transcript);
                        if (!mounted) return;
                        Navigator.pop(context); // 关闭loading
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('上传成功'),
                            content: Text('任务已提交，orderId: $orderId'),
                            actions: [
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // 关闭弹窗
                                  Navigator.of(context).pop(); // 返回上一页
                                  // 跳转到文本库tab页
                                  final mainTabState = context.findAncestorStateOfType<MainTabPageState>();
                                  if (mainTabState != null && mainTabState.mounted) {
                                    mainTabState.setState(() {
                                      mainTabState.currentIndex = 2; // 文本库tab索引
                                    });
                                  }
                                },
                                child: Text('确定'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context); // 关闭弹窗
                                  if (mounted) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TranscribeTaskDetailPage(
                                          orderId: orderId,
                                          autoStartAiChat: false,
                                        ),
                                      ),
                                    );
                                  }
                                },
                                child: Text('查看结果'),
                              ),
                            ],
                          ),
                        );
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context); // 关闭loading
                          showDialog(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: Text('转写失败'),
                              content: Text(e.toString()),
                              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('确定'))],
                            ),
                          );
                        }
                      }
                    },
                    child: Text('提交转写任务'),
                  ),
                ],
              ),
      ),
    );
  }
} 