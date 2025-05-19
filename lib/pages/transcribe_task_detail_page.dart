import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import '../services/storage_service.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TranscribeTaskDetailPage extends StatefulWidget {
  final String orderId;
  const TranscribeTaskDetailPage({Key? key, required this.orderId}) : super(key: key);

  @override
  State<TranscribeTaskDetailPage> createState() => _TranscribeTaskDetailPageState();
}

class _TranscribeTaskDetailPageState extends State<TranscribeTaskDetailPage> {
  Map? _task;
  bool _loading = true;
  late AudioPlayer _player;
  bool _audioReady = false;
  bool _querying = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _loadTask();
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
              await StorageService.insertTranscript(updated);
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

  @override
  void dispose() {
    _player.dispose();
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
            Text('转写文本:', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            _querying
                ? Row(children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('正在查询转写结果...')])
                : SelectableText(_task!['text'] ?? ''),
            SizedBox(height: 8),
            ElevatedButton.icon(
              icon: Icon(Icons.copy),
              label: Text('复制文本'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _task!['text'] ?? ''));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已复制到剪贴板')));
              },
            ),
          ],
        ),
      ),
    );
  }
} 