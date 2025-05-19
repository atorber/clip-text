import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/transcript.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('文本库')),
      body: _loading
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
                    return ListTile(
                      leading: Icon(Icons.description),
                      title: Text(t.text.length > 20 ? t.text.substring(0, 20) + '...' : t.text),
                      subtitle: Text('${t.createdAt.toLocal()}'),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: Text('转写全文'),
                            content: SingleChildScrollView(child: Text(t.text)),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('关闭'))],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }
} 