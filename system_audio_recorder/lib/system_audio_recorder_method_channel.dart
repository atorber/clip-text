import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'system_audio_recorder_platform_interface.dart';

/// An implementation of [SystemAudioRecorderPlatform] that uses method channels.
class MethodChannelSystemAudioRecorder extends SystemAudioRecorderPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('system_audio_recorder');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  @override
  Future<List<Map<String, dynamic>>> listRecordings() async {
    final files = await methodChannel.invokeMethod<List<dynamic>>('listRecordings');
    if (files == null) return [];
    return files.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
