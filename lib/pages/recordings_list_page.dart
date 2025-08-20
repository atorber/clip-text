import 'dart:io';
import 'package:flutter/material.dart';
import '../models/recording.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'submit_transcribe_task_page.dart';
import '../services/storage_service.dart';
import 'transcribe_task_detail_page.dart';

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

  /// 加载本地录音文件列表，并按修改时间倒序排序；
  /// 同时检测每条录音对应的转写任务是否已有文本结果。
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
          .toList();
      // 默认排序改为：按时间倒序（最新在前）
      newRecordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
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
    return "${dt.year.toString().padLeft(4, '0')}-"
        "${dt.month.toString().padLeft(2, '0')}-"
        "${dt.day.toString().padLeft(2, '0')} "
        "${dt.hour.toString().padLeft(2, '0')}:"
        "${dt.minute.toString().padLeft(2, '0')}:"
        "${dt.second.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadRecordings,
      child: _loading
          ? Center(child: CircularProgressIndicator())
          : recordings.isEmpty
          ? ListView(
              children: [
                SizedBox(height: 120),
                Center(child: Text('暂无录音，快去录制吧~', style: TextStyle(fontSize: 16, color: Colors.grey))),
              ],
            )
          : ListView.builder(
              itemCount: recordings.length,
              itemBuilder: (context, index) {
                final rec = recordings[index];
                return Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.audiotrack),
                      title: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec.filePath.split('/').last,
                            style: TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4),
                          Text(
                            '大小: \\${_formatSize(rec.size)}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          Text(
                            '时间: \\${_formatDateTime(rec.createdAt)}',
                            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                          ),
                          SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (_playingIndex == index && _playerState?.playing == true)
                                IconButton(
                                  icon: Icon(Icons.pause),
                                  tooltip: '暂停',
                                  onPressed: _pauseRecording,
                                )
                              else if (_playingIndex == index && _playerState?.playing == false && _playerState?.processingState == ProcessingState.ready)
                                IconButton(
                                  icon: Icon(Icons.play_arrow),
                                  tooltip: '继续播放',
                                  onPressed: _resumeRecording,
                                )
                              else
                                IconButton(
                                  icon: Icon(Icons.play_arrow),
                                  tooltip: '播放',
                                  onPressed: () => _playRecording(rec, index),
                                ),
                              if (_playingIndex == index)
                                IconButton(
                                  icon: Icon(Icons.stop),
                                  tooltip: '停止',
                                  onPressed: _stopRecording,
                                ),
                              IconButton(
                                icon: Icon(Icons.delete),
                                tooltip: '删除',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: Text('确认删除'),
                                      content: Text('确定要删除该录音吗？'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: Text('删除')),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _deleteRecording(rec);
                                  }
                                },
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => SubmitTranscribeTaskPage(audioPath: rec.filePath),
                                    ),
                                  );
                                },
                                child: Text('转文字'),
                              ),
                              // 如果该录音已有转录文本，显示"查看文字"按钮
                              if (_transcriptionOrderIds.containsKey(rec.filePath))
                                TextButton(
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
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.green,
                                  ),
                                  child: Text('查看文字'),
                                ),
                            ],
                          ),
                        ],
                      ),
                      onTap: () => _playRecording(rec, index),
                    ),
                    if (_playingIndex == index && _duration != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            Slider(
                              min: 0,
                              max: _duration!.inMilliseconds.toDouble(),
                              value: (_position?.inMilliseconds ?? 0).clamp(0, _duration!.inMilliseconds).toDouble(),
                              onChanged: (v) async {
                                await _player?.seek(Duration(milliseconds: v.toInt()));
                              },
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(_formatDateTime(rec.createdAt)),
                                Text(_formatDateTime(rec.createdAt.add(_duration!))),
                              ],
                            ),
                          ],
                        ),
                      ),
                    Divider(height: 1, thickness: 1, indent: 16, endIndent: 16),
                  ],
                );
              },
            ),
    );
  }
} 