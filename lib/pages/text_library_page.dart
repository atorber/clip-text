import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/transcript.dart';
import 'dart:convert';
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
                                        builder: (_) => TranscribeTaskDetailPage(
                                          orderId: t.orderId!,
                                          autoStartAiChat: false,
                                        ),
                                      ),
                                    );
                                    await _loadTexts();
                                  },
                                  child: Text('查看结果'),
                                ),
                                if (t.text.trim().isNotEmpty)
                                  TextButton(
                                    onPressed: () async {
                                      if (t.orderId == null || t.orderId!.isEmpty) {
                                        showDialog(
                                          context: context,
                                          builder: (_) => AlertDialog(
                                            title: Text('AI对话'),
                                            content: Text('无orderId，无法进入AI对话'),
                                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭'))],
                                          ),
                                        );
                                        return;
                                      }
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => TranscribeTaskDetailPage(
                                            orderId: t.orderId!,
                                            autoStartAiChat: true,
                                          ),
                                        ),
                                      );
                                      await _loadTexts();
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: Colors.blue,
                                    ),
                                    child: Text('AI对话'),
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