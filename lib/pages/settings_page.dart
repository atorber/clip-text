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
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _loading = true);
    final config = await StorageService.getTranscribeApiConfig();
    _appIdController.text = config['appId'] ?? '';
    _secretKeyController.text = config['secretKey'] ?? '';
    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    await StorageService.saveTranscribeApiConfig(
      appId: _appIdController.text.trim(),
      secretKey: _secretKeyController.text.trim(),
    );
    setState(() => _loading = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存成功')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('设置')),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('转文字API密钥', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    SizedBox(height: 8),
                    Text('当前APPID: \\n' + _appIdController.text, style: TextStyle(fontSize: 13, color: Colors.grey)),
                    Text('当前SecretKey: \\n' + _secretKeyController.text, style: TextStyle(fontSize: 13, color: Colors.grey)),
                    SizedBox(height: 24),
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
    super.dispose();
  }
} 