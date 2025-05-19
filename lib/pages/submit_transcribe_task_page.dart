import 'package:flutter/material.dart';

class SubmitTranscribeTaskPage extends StatelessWidget {
  final String audioPath;
  const SubmitTranscribeTaskPage({Key? key, required this.audioPath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('提交转写任务')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('音频文件路径：', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(audioPath, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                // TODO: 实现转写任务提交逻辑
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('转写任务已提交（待实现）')),
                );
              },
              child: Text('提交转写任务'),
            ),
          ],
        ),
      ),
    );
  }
} 