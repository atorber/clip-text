import 'package:flutter/material.dart';

class TextLibraryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('文本库')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.description),
            title: Text('会议记录示例'),
            subtitle: Text('2024-06-01 10:05'),
            onTap: () {
              // TODO: 查看/编辑文本
            },
          ),
        ],
      ),
    );
  }
} 