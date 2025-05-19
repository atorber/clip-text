import 'dart:io';
import 'dart:typed_data';

Future<File> convertPcmToWav({
  required String pcmPath,
  required String wavPath,
  int sampleRate = 44100,
  int channels = 2,
  int byteRate = 16,
}) async {
  final pcmFile = File(pcmPath);
  final pcmBytes = await pcmFile.readAsBytes();
  final wavFile = File(wavPath);

  int totalAudioLen = pcmBytes.length;
  int totalDataLen = totalAudioLen + 36;
  int longSampleRate = sampleRate;
  int channels_ = channels;
  int byteRate_ = longSampleRate * channels_ * byteRate ~/ 8;

  var header = BytesBuilder();
  header.add([
    82, 73, 70, 70, // 'RIFF'
    ..._intToBytes(totalDataLen, 4),
    87, 65, 86, 69, // 'WAVE'
    102, 109, 116, 32, // 'fmt '
    16, 0, 0, 0, // Subchunk1Size (16 for PCM)
    1, 0, // AudioFormat (1 for PCM)
    channels_, 0, // NumChannels
    ..._intToBytes(longSampleRate, 4),
    ..._intToBytes(byteRate_, 4),
    (channels_ * byteRate ~/ 8), 0, // BlockAlign
    byteRate, 0, // BitsPerSample
    100, 97, 116, 97, // 'data'
    ..._intToBytes(totalAudioLen, 4),
  ]);
  header.add(pcmBytes);

  await wavFile.writeAsBytes(header.toBytes(), flush: true);
  return wavFile;
}

List<int> _intToBytes(int value, int length) {
  final bytes = <int>[];
  for (int i = 0; i < length; i++) {
    bytes.add((value >> (8 * i)) & 0xFF);
  }
  return bytes;
} 