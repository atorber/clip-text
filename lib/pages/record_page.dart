import 'package:flutter/material.dart';
import '../services/system_audio_recorder_service.dart';
// import '../services/audio_service.dart'; // 已移除未使用的导入
import '../main.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/pcm_to_wav.dart';
import 'package:system_audio_recorder/system_audio_recorder.dart';

class RecordPage extends StatefulWidget {
  @override
  State<RecordPage> createState() => _RecordPageState();
}

class _RecordPageState extends State<RecordPage> {
  bool isRecording = false;
  String? recordPath;
  Timer? _timer;
  int _elapsedSeconds = 0;

  void _startTimer() {
    _timer?.cancel();
    _elapsedSeconds = 0;
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _elapsedSeconds = 0;
    });
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // 新增：封装保存录音逻辑
  Future<void> _saveRecording(String path) async {
    final extDir = await getExternalStorageDirectory();
    final recordingsDir = Directory('${extDir!.path}/Recordings');
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    final fileName = 'system_record_${DateTime.now().millisecondsSinceEpoch}.pcm';
    final newPath = '${recordingsDir.path}/$fileName';
    final file = File(path);
    final newFile = await file.copy(newPath);
    await file.delete();
    // PCM转WAV, fileName使用当前时间，格式为yyyyMMddHHmmss，例如：20250519163000.wav
    final now = DateTime.now();
    final wavName =
        '${now.year.toString().padLeft(4, '0')}'
        '${now.month.toString().padLeft(2, '0')}'
        '${now.day.toString().padLeft(2, '0')}'
        '${now.hour.toString().padLeft(2, '0')}'
        '${now.minute.toString().padLeft(2, '0')}'
        '${now.second.toString().padLeft(2, '0')}.wav';

    final wavPath = p.join(recordingsDir.path, wavName);
    await convertPcmToWav(pcmPath: newFile.path, wavPath: wavPath);
    // 删除原始PCM文件
    await newFile.delete();
    // 弹窗询问后续操作
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('录音已保存'),
        content: Text('请选择接下来的操作'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('list'),
            child: Text('去列表播放'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('record'),
            child: Text('开始新录制'),
          ),
        ],
      ),
    );
    if (action == 'list') {
      final mainTabState = context.findAncestorStateOfType<MainTabPageState>();
      if (mainTabState != null && mainTabState.mounted) {
        mainTabState.setState(() {
          mainTabState.currentIndex = 1;
        });
      }
    } else if (action == 'record') {
      _onRecordButtonPressed();
    }
    // 保存后清空recordPath
    recordPath = null;
  }

  void _onRecordButtonPressed() async {
    if (!isRecording) {
      setState(() => isRecording = true);
      recordPath = await SystemAudioRecorderService.startRecord('com.android.chrome');
      if (recordPath != null) {
        try {
          await SystemAudioRecorder().startFloatingRecorder();
        } catch (e) {
          if (e.toString().contains('NO_PERMISSION')) {
            if (mounted) {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('需要悬浮窗权限'),
                  content: Text('请在系统设置中授予悬浮窗权限后再试。'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('确定'))],
                ),
              );
            }
          }
        }
        _startTimer();
      } else {
        setState(() => isRecording = false);
        // 可选：提示用户录音授权失败
      }
    } else {
      print('准备停止录制');
      final path = await SystemAudioRecorderService.stopRecord();
      print('停止录制返回: $path');
      setState(() => isRecording = false);
      _stopTimer();

      if (path != null) {
        // 先询问是否保存
        final save = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('是否保存录音？'),
            content: Text('录音完成，是否保存该录音？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('否'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('是'),
              ),
            ],
          ),
        );
        if (save == true) {
          await _saveRecording(path);
        } else {
          // 不保存，删除临时文件
          try {
            await File(path).delete();
          } catch (e) {}
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _listenFloatingRecorderEvent();
  }

  void _listenFloatingRecorderEvent() {
    SystemAudioRecorder.setFloatingRecorderEventHandler((event) async {
      if (event == 'stop') {
        if (isRecording) {
          setState(() => isRecording = false);
          _stopTimer();
          final save = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('是否保存录音？'),
              content: Text('录音完成，是否保存该录音？'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('否'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('是'),
                ),
              ],
            ),
          );
          if (save == true) {
            if (recordPath != null) {
              await _saveRecording(recordPath!);
            }
          } else {
            if (recordPath != null) {
              try {
                await File(recordPath!).delete();
              } catch (e) {}
              recordPath = null;
            }
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.mic, size: 80, color: Colors.deepOrange),
          SizedBox(height: 20),
          Text(isRecording ? '正在录制...  ${_formatDuration(_elapsedSeconds)}' : '点击下方按钮开始录制系统音频'),
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