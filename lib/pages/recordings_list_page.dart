import 'package:flutter/material.dart';
import 'package:system_audio_recorder/system_audio_recorder.dart';
import '../models/recording.dart';

class RecordingsListPage extends StatefulWidget {
  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  List<Recording> recordings = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecordings();
  }

  Future<void> _loadRecordings() async {
    setState(() => _loading = true);
    try {
      final list = await Recording.getAllRecordingsFromPlugin();
      setState(() {
        recordings = list;
      });
    } catch (e) {
      setState(() {
        recordings = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  String _formatSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('录音列表')),
      body: RefreshIndicator(
        onRefresh: _loadRecordings,
        child: _loading
            ? Center(child: CircularProgressIndicator())
            : recordings.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: 120),
                      Center(child: Text('暂无录音，快去录制吧~', style: TextStyle(fontSize: 16, color: Colors.grey))),
                    ],
                  )
                : ListView.builder(
                    itemCount: recordings.length,
                    itemBuilder: (context, index) {
                      final rec = recordings[index];
                      return ListTile(
                        leading: Icon(Icons.audiotrack),
                        title: Text(rec.filePath.split('/').last),
                        subtitle: Text(
                          '大小: ${_formatSize(rec.size)}\n'
                          '时间: ${rec.createdAt}',
                        ),
                        onTap: () {
                          // TODO: 跳转到转写/编辑页面
                        },
                        onLongPress: () {
                          // TODO: 长按直接转写
                        },
                      );
                    },
                  ),
      ),
    );
  }
} 