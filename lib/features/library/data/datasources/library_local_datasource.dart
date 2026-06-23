import 'package:hive/hive.dart';
import '../../../../core/error/exceptions.dart';
import '../../domain/entities/recording.dart';
import '../models/recording_model.dart';

abstract class LibraryLocalDataSource {
  Future<List<Recording>> getCachedRecordings();
  Future<void> cacheRecordings(List<Recording> recordings);
  Future<void> deleteCachedRecording(String id);
  Future<void> renameCachedRecording(String id, String newTitle);
  Future<void> saveRecording(Recording recording);
  Future<Recording?> getRecordingById(String id);
}

class LibraryLocalDataSourceImpl implements LibraryLocalDataSource {
  final Box _box;
  LibraryLocalDataSourceImpl({required Box box}) : _box = box;

  @override
  Future<List<Recording>> getCachedRecordings() async {
    try {
      return _box.values
          .map(
            (value) => RecordingModel.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList();
    } catch (error) {
      throw CacheException('Failed to read cached recordings: $error');
    }
  }

  @override
  Future<void> cacheRecordings(List<Recording> recordings) async {
    try {
      await _box.clear();
      final entries = {
        for (final recording in recordings)
          recording.id: RecordingModel.fromEntity(recording).toJson(),
      };
      await _box.putAll(entries);
    } catch (error) {
      throw CacheException('Failed to cache recordings: $error');
    }
  }

  @override
  Future<void> deleteCachedRecording(String id) async {
    try {
      await _box.delete(id);
    } catch (error) {
      throw CacheException('Failed to delete recording: $error');
    }
  }

  @override
  Future<void> renameCachedRecording(String id, String newTitle) async {
    try {
      final existing = _box.get(id);
      if (existing != null) {
        final model = RecordingModel.fromJson(
          Map<String, dynamic>.from(existing as Map),
        );
        final updated = model.copyWith(title: newTitle);
        await _box.put(id, updated.toJson());
      }
    } catch (error) {
      throw CacheException('Failed to rename recording: $error');
    }
  }

  @override
  Future<void> saveRecording(Recording recording) async {
    try {
      await _box.put(
        recording.id,
        RecordingModel.fromEntity(recording).toJson(),
      );
    } catch (error) {
      throw CacheException('Failed to save recording: $error');
    }
  }

  @override
  Future<Recording?> getRecordingById(String id) async {
    try {
      final value = _box.get(id);
      if (value == null) return null;
      return RecordingModel.fromJson(Map<String, dynamic>.from(value as Map));
    } catch (error) {
      throw CacheException('Failed to read recording: $error');
    }
  }
}
