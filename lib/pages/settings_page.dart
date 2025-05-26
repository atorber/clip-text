import 'package:flutter/material.dart';
import '../services/storage_service.dart';

class SettingsPage extends StatefulWidget {
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _formKey = GlobalKey<FormState>();
  final _appIdController = TextEditingController();
  final _secretKeyController = TextEditingController();
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
    _appIdController.text = config['appId'] ?? '';
    _secretKeyController.text = config['secretKey'] ?? '';
    _chatGptApiKeyController.text = chatGptConfig['apiKey'] ?? '';
    _chatGptBaseUrlController.text = chatGptConfig['baseUrl'] ?? 'https://api.openai.com';
    _chatGptModelController.text = chatGptConfig['model'] ?? 'gpt-3.5-turbo';
    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await StorageService.saveTranscribeApiConfig(
      appId: _appIdController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
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
    return Scaffold(
      // appBar: AppBar(title: Text('转文字API密钥')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(height: 24),
                    Text('讯飞语音转文字API配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('APPID: ${_appIdController.text.isEmpty ? '未设置' : _appIdController.text}', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('SecretKey: ${_secretKeyController.text.isEmpty ? '未设置' : _secretKeyController.text}', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _appIdController,
                      decoration: InputDecoration(labelText: 'APPID'),
                      validator: (v) => v == null || v.trim().isEmpty ? '请输入APPID' : null,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _secretKeyController,
                      decoration: InputDecoration(labelText: 'SecretKey'),
                      validator: (v) => v == null || v.trim().isEmpty ? '请输入SecretKey' : null,
                    ),
                    SizedBox(height: 32),
                    Text('OpenAI API配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('API Key: ${_chatGptApiKeyController.text.isEmpty ? '未设置' : '已设置'}', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('Base URL: ${_chatGptBaseUrlController.text.isEmpty ? '使用默认' : _chatGptBaseUrlController.text}', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('Model: ${_chatGptModelController.text.isEmpty ? '使用默认' : _chatGptModelController.text}', style: TextStyle(fontSize: 13, color: Colors.grey)),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _chatGptApiKeyController,
                      decoration: InputDecoration(
                        labelText: 'ChatGPT API Key',
                        hintText: '请输入OpenAI API Key',
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? '请输入ChatGPT API Key' : null,
                      // obscureText: true,
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _chatGptBaseUrlController,
                      decoration: InputDecoration(
                        labelText: 'Base URL (可选)',
                        hintText: 'https://api.openai.com',
                      ),
                    ),
                    SizedBox(height: 16),
                    TextFormField(
                      controller: _chatGptModelController,
                      decoration: InputDecoration(
                        labelText: 'Model (可选)',
                        hintText: 'gpt-3.5-turbo',
                      ),
                    ),
                    SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveConfig,
                        child: Text('保存'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _secretKeyController.dispose();
    _chatGptApiKeyController.dispose();
    _chatGptBaseUrlController.dispose();
    _chatGptModelController.dispose();
    super.dispose();
  }
} 