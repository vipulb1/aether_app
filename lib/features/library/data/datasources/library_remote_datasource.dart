import 'package:http/http.dart' as http;
import '../../domain/entities/recording.dart';
import '../../../../core/error/exceptions.dart';

abstract class LibraryRemoteDataSource {
  Future<List<Recording>> getRecordings();
  Future<List<Recording>> searchRecordings(String query);
  Future<void> deleteRecording(String id);
}

class LibraryRemoteDataSourceImpl implements LibraryRemoteDataSource {
  final http.Client client;

  LibraryRemoteDataSourceImpl({required this.client});

  @override
  Future<List<Recording>> getRecordings() async {
    // In production: call REST API
    // final response = await client.get(Uri.parse('$baseUrl/recordings'));
    // For now, throw to trigger offline fallback
    throw const ServerException('Remote not yet available');
  }

  @override
  Future<List<Recording>> searchRecordings(String query) async {
    throw const ServerException('Remote not yet available');
  }

  @override
  Future<void> deleteRecording(String id) async {
    throw const ServerException('Remote not yet available');
  }
}
