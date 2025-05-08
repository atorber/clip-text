import 'system_audio_recorder_platform_interface.dart';

class SystemAudioRecorder {
  Future<String?> getPlatformVersion() {
    return SystemAudioRecorderPlatform.instance.getPlatformVersion();
  }

  Future<List<Map<String, dynamic>>> listRecordings() {
    return SystemAudioRecorderPlatform.instance.listRecordings();
  }
}
