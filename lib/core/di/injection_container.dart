import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../network/network_info.dart';
import '../../features/library/data/datasources/library_local_datasource.dart';
import '../../features/library/data/datasources/library_remote_datasource.dart';
import '../../features/library/data/repositories/library_repository_impl.dart';
import '../../features/library/domain/repositories/library_repository.dart';
import '../../features/library/domain/usecases/get_recordings.dart';
import '../../features/library/domain/usecases/search_recordings.dart';
import '../../features/library/domain/usecases/delete_recording.dart';
import '../../features/library/domain/usecases/rename_recording.dart';
import '../../features/library/domain/usecases/save_recording.dart';
import '../../features/library/presentation/bloc/library_bloc.dart';
import '../../features/recording/presentation/bloc/recording_bloc.dart';
import '../../features/translation/data/datasources/translation_remote_datasource.dart';
import '../../features/translation/data/repositories/translation_repository_impl.dart';
import '../../features/translation/domain/repositories/translation_repository.dart';
import '../../features/translation/domain/usecases/translate_text.dart';
import '../../features/translation/presentation/bloc/translation_bloc.dart';

final sl = GetIt.instance;

Future<void> initDependencies() async {
  // ── External ──
  sl.registerLazySingleton<http.Client>(() => http.Client());
  sl.registerLazySingleton<Connectivity>(() => Connectivity());

  // ── Core ──
  sl.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(sl<Connectivity>()),
  );

  // ── Library Feature ──
  final recordingsBox = await Hive.openBox('recordings');
  sl.registerLazySingleton<LibraryLocalDataSource>(
    () => LibraryLocalDataSourceImpl(box: recordingsBox),
  );
  sl.registerLazySingleton<LibraryRemoteDataSource>(
    () => LibraryRemoteDataSourceImpl(client: sl<http.Client>()),
  );
  sl.registerLazySingleton<LibraryRepository>(
    () => LibraryRepositoryImpl(
      localDataSource: sl<LibraryLocalDataSource>(),
      remoteDataSource: sl<LibraryRemoteDataSource>(),
      networkInfo: sl<NetworkInfo>(),
    ),
  );
  sl.registerLazySingleton(() => GetRecordings(sl<LibraryRepository>()));
  sl.registerLazySingleton(() => SearchRecordings(sl<LibraryRepository>()));
  sl.registerLazySingleton(() => DeleteRecording(sl<LibraryRepository>()));
  sl.registerLazySingleton(() => RenameRecording(sl<LibraryRepository>()));
  sl.registerFactory(
    () => LibraryBloc(
      getRecordings: sl<GetRecordings>(),
      searchRecordings: sl<SearchRecordings>(),
      deleteRecording: sl<DeleteRecording>(),
      renameRecording: sl<RenameRecording>(),
      saveRecording: sl<SaveRecording>(),
    ),
  );

  // ── Recording Feature ──
  sl.registerLazySingleton(() => SaveRecording(sl<LibraryRepository>()));
  sl.registerFactory(() => RecordingBloc(saveRecording: sl<SaveRecording>()));

  // ── Translation Feature ──
  sl.registerLazySingleton<TranslationRemoteDataSource>(
    () => TranslationRemoteDataSourceImpl(client: sl<http.Client>()),
  );
  sl.registerLazySingleton<TranslationRepository>(
    () => TranslationRepositoryImpl(
      remoteDataSource: sl<TranslationRemoteDataSource>(),
    ),
  );
  sl.registerLazySingleton(() => TranslateText(sl<TranslationRepository>()));
  sl.registerFactory(() => TranslationBloc(translateText: sl<TranslateText>()));
}
