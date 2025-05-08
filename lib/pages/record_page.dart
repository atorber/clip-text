import 'package:flutter/material.dart';
import '../services/system_audio_recorder_service.dart';
// import '../services/audio_service.dart'; // 已移除未使用的导入
import '../services/storage_service.dart';
import '../models/recording.dart';
import 'package:uuid/uuid.dart';

class RecordPage extends StatefulWidget {
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool isRecording = false;
  String? recordPath;

  void _onRecordButtonPressed() async {
    if (!isRecording) {
      setState(() => isRecording = true);
      recordPath = await SystemAudioRecorderService.startRecord('com.android.chrome');
    } else {
      print('准备停止录制');
      final path = await SystemAudioRecorderService.stopRecord();
      print('停止录制返回: $path');
      setState(() => isRecording = false);

      if (path != null) {
        final id = Uuid().v4();
        final rec = Recording(
          id: id,
          filePath: path,
          createdAt: DateTime.now(),
          size: 0, // 目前无法获取实际大小，填 0
          sourceApp: 'com.android.chrome',
        );
        await StorageService.insertRecording(rec.toMap());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('录音已保存')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, size: 80, color: Colors.deepOrange),
          SizedBox(height: 20),
          Text(isRecording ? '正在录制...' : '点击下方按钮开始录制系统音频'),
          SizedBox(height: 40),
          ElevatedButton.icon(
            onPressed: _onRecordButtonPressed,
            icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white),
            label: Text(isRecording ? '停止录制' : '开始录制', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRecording ? Colors.grey : Colors.red,
              minimumSize: Size(160, 48),
            ),
          ),
        ],
      ),
    );
  }
} 