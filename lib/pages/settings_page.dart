import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../utils/colors.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  String _provider = StorageService.transcribeProviderIflytek;
  final _appIdController = TextEditingController();
  final _secretKeyController = TextEditingController();
  final _qwenApiKeyController = TextEditingController();
  final _qwenBaseUrlController = TextEditingController();
  final _qwenModelController = TextEditingController();
  final _chatGptApiKeyController = TextEditingController();
  final _chatGptBaseUrlController = TextEditingController();
  final _chatGptModelController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final config = await StorageService.getTranscribeApiConfig();
    final chatGptConfig = await StorageService.getChatGptApiConfig();
    _provider = config['provider'] ?? StorageService.transcribeProviderIflytek;
    _appIdController.text = config['appId'] ?? '';
    _secretKeyController.text = config['secretKey'] ?? '';
    _qwenApiKeyController.text = config['qwenApiKey'] ?? '';
    _qwenBaseUrlController.text =
        config['qwenBaseUrl'] ?? 'https://dashscope.aliyuncs.com/api/v1';
    _qwenModelController.text = config['qwenModel'] ?? 'qwen3-asr-flash';
    _chatGptApiKeyController.text = chatGptConfig['apiKey'] ?? '';
    _chatGptBaseUrlController.text = chatGptConfig['baseUrl'] ?? 'https://api.openai.com';
    _chatGptModelController.text = chatGptConfig['model'] ?? 'gpt-3.5-turbo';
    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await StorageService.saveTranscribeApiConfig(
      provider: _provider,
      appId: _appIdController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
      qwenApiKey: _qwenApiKeyController.text.trim(),
      qwenBaseUrl: _qwenBaseUrlController.text.trim().isEmpty
          ? null
          : _qwenBaseUrlController.text.trim(),
      qwenModel: _qwenModelController.text.trim().isEmpty
          ? null
          : _qwenModelController.text.trim(),
    );
    await StorageService.saveChatGptApiConfig(
      apiKey: _chatGptApiKeyController.text.trim(),
      baseUrl: _chatGptBaseUrlController.text.trim().isEmpty ? null : _chatGptBaseUrlController.text.trim(),
      model: _chatGptModelController.text.trim().isEmpty ? null : _chatGptModelController.text.trim(),
    );
    setState(() => _loading = false);
    
    // 检查widget是否仍然挂载
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存成功')));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 100),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '设置',
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w800,
                fontSize: 32,
                color: AppColors.primary,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '管理您的数字档案和云端同步。',
              style: TextStyle(
                color: AppColors.onSurfaceVariant,
                fontSize: 14,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 32),

            // AI Model Configuration
            Row(
              children: [
                Icon(Icons.psychology, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  'AI 模型配置 (OpenAI)',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                children: [
                  _buildInputField(
                    label: 'Base URL (可选)',
                    controller: _chatGptBaseUrlController,
                    hint: 'https://api.openai.com',
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: '模型名称',
                    controller: _chatGptModelController,
                    hint: '例如：gpt-3.5-turbo',
                  ),
                  const SizedBox(height: 16),
                  _buildInputField(
                    label: 'API 密钥',
                    controller: _chatGptApiKeyController,
                    hint: 'sk-••••••••••••••••••••••••••••••••',
                    isPassword: true,
                    validator: (v) => v == null || v.trim().isEmpty ? '请输入ChatGPT API Key' : null,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Transcription Configuration
            Row(
              children: [
                Icon(Icons.description, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Text(
                  '转录引擎',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '选择转写服务',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: StorageService.transcribeProviderIflytek,
                        label: Text('讯飞'),
                        icon: Icon(Icons.mic),
                      ),
                      ButtonSegment(
                        value: StorageService.transcribeProviderQwen,
                        label: Text('通义千问'),
                        icon: Icon(Icons.auto_awesome),
                      ),
                    ],
                    selected: {_provider},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _provider = selection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_provider == StorageService.transcribeProviderIflytek) ...[
                    _buildInputField(
                      label: 'APPID',
                      controller: _appIdController,
                      hint: '请输入讯飞 APPID',
                      validator: (v) => v == null || v.trim().isEmpty ? '请输入APPID' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'SecretKey',
                      controller: _secretKeyController,
                      hint: '请输入讯飞 SecretKey',
                      isPassword: true,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请输入SecretKey' : null,
                    ),
                  ] else ...[
                    _buildInputField(
                      label: 'API Key',
                      controller: _qwenApiKeyController,
                      hint: 'sk-••••••••••••••••••••••••••••••••',
                      isPassword: true,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? '请输入通义千问 API Key' : null,
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: 'Base URL (可选)',
                      controller: _qwenBaseUrlController,
                      hint: 'https://dashscope.aliyuncs.com/api/v1',
                    ),
                    const SizedBox(height: 16),
                    _buildInputField(
                      label: '模型名称',
                      controller: _qwenModelController,
                      hint: 'qwen3-asr-flash',
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveConfig,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(100),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  '保存设置',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        TextFormField(
          controller: controller,
          obscureText: isPassword,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.outline),
            filled: true,
            fillColor: AppColors.surfaceContainerHigh,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: isPassword
                ? Icon(Icons.visibility, color: AppColors.onSurfaceVariant)
                : null,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _secretKeyController.dispose();
    _qwenApiKeyController.dispose();
    _qwenBaseUrlController.dispose();
    _qwenModelController.dispose();
    _chatGptApiKeyController.dispose();
    _chatGptBaseUrlController.dispose();
    _chatGptModelController.dispose();
    super.dispose();
  }
} 