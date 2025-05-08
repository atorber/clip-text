import 'package:flutter/services.dart';

class SystemAudioRecorderService {
  static const MethodChannel _channel = MethodChannel('system_audio_recorder');

  static Future<String?> startRecord(String packageName) async {
    return await _channel.invokeMethod('startRecord', {'packageName': packageName});
  }

  static Future<String?> stopRecord() async {
    return await _channel.invokeMethod('stopRecord');
  }
} 