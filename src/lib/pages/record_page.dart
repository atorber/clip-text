import 'package:flutter/material.dart';

class RecordPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, size: 80, color: Colors.deepOrange),
          SizedBox(height: 20),
          Text('点击下方按钮开始录制系统音频'),
          SizedBox(height: 40),
          FloatingActionButton(
            onPressed: () {
              // TODO: 调用原生录音
            },
            child: Icon(Icons.fiber_manual_record),
            backgroundColor: Colors.red,
          ),
        ],
      ),
    );
  }
} 