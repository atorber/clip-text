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
    if (!mounted) return;
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
    if (!mounted) return;
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

  /// 点击"悬浮按钮"：
  /// - 调用插件显示悬浮窗；
  /// - 插件内部会最小化应用（moveTaskToBack）；
  /// - 若无悬浮窗权限则给出提示。
  Future<void> _onShowFloatingButtonPressed() async {
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
  }

  /// 停止录制的通用逻辑：
  /// - 停止录音服务
  /// - 重置状态和计时器
  /// - 询问是否保存录音
  /// - 根据用户选择保存或删除文件
  Future<void> _stopRecording() async {
    if (!isRecording) return;
    
    print('准备停止录制');
    final path = await SystemAudioRecorderService.stopRecord();
    print('停止录制返回: $path');
    setState(() => isRecording = false);
    _stopTimer();

    if (path != null) {
      // 先询问是否保存
      if (!mounted) return;
      final save = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('是否保存录音？'),
          content: Text('录音完成，是否保存该录音？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('否'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
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
        } catch (e) {
          // 忽略删除临时文件的错误
          print('删除临时文件失败: $e');
        }
      }
    }
  }

  /// 录音按钮点击处理：
  /// - 未在录制：发起系统授权；仅在授权成功并返回有效路径后切换为"录制中"。
  /// - 用户取消/授权失败：保持"开始录制"状态并不启动计时。
  /// - 录制中：停止录制并提示是否保存。
  void _onRecordButtonPressed() async {
    if (!isRecording) {
      try {
        final path = await SystemAudioRecorderService.startRecord('com.android.chrome');
        if (path != null) {
          setState(() {
            isRecording = true;
            recordPath = path;
          });
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
          // 授权未通过或未返回有效路径，保持未录制状态
          if (mounted) {
            setState(() {
              isRecording = false;
              recordPath = null;
            });
          }
        }
      } catch (e) {
        // 处理平台异常（例如用户取消屏幕捕获授权）
        if (mounted) {
          setState(() {
            isRecording = false;
            recordPath = null;
          });
        }
      }
    } else {
      // 调用通用的停止录制逻辑
      await _stopRecording();
    }
  }

  @override
  void initState() {
    super.initState();
    _listenFloatingRecorderEvent();
    
    // 检查是否是从悬浮窗选择"是"启动的
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFloatingWindowIntent();
    });
  }

  /// 检查是否是从悬浮窗选择"是"启动的，如果是则直接跳转到录音列表
  void _checkFloatingWindowIntent() {
    // 由于Flutter的限制，我们无法直接读取启动意图的extra
    // 但是我们可以通过其他方式实现直接跳转
    // 这里我们使用一个延迟检查，如果是从悬浮窗启动的，会在录音完成后自动跳转
    print('检查悬浮窗启动意图 - 当前无法直接读取，等待录音完成后的处理');
  }

  void _listenFloatingRecorderEvent() {
    SystemAudioRecorder.setFloatingRecorderEventHandler((event) async {
      print('收到悬浮窗事件: $event');
      
      if (event == 'start') {
        // 悬浮窗开始录音事件
        print('悬浮窗启动录音事件，当前状态: isRecording=$isRecording');
        
        if (!isRecording) {
          // 悬浮窗已经启动了录音，我们只需要同步状态
          setState(() {
            isRecording = true;
            // 注意：这里不设置recordPath，因为悬浮窗的录音路径可能不同
            // recordPath将在停止录音时通过stopRecord获取
          });
          _startTimer();
          print('悬浮窗启动录音状态已同步，启动计时器');
        } else {
          print('APP已在录音状态，忽略悬浮窗启动事件');
        }
      } else if (event == 'stop') {
        // 悬浮窗停止录音事件 - 自动保存录音文件
        print('处理悬浮窗停止录音事件，当前状态: isRecording=$isRecording');
        
        if (isRecording) {
          print('立即处理悬浮窗停止录音事件');
          await _handleFloatingWindowStop();
          
          // 悬浮窗录音完成后，直接跳转到录音列表页面
          print('悬浮窗录音处理完成，准备跳转到录音列表');
          _goToRecordingsList();
        } else {
          print('APP未在录音状态，忽略悬浮窗停止事件');
        }
      }
    });
  }

  /// 处理悬浮窗停止录音的具体逻辑
  Future<void> _handleFloatingWindowStop() async {
    print('开始处理悬浮窗停止录音');
    print('当前recordPath: $recordPath');
    
    setState(() => isRecording = false);
    _stopTimer();
    
    // 先调用stopRecord获取最终的录音文件路径，然后自动保存
    try {
      print('调用SystemAudioRecorderService.stopRecord()...');
      final finalPath = await SystemAudioRecorderService.stopRecord();
      print('悬浮窗停止录音返回路径: $finalPath');
      
      if (finalPath != null && finalPath.isNotEmpty) {
        print('使用stopRecord返回的路径保存: $finalPath');
        // 悬浮窗录音自动保存，但不显示对话框
        await _saveRecordingSilently(finalPath);
        print('悬浮窗录音已自动保存（静默模式）');
      } else {
        print('stopRecord返回路径无效，尝试使用recordPath');
        // 如果stopRecord没有返回路径，尝试使用recordPath
        if (recordPath != null && recordPath!.isNotEmpty) {
          print('使用recordPath保存悬浮窗录音: $recordPath');
          await _saveRecordingSilently(recordPath!);
          print('使用recordPath保存悬浮窗录音（静默模式）');
        } else {
          print('ERROR: 两个路径都无效，无法保存录音文件');
          print('recordPath: $recordPath');
          print('finalPath: $finalPath');
          
          // 尝试从插件获取录音列表，看是否有可用的录音文件
          await _trySaveFromRecordingsList();
        }
      }
    } catch (e) {
      print('悬浮窗录音自动保存失败: $e');
      // 如果stopRecord失败，尝试使用recordPath
      if (recordPath != null && recordPath!.isNotEmpty) {
        try {
          print('使用recordPath作为备用方案保存: $recordPath');
          await _saveRecordingSilently(recordPath!);
          print('使用recordPath保存悬浮窗录音（备用方案，静默模式）');
        } catch (e2) {
          print('备用保存方案也失败: $e2');
          // 最后尝试从录音列表获取
          await _trySaveFromRecordingsList();
        }
      } else {
        print('ERROR: recordPath也无效，无法使用备用方案');
        // 尝试从录音列表获取
        await _trySaveFromRecordingsList();
      }
    }
    
    recordPath = null;
  }

  /// 尝试从录音列表获取并保存录音文件
  Future<void> _trySaveFromRecordingsList() async {
    print('尝试从录音列表获取录音文件...');
    try {
      // 获取录音列表
      final recordings = await SystemAudioRecorder().listRecordings();
      print('获取到录音列表: $recordings');
      
      if (recordings.isNotEmpty) {
        // 获取最新的录音文件
        final latestRecording = recordings.last;
        print('最新录音文件: $latestRecording');
        
        if (latestRecording['path'] != null) {
          final path = latestRecording['path'] as String;
          print('尝试保存最新录音文件: $path');
          await _saveRecordingSilently(path);
          print('从录音列表保存成功');
        } else {
          print('最新录音文件路径为空');
        }
      } else {
        print('录音列表为空，无法获取录音文件');
      }
    } catch (e) {
      print('从录音列表获取录音文件失败: $e');
    }
  }

  /// 静默保存录音文件，不显示对话框
  Future<void> _saveRecordingSilently(String path) async {
    print('开始静默保存录音文件，输入路径: $path');
    
    try {
      // 检查输入文件是否存在
      final inputFile = File(path);
      if (!await inputFile.exists()) {
        print('ERROR: 输入文件不存在: $path');
        return;
      }
      
      final inputFileSize = await inputFile.length();
      print('输入文件大小: $inputFileSize 字节');
      
      final extDir = await getExternalStorageDirectory();
      print('外部存储目录: ${extDir?.path}');
      
      final recordingsDir = Directory('${extDir!.path}/Recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
        print('创建录音目录: ${recordingsDir.path}');
      } else {
        print('录音目录已存在: ${recordingsDir.path}');
      }
      
      final fileName = 'system_record_${DateTime.now().millisecondsSinceEpoch}.pcm';
      final newPath = '${recordingsDir.path}/$fileName';
      print('PCM文件路径: $newPath');
      
      final file = File(path);
      final newFile = await file.copy(newPath);
      print('PCM文件复制完成: ${newFile.path}');
      
      await file.delete();
      print('原始文件已删除');
      
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
      print('WAV文件路径: $wavPath');
      
      print('开始PCM转WAV转换...');
      await convertPcmToWav(pcmPath: newFile.path, wavPath: wavPath);
      print('PCM转WAV转换完成');
      
      // 删除原始PCM文件
      await newFile.delete();
      print('临时PCM文件已删除');
      
      // 验证最终文件
      final finalWavFile = File(wavPath);
      if (await finalWavFile.exists()) {
        final finalSize = await finalWavFile.length();
        print('录音文件已成功保存到: $wavPath');
        print('最终文件大小: $finalSize 字节');
      } else {
        print('ERROR: 最终WAV文件不存在: $wavPath');
      }
      
    } catch (e) {
      print('静默保存录音文件失败: $e');
      rethrow;
    }
  }

  /// 跳转到录音列表页面
  void _goToRecordingsList() {
    if (mounted) {
      // 查找主页面状态并切换到录音列表标签
      final mainTabState = context.findAncestorStateOfType<MainTabPageState>();
      if (mainTabState != null && mainTabState.mounted) {
        mainTabState.setState(() {
          mainTabState.currentIndex = 1; // 切换到录音列表标签
        });
        print('已跳转到录音列表页面');
      } else {
        print('无法找到主页面状态，跳转失败');
      }
    }
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
          Column(
            children: [
              ElevatedButton.icon(
                onPressed: _onRecordButtonPressed,
                icon: Icon(isRecording ? Icons.stop : Icons.fiber_manual_record, color: Colors.white),
                label: Text(isRecording ? '停止录制' : '开始录制', style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isRecording ? Colors.grey : Colors.red,
                  minimumSize: Size(160, 48),
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _onShowFloatingButtonPressed,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(160, 44),
                ),
                child: Text('悬浮按钮'),
              ),
            ],
          ),
        ],
      ),
    );
  }
} 