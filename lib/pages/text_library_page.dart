import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/transcript.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/storage_service.dart';
import '../pages/transcribe_task_detail_page.dart';

class TextLibraryPage extends StatefulWidget {
  @override
  State<TextLibraryPage> createState() => _TextLibraryPageState();
}

class _TextLibraryPageState extends State<TextLibraryPage> {
  List<Transcript> texts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTexts();
  }

  Future<void> _loadTexts() async {
    setState(() => _loading = true);
    final list = await StorageService.getAllTranscripts();
    setState(() {
      texts = list.map((e) => Transcript.fromMap(e)).toList().reversed.toList();
      _loading = false;
    });
  }

  Future<String?> _queryIflytekResult(String orderId) async {
    // 读取API配置
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
      'orderId': orderId,
    };
    final uri = Uri.https('raasr.xfyun.cn', '/v2/api/getResult', queryParams);
    print('[查询结果] $uri');
    final response = await http.get(uri);
    print('[查询返回] ${response.statusCode} ${response.body}');
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      if (json['code'] == '000000' && json['descInfo'] == 'success') {
        final orderResultStr = json['content']['orderResult'];
        if (orderResultStr is String && orderResultStr.isNotEmpty) {
          try {
            final text = parseIflytekOrderResult(orderResultStr);
            return text.isNotEmpty ? text : '暂无结果，请稍后刷新';
          } catch (e) {
            return '解析orderResult失败: $e';
          }
        } else {
          return '暂无结果，请稍后刷新';
        }
      } else if (json['code'] == '26620') {
        return '任务未完成，请稍后再试';
      } else {
        throw Exception('查询失败: ${json['descInfo'] ?? json['failed'] ?? json['desc']}');
      }
    } else {
      throw Exception('HTTP错误: ${response.statusCode}');
    }
  }

  String parseIflytekOrderResult(String orderResultStr) {
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
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? Center(child: CircularProgressIndicator())
        : texts.isEmpty
            ? ListView(
                children: [
                  SizedBox(height: 120),
                  Center(child: Text('暂无文本，快去录制并转写吧~', style: TextStyle(fontSize: 16, color: Colors.grey))),
                ],
              )
            : ListView.builder(
                itemCount: texts.length,
                itemBuilder: (context, index) {
                  final t = texts[index];
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.description),
                        title: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              t.text.length > 20 ? '${t.text.substring(0, 20)}...' : (t.text.isNotEmpty ? t.text : '转换中...'),
                              style: TextStyle(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '创建时间: ${t.createdAt.toLocal()}',
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                            SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: () async {
                                    if (t.orderId == null || t.orderId!.isEmpty) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => AlertDialog(
                                          title: Text('转写结果'),
                                          content: Text('无orderId，无法查询'),
                                          actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭'))],
                                        ),
                                      );
                                      return;
                                    }
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TranscribeTaskDetailPage(orderId: t.orderId!),
                                      ),
                                    );
                                    await _loadTexts();
                                  },
                                  child: Text('查看结果'),
                                ),
                                IconButton(
                                  icon: Icon(Icons.delete, color: Colors.red),
                                  tooltip: '删除',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: Text('确认删除'),
                                        content: Text('确定要删除该转写文本吗？'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('删除')),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await _deleteTranscript(t.id);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                    ],
                  );
                },
              );
  }

  Future<void> _deleteTranscript(String id) async {
    await StorageService.deleteTranscriptById(id);
    await _loadTexts();
  }
} 