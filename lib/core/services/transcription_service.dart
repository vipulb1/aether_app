import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';

import 'package:whisper_flutter_new/whisper_flutter_new.dart';

import '../../features/library/domain/entities/recording.dart';

class TranscriptionService {
  /// Transcribe audio file using Whisper Kit.
  ///
  /// The Whisper class downloads the chosen model automatically on first use.
  /// Progressive updates are emitted as transcript segments after transcription.
  static Future<List<TranscriptLine>> transcribeAudio(String filePath) async {
    final transcript = <TranscriptLine>[];
    await for (final chunk in transcribeAudioStream(filePath)) {
      transcript.addAll(chunk);
    }
    return transcript;
  }

  /// Transcribe audio in batches for the detail screen.
  static Stream<List<TranscriptLine>> transcribeAudioStream(
    String filePath,
  ) async* {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('Audio file not found: $filePath');
    }
    final length = await file.length();
    if (length < 44) {
      throw Exception('Audio file is too small or not a valid WAV: $filePath');
    }

    final info = await _readWavHeader(file);
    // Whisper prefers 16kHz mono PCM16, but we can convert other PCM and float formats.
    if (info['audioFormat'] != 1 && info['audioFormat'] != 3) {
      throw Exception(
        'Unsupported WAV audio format: ${info['audioFormat']} (expected PCM16 or float32)',
      );
    }
    print(
      'WAV header for $filePath: audioFormat=${info['audioFormat']}, channels=${info['numChannels']}, sampleRate=${info['sampleRate']}, bits=${info['bitsPerSample']}',
    );

    String pathToTranscribe = filePath;
    File? tempResampled;
    final needsConversion =
        info['audioFormat'] != 1 ||
        info['bitsPerSample'] != 16 ||
        info['numChannels'] != 1 ||
        info['sampleRate'] != 16000;

    if (needsConversion) {
      tempResampled = await _resampleTo16k(file);
      pathToTranscribe = tempResampled.path;
      if (!await File(pathToTranscribe).exists()) {
        throw Exception('Resampled file was not created: $pathToTranscribe');
      }
      print('Converted audio to supported 16k PCM16 mono: $pathToTranscribe');
    }

    try {
      final data = await _extractWavData(File(pathToTranscribe));
      final rms = _computeRms16(data);
      print('WAV RMS for $pathToTranscribe: $rms');
      if (rms < 500) {
        throw Exception('Audio appears silent or too quiet (RMS=$rms)');
      }
    } catch (e) {
      print('WAV data check warning for $pathToTranscribe: $e');
    }

    try {
      final convertedInfo = await _readWavHeader(File(pathToTranscribe));
      print(
        'Transcription source header for $pathToTranscribe: '
        'audioFormat=${convertedInfo['audioFormat']}, '
        'channels=${convertedInfo['numChannels']}, '
        'sampleRate=${convertedInfo['sampleRate']}, '
        'bits=${convertedInfo['bitsPerSample']}',
      );
    } catch (e) {
      print('Failed to read header for $pathToTranscribe: $e');
    }

    final whisper = Whisper(model: WhisperModel.tiny);

    final request = TranscribeRequest(
      audio: pathToTranscribe,
      language: 'en',
      isTranslate: true,
    );

    WhisperTranscribeResponse result;
    try {
      result = await whisper.transcribe(transcribeRequest: request);
    } catch (e, st) {
      throw Exception('Whisper transcribe failed: $e\n$st');
    } finally {
      try {
        if (tempResampled != null && await tempResampled.exists()) {
          await tempResampled.delete();
        }
      } catch (_) {}
    }

    final hasSegments = result.segments != null && result.segments!.isNotEmpty;
    final hasText = (result.text ?? '').trim().isNotEmpty;
    print(
      'Whisper transcription result for $pathToTranscribe: text="${result.text}", segments=${result.segments?.length ?? 0}',
    );
    if (result.segments != null) {
      for (final s in result.segments!) {
        print('  segment: [${s.fromTs} -> ${s.toTs}] "${s.text}"');
      }
    }
    if (!hasSegments && !hasText) {
      throw Exception(
        'Empty transcription result from Whisper for: $pathToTranscribe',
      );
    }

    final transcriptLines = _buildTranscriptLines(result);
    for (final line in transcriptLines) {
      yield [line];
    }
  }

  static List<TranscriptLine> _buildTranscriptLines(
    WhisperTranscribeResponse response,
  ) {
    final segments = response.segments;
    if (segments != null && segments.isNotEmpty) {
      return segments
          .map(
            (segment) =>
                TranscriptLine(speaker: 'Speaker 1', text: segment.text.trim()),
          )
          .where((line) => line.text.isNotEmpty)
          .toList();
    }

    final text = response.text?.trim() ?? '';
    return text.isNotEmpty
        ? [TranscriptLine(speaker: 'Speaker 1', text: text)]
        : [];
  }
}

/// Read minimal WAV header info needed for validation.
Future<Map<String, int>> _readWavHeader(File file) async {
  final bytes = await file.readAsBytes();
  if (bytes.length < 44) throw Exception('WAV file too short');

  String riff = String.fromCharCodes(bytes.sublist(0, 4));
  String wave = String.fromCharCodes(bytes.sublist(8, 12));
  if (riff != 'RIFF' || wave != 'WAVE') throw Exception('Not a RIFF/WAVE file');

  int offset = 12;
  int audioFormat = 1;
  int numChannels = 1;
  int sampleRate = 16000;
  int bitsPerSample = 16;

  while (offset + 8 <= bytes.length) {
    final chunkId = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final chunkSize = _readUint32(bytes, offset + 4);
    if (chunkId == 'fmt ') {
      // parse fmt chunk
      audioFormat = bytes[offset + 8] | (bytes[offset + 9] << 8);
      numChannels = bytes[offset + 10] | (bytes[offset + 11] << 8);
      sampleRate = _readUint32(bytes, offset + 12);
      bitsPerSample = bytes[offset + 22] | (bytes[offset + 23] << 8);

      // Support WAVE_FORMAT_EXTENSIBLE, where the actual format is in the subformat GUID.
      if (audioFormat == 0xFFFE && chunkSize >= 40) {
        final subFormat = bytes[offset + 32] | (bytes[offset + 33] << 8);
        if (subFormat == 1 || subFormat == 3) {
          audioFormat = subFormat;
        }
      }
    }
    offset += 8 + chunkSize;
    if (chunkSize.isOdd) {
      offset += 1;
    }
  }

  return {
    'audioFormat': audioFormat,
    'numChannels': numChannels,
    'sampleRate': sampleRate,
    'bitsPerSample': bitsPerSample,
  };
}

int _readUint32(List<int> data, int offset) {
  return data[offset] |
      (data[offset + 1] << 8) |
      (data[offset + 2] << 16) |
      (data[offset + 3] << 24);
}

/// Extract raw PCM bytes from WAV data chunk.
Future<List<int>> _extractWavData(File file) async {
  final bytes = await file.readAsBytes();
  int dataOffset = 12;
  while (dataOffset + 8 <= bytes.length) {
    final chunkId = String.fromCharCodes(
      bytes.sublist(dataOffset, dataOffset + 4),
    );
    final chunkSize = _readUint32(bytes, dataOffset + 4);
    if (chunkId == 'data') {
      final dataStart = dataOffset + 8;
      return bytes.sublist(dataStart, dataStart + chunkSize);
    }
    dataOffset += 8 + chunkSize;
    if (chunkSize.isOdd) {
      dataOffset += 1;
    }
  }
  throw Exception('WAV data chunk not found');
}

/// Compute RMS of 16-bit PCM little-endian samples.
int _computeRms16(List<int> data) {
  if (data.length < 2) return 0;
  int count = 0;
  double sumSq = 0.0;
  for (int i = 0; i + 1 < data.length; i += 2) {
    int sample = data[i] | (data[i + 1] << 8);
    if (sample & 0x8000 != 0) sample = sample - 0x10000;
    sumSq += (sample * sample).toDouble();
    count++;
  }
  if (count == 0) return 0;
  final meanSq = sumSq / count;
  final rms = Math.sqrt(meanSq);
  return rms.toInt();
}

/// Resample input WAV to 16kHz 16-bit mono PCM using pure Dart. Returns a new File.
Future<File> _resampleTo16k(File input) async {
  final info = await _readWavHeader(input);
  final audioFormat = info['audioFormat']!;
  final bitsPerSample = info['bitsPerSample']!;
  if (audioFormat != 1 && audioFormat != 3) {
    throw Exception(
      'Unsupported WAV format for resampling: format=$audioFormat bits=$bitsPerSample',
    );
  }

  final sourceSampleRate = info['sampleRate']!;
  final sourceChannels = info['numChannels']!;
  final sourceData = await _extractWavData(input);

  final sourceSamples = _decodeWavSamples(
    sourceData,
    audioFormat,
    bitsPerSample,
  );
  if (sourceSamples.isEmpty) {
    throw Exception('No audio samples found for resampling');
  }

  final monoSamples = <double>[];
  if (sourceChannels == 1) {
    monoSamples.addAll(sourceSamples);
  } else {
    for (
      var i = 0;
      i + sourceChannels - 1 < sourceSamples.length;
      i += sourceChannels
    ) {
      var sum = 0.0;
      for (var ch = 0; ch < sourceChannels; ch++) {
        sum += sourceSamples[i + ch];
      }
      monoSamples.add(sum / sourceChannels);
    }
  }

  final targetRate = 16000;
  final outputCount = ((monoSamples.length * targetRate) / sourceSampleRate)
      .round();
  final outputSamples = <int>[];

  for (var i = 0; i < outputCount; i++) {
    final position = i * sourceSampleRate / targetRate;
    final index = position.floor();
    final nextIndex = Math.min(index + 1, monoSamples.length - 1);
    final fraction = position - index;
    final sample =
        ((1 - fraction) * monoSamples[index] +
                fraction * monoSamples[nextIndex])
            .clamp(-1.0, 1.0);
    outputSamples.add((sample * 32767).round());
  }

  final dir = input.parent;
  final name = input.uri.pathSegments.last;
  final outName = name.replaceAll('.wav', '') + '_16k.wav';
  final outPath = '${dir.path}/$outName';
  final outFile = File(outPath);

  final header = _buildWavHeader(
    sampleCount: outputSamples.length,
    numChannels: 1,
    sampleRate: targetRate,
    bitsPerSample: 16,
  );

  final bytes = BytesBuilder();
  bytes.add(header);
  for (final sample in outputSamples) {
    final clipped = sample.clamp(-32768, 32767);
    bytes.add([clipped & 0xFF, (clipped >> 8) & 0xFF]);
  }

  await outFile.writeAsBytes(bytes.toBytes(), flush: true);
  return outFile;
}

List<double> _decodeWavSamples(
  List<int> data,
  int audioFormat,
  int bitsPerSample,
) {
  final bytes = Uint8List.fromList(data);
  final samples = <double>[];

  if (audioFormat == 1) {
    if (bitsPerSample == 8) {
      for (final value in bytes) {
        samples.add((value - 128) / 128.0);
      }
    } else if (bitsPerSample == 16) {
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i + 1 < bytes.length; i += 2) {
        final sample = view.getInt16(i, Endian.little);
        samples.add(sample / 32768.0);
      }
    } else if (bitsPerSample == 24) {
      for (var i = 0; i + 2 < bytes.length; i += 3) {
        var value = bytes[i] | (bytes[i + 1] << 8) | (bytes[i + 2] << 16);
        if (value & 0x800000 != 0) value |= 0xFF000000;
        samples.add((value.toSigned(32) / 8388608.0).clamp(-1.0, 1.0));
      }
    } else if (bitsPerSample == 32) {
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i + 3 < bytes.length; i += 4) {
        final sample = view.getInt32(i, Endian.little);
        samples.add((sample / 2147483648.0).clamp(-1.0, 1.0));
      }
    }
  } else if (audioFormat == 3) {
    if (bitsPerSample == 32) {
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i + 3 < bytes.length; i += 4) {
        samples.add(view.getFloat32(i, Endian.little).clamp(-1.0, 1.0));
      }
    } else if (bitsPerSample == 64) {
      final view = ByteData.sublistView(bytes);
      for (var i = 0; i + 7 < bytes.length; i += 8) {
        samples.add(view.getFloat64(i, Endian.little).clamp(-1.0, 1.0));
      }
    }
  }

  return samples;
}

List<int> _buildWavHeader({
  required int sampleCount,
  required int numChannels,
  required int sampleRate,
  required int bitsPerSample,
}) {
  final byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
  final blockAlign = numChannels * bitsPerSample ~/ 8;
  final dataSize = sampleCount * numChannels * bitsPerSample ~/ 8;
  final chunkSize = 36 + dataSize;

  final builder = BytesBuilder();
  builder.add('RIFF'.codeUnits);
  builder.add(_toLittleEndian(chunkSize, 4));
  builder.add('WAVE'.codeUnits);
  builder.add('fmt '.codeUnits);
  builder.add(_toLittleEndian(16, 4));
  builder.add(_toLittleEndian(1, 2));
  builder.add(_toLittleEndian(numChannels, 2));
  builder.add(_toLittleEndian(sampleRate, 4));
  builder.add(_toLittleEndian(byteRate, 4));
  builder.add(_toLittleEndian(blockAlign, 2));
  builder.add(_toLittleEndian(bitsPerSample, 2));
  builder.add('data'.codeUnits);
  builder.add(_toLittleEndian(dataSize, 4));
  return builder.toBytes();
}

List<int> _toLittleEndian(int value, int byteCount) {
  final bytes = List<int>.filled(byteCount, 0);
  for (var i = 0; i < byteCount; i++) {
    bytes[i] = (value >> (8 * i)) & 0xFF;
  }
  return bytes;
}
