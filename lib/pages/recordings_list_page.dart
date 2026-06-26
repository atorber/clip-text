import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recording.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'submit_transcribe_task_page.dart';
import '../services/storage_service.dart';
import 'transcribe_task_detail_page.dart';
import '../utils/colors.dart';

class RecordingsListPage extends StatefulWidget {
  @override
  State<RecordingsListPage> createState() => _RecordingsListPageState();
}

class _RecordingsListPageState extends State<RecordingsListPage> {
  List<Recording> recordings = [];
  bool _loading = false;
  AudioPlayer? _player;
  int? _playingIndex;
  PlayerState? _playerState;
  Duration? _duration;
  Duration? _position;
  
  // 存储录音文件路径到转写任务orderId的映射
  Map<String, String> _transcriptionOrderIds = {};

  @override
  void initState() {
    super.initState();
    _loadRecordings();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecordings();
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    setState(() => _loading = true);
    try {
      final dir = await getExternalStorageDirectory();
      final recordingsDir = Directory('${dir!.path}/Recordings');
      if (!await recordingsDir.exists()) {
        await recordingsDir.create(recursive: true);
      }
      final files = recordingsDir
          .listSync()
          .where((f) => f is File && p.extension(f.path).toLowerCase() == '.wav')
          .map((f) => File(f.path))
          .toList();
      
      final newRecordings = files
          .map((f) => Recording(
                id: p.basename(f.path),
                filePath: f.path,
                createdAt: f.statSync().modified,
                size: f.lengthSync(),
                sourceApp: null,
              ))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      // 检查每个录音是否有对应的转录任务
      final allTranscripts = await StorageService.getAllTranscripts();
      final newTranscriptionOrderIds = <String, String>{};
      
      for (final recording in newRecordings) {
        // 查找使用相同音频文件路径且有转录文本的任务
        for (final transcript in allTranscripts) {
          if (transcript['recordingId'] == recording.filePath && 
              transcript['text'] != null && 
              (transcript['text'] as String).trim().isNotEmpty) {
            newTranscriptionOrderIds[recording.filePath] = transcript['orderId'];
            break;
          }
        }
      }
      
      setState(() {
        recordings = newRecordings;
        _transcriptionOrderIds = newTranscriptionOrderIds;
      });
    } catch (e) {
      setState(() {
        recordings = [];
        _transcriptionOrderIds = {};
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteRecording(Recording rec) async {
    try {
      final file = File(rec.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      // 忽略删除文件的错误
      print('删除录音文件失败: $e');
    }
    await _loadRecordings();
  }

  void _playRecording(Recording rec, int index) async {
    if (_player != null) {
      await _player!.stop();
      await _player!.dispose();
    }
    final player = AudioPlayer();
    setState(() {
      _player = player;
      _playingIndex = index;
      _duration = null;
      _position = Duration.zero;
    });
    player.playerStateStream.listen((state) {
      setState(() {
        _playerState = state;
      });
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingIndex = null;
          _position = Duration.zero;
        });
        player.seek(Duration.zero);
        player.stop();
      }
    });
    player.durationStream.listen((d) {
      setState(() {
        _duration = d;
      });
    });
    player.positionStream.listen((p) {
      setState(() {
        _position = p;
      });
    });
    try {
      await player.setFilePath(rec.filePath);
      await player.play();
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('播放失败'),
            content: Text('无法播放该录音文件。'),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text('确定'))],
          ),
        );
        setState(() {
          _player = null;
          _playingIndex = null;
        });
      }
    }
  }

  void _pauseRecording() async {
    await _player?.pause();
  }

  void _resumeRecording() async {
    await _player?.play();
  }

  void _stopRecording() async {
    await _player?.stop();
    setState(() {
      _playingIndex = null;
      _position = Duration.zero;
    });
  }

  String _formatSize(int size) {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String _formatDateTime(DateTime dt) {
    return "${dt.year.toString()}年"
        "${dt.month.toString().padLeft(2, '0')}月"
        "${dt.day.toString().padLeft(2, '0')}日 "
        "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRecordings,
      child: _loading
          ? const Center(child: CircularProgressIndicator())
          : recordings.isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Center(
                  child: Text('暂无录音，快去录制吧~', style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant)),
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 100), // add bottom padding for nav
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final rec = recordings[index];
                final fileName = rec.filePath.split('/').last;
                final bool hasTranscript = _transcriptionOrderIds.containsKey(rec.filePath);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(5),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fileName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          fontFamily: 'Manrope',
                                          color: AppColors.onSurface,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (hasTranscript) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryFixed,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          '已转录',
                                          style: TextStyle(
                                            color: AppColors.onPrimaryFixedVariant,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      _formatDateTime(rec.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(width: 4, height: 4, decoration: BoxDecoration(color: AppColors.outlineVariant, shape: BoxShape.circle)),
                                    const SizedBox(width: 8),
                                    Text(
                                      _formatSize(rec.size),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.onSurfaceVariant,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Play/Pause Button
                          GestureDetector(
                            onTap: () {
                              if (_playingIndex == index && _playerState?.playing == true) {
                                _pauseRecording();
                              } else if (_playingIndex == index && _playerState?.playing == false) {
                                _resumeRecording();
                              } else {
                                _playRecording(rec, index);
                              }
                            },
                            child: Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withAlpha(51),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                (_playingIndex == index && _playerState?.playing == true)
                                  ? Icons.pause
                                  : Icons.play_arrow,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (_playingIndex == index && _duration != null) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 4,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                                  activeTrackColor: AppColors.primary,
                                  inactiveTrackColor: AppColors.outlineVariant,
                                  thumbColor: AppColors.primary,
                                ),
                                child: Slider(
                                  min: 0,
                                  max: _duration!.inMilliseconds.toDouble(),
                                  value: (_position?.inMilliseconds ?? 0).clamp(0, _duration!.inMilliseconds).toDouble(),
                                  onChanged: (v) async {
                                    await _player?.seek(Duration(milliseconds: v.toInt()));
                                  },
                                ),
                              ),
                            ),
                            Text(
                              '${(_position?.inSeconds ?? 0) ~/ 60}:${((_position?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')} / ${_duration!.inSeconds ~/ 60}:${(_duration!.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (_playingIndex == index)
                            IconButton(
                              icon: Icon(Icons.stop, color: AppColors.onSurfaceVariant, size: 20),
                              tooltip: '停止',
                              onPressed: _stopRecording,
                            ),
                          IconButton(
                            icon: Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                            tooltip: '删除',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('确认删除'),
                                  content: const Text('确定要删除该录音吗？'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await _deleteRecording(rec);
                              }
                            },
                          ),
                          const Spacer(),
                          if (!hasTranscript)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SubmitTranscribeTaskPage(audioPath: rec.filePath),
                                  ),
                                );
                              },
                              icon: Icon(Icons.text_snippet, size: 16),
                              label: Text('转写'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          if (hasTranscript)
                            TextButton.icon(
                              onPressed: () {
                                final orderId = _transcriptionOrderIds[rec.filePath]!;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TranscribeTaskDetailPage(
                                      orderId: orderId,
                                      autoStartAiChat: false,
                                    ),
                                  ),
                                );
                              },
                              icon: Icon(Icons.visibility, size: 16),
                              label: Text('查看'),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
} 