import 'package:flutter/material.dart';

class RecordingsListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('录音列表')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.audiotrack),
            title: Text('录音示例1'),
            subtitle: Text('2024-06-01 10:00'),
            onTap: () {
              // TODO: 跳转到转写/编辑页面
            },
            onLongPress: () {
              // TODO: 长按直接转写
            },
          ),
        ],
      ),
    );
  }
} 