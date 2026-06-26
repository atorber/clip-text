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
import '../utils/colors.dart';

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
        if (!mounted) return;
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
          } catch (e) {
            // 忽略删除临时文件的错误
            print('删除临时文件失败: $e');
          }
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
          if (!mounted) return;
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
              } catch (e) {
                // 忽略删除临时文件的错误
                print('删除临时文件失败: $e');
              }
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          const SizedBox(height: 24),
          // Header / Metadata row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '当前会话',
                    style: TextStyle(
                      color: AppColors.onSurfaceVariant,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '未命名档案_042',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Manrope',
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(Icons.language, color: AppColors.primary, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      '中文 (简体)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.expand_more, color: AppColors.outline, size: 12),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // Visualizer
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Inner gradient
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(32),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AppColors.surfaceContainerLow.withAlpha(51),
                      ],
                    ),
                  ),
                ),
                // Mock waveform
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildWaveformBar(16, AppColors.outlineVariant),
                    _buildWaveformBar(24, AppColors.outlineVariant),
                    _buildWaveformBar(48, AppColors.primary),
                    _buildWaveformBar(72, AppColors.primary),
                    _buildWaveformBar(96, AppColors.primary),
                    _buildWaveformBar(64, AppColors.primary),
                    _buildWaveformBar(40, AppColors.primary),
                    _buildWaveformBar(72, AppColors.primary),
                    _buildWaveformBar(84, AppColors.primary),
                    _buildWaveformBar(96, AppColors.primary),
                    _buildWaveformBar(64, AppColors.primary),
                    _buildWaveformBar(72, AppColors.primary),
                    _buildWaveformBar(96, AppColors.primary),
                    _buildWaveformBar(112, AppColors.primary),
                    _buildWaveformBar(84, AppColors.primary),
                    _buildWaveformBar(104, AppColors.primary),
                    _buildWaveformBar(64, AppColors.outlineVariant),
                    _buildWaveformBar(48, AppColors.outlineVariant),
                    _buildWaveformBar(56, AppColors.outlineVariant),
                    _buildWaveformBar(32, AppColors.outlineVariant),
                    _buildWaveformBar(24, AppColors.outlineVariant),
                  ],
                ),
                Positioned(
                  bottom: 24,
                  child: Text(
                    _formatDuration(_elapsedSeconds),
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Fake Realtime Transcription
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(32),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.tertiary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '实时转录',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.open_in_full, size: 16, color: AppColors.primary),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      color: AppColors.onSurface.withAlpha(230),
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(text: '“……声音的架构不仅仅是记录频率，而是捕捉说话者呼吸背后的'),
                      WidgetSpan(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                          decoration: BoxDecoration(
                            color: AppColors.primaryFixed,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '意图',
                            style: TextStyle(color: AppColors.onPrimaryFixedVariant, fontSize: 16),
                          ),
                        ),
                      ),
                      TextSpan(text: '。当我们存档这些时刻时，我们本质上是在构建一个人类意识的图书馆……”'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.description, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text('笔记', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant, letterSpacing: 2)),
                ],
              ),
              GestureDetector(
                onTap: _onRecordButtonPressed,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isRecording)
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.tertiary.withAlpha(12),
                        ),
                      ),
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isRecording
                            ? [AppColors.tertiary, AppColors.error]
                            : [AppColors.primary, AppColors.primaryContainer],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.onSurface.withAlpha(38),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Icon(
                        isRecording ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(Icons.layers, color: AppColors.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  Text('图层', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.onSurfaceVariant, letterSpacing: 2)),
                ],
              ),
            ],
          ),
            const SizedBox(height: 80), // Space for bottom nav
          ],
        ),
      ),
    );
  }

  Widget _buildWaveformBar(double height, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      width: 4,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
} 