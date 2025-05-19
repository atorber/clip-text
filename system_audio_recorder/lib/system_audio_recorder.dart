import 'system_audio_recorder_platform_interface.dart';
import 'package:flutter/services.dart';

class SystemAudioRecorder {
  Future<String?> getPlatformVersion() {
    return SystemAudioRecorderPlatform.instance.getPlatformVersion();
  }

  Future<List<Map<String, dynamic>>> listRecordings() {
    return SystemAudioRecorderPlatform.instance.listRecordings();
  }

  Future<void> startFloatingRecorder() async {
    await SystemAudioRecorderPlatform.instance.startFloatingRecorder();
  }

  Future<void> stopFloatingRecorder() async {
    await SystemAudioRecorderPlatform.instance.stopFloatingRecorder();
  }

  static const MethodChannel _eventChannel = MethodChannel('system_audio_recorder');
  static void setFloatingRecorderEventHandler(Future<void> Function(String event) handler) {
    _eventChannel.setMethodCallHandler((call) async {
      if (call.method == 'onFloatingRecorderEvent') {
        await handler(call.arguments as String);
      }
    });
  }
}
