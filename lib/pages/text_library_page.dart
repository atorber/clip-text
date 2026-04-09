import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../models/transcript.dart';
import '../pages/transcribe_task_detail_page.dart';
import '../utils/colors.dart';

class TextLibraryPage extends StatefulWidget {
  @override
  State<TextLibraryPage> createState() => _TextLibraryPageState();
}

class _TextLibraryPageState extends State<TextLibraryPage> {
  List<Transcript> texts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTexts();
  }

  Future<void> _loadTexts() async {
    setState(() => _loading = true);
    final list = await StorageService.getAllTranscripts();
    setState(() {
      texts = list.map((e) => Transcript.fromMap(e)).toList().reversed.toList();
      _loading = false;
    });
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
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Header and Search
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '录音库',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                  color: AppColors.onSurface,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    Icon(Icons.search, color: AppColors.outline),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: '搜索您的录音库...',
                          hintStyle: TextStyle(color: AppColors.onSurfaceVariant.withAlpha(153)),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: TextStyle(color: AppColors.onSurface, fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('全部', true),
                    const SizedBox(width: 8),
                    _buildFilterChip('已转录', false),
                    const SizedBox(width: 8),
                    _buildFilterChip('已同步', false),
                    const SizedBox(width: 8),
                    _buildFilterChip('草稿', false),
                  ],
                ),
              ),
            ],
          ),
        ),

        // List View
        Expanded(
          child: texts.isEmpty
              ? ListView(
                  children: [
                    const SizedBox(height: 120),
                    Center(child: Text('暂无文本，快去录制并转写吧~', style: TextStyle(fontSize: 16, color: AppColors.onSurfaceVariant))),
                  ],
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(left: 24, right: 24, bottom: 100), // add bottom padding for nav
                  itemCount: texts.length,
                  itemBuilder: (context, index) {
                    final t = texts[index];
                    final isTranscribing = t.text.isEmpty;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          )
                        ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                            t.recordingId.split('/').last,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              fontFamily: 'Manrope',
                                              color: AppColors.onSurface,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: isTranscribing ? AppColors.surfaceContainerHighest : AppColors.primaryFixed,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            isTranscribing ? '转换中' : '已转录',
                                            style: TextStyle(
                                              color: isTranscribing ? AppColors.onSurfaceVariant : AppColors.onPrimaryFixedVariant,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.0,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          _formatDateTime(t.createdAt.toLocal()),
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
                              const SizedBox(width: 16),
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withAlpha(51),
                                      blurRadius: 12,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                                  onPressed: () {
                                    // Navigate to recordings list to play
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Content Preview
                          Text(
                            t.text.length > 50 ? '${t.text.substring(0, 50)}...' : (t.text.isNotEmpty ? t.text : '音频正在云端处理中，请稍后...'),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.onSurface.withAlpha(204),
                              height: 1.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              IconButton(
                                icon: Icon(Icons.delete_outline, color: AppColors.error, size: 22),
                                tooltip: '删除',
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('确认删除'),
                                      content: const Text('确定要删除该转写文本吗？'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
                                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await _deleteTranscript(t.id);
                                  }
                                },
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () async {
                                  if (t.orderId == null || t.orderId!.isEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无orderId，无法查询')));
                                    return;
                                  }
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => TranscribeTaskDetailPage(
                                        orderId: t.orderId!,
                                        autoStartAiChat: false,
                                      ),
                                    ),
                                  );
                                  await _loadTexts();
                                },
                                icon: Icon(Icons.description, size: 16),
                                label: Text('查看结果'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primary,
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              if (t.text.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    if (t.orderId == null || t.orderId!.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无orderId，无法进入AI对话')));
                                      return;
                                    }
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => TranscribeTaskDetailPage(
                                          orderId: t.orderId!,
                                          autoStartAiChat: true,
                                        ),
                                      ),
                                    );
                                    await _loadTexts();
                                  },
                                  icon: Icon(Icons.auto_awesome, size: 16, color: Colors.white),
                                  label: Text('AI 分析', style: TextStyle(color: Colors.white)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : AppColors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _deleteTranscript(String id) async {
    await StorageService.deleteTranscriptById(id);
    await _loadTexts();
  }
} 