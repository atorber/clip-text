import 'package:flutter/material.dart';

class TextLibraryPage extends StatefulWidget {
  @override
  State<TextLibraryPage> createState() => _TextLibraryPageState();
}

class _TextLibraryPageState extends State<TextLibraryPage> {
  List<Map<String, dynamic>> texts = [];

  @override
  void initState() {
    super.initState();
    // TODO: 加载文本库数据
    // texts = await StorageService.getAllTranscripts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('文本库')),
      body: texts.isEmpty
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
                return ListTile(
                  leading: Icon(Icons.description),
                  title: Text(t['title'] ?? '无标题'),
                  subtitle: Text(t['createdAt'] ?? ''),
                  onTap: () {
                    // TODO: 查看/编辑文本
                  },
                );
              },
            ),
    );
  }
} 