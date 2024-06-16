import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:injectable/injectable.dart';
import 'package:revanced_manager/app/app.locator.dart';
import 'package:revanced_manager/services/manager_api.dart';
import 'package:revanced_manager/services/toast.dart';

@lazySingleton
class DownloadManager {
  final ManagerAPI _managerAPI = locator<ManagerAPI>();
  late final String _userAgent;

  final _cacheOptions = CacheOptions(
    store: MemCacheStore(),
    maxStale: const Duration(days: 1),
    priority: CachePriority.high,
  );

  Future<void> initialize() async {
    _userAgent = 'ReVanced-Manager/${await _managerAPI.getCurrentManagerVersion()}';
  }

  Dio initDio(String url) {
    var dio = Dio();
    try {
      dio = Dio(
        BaseOptions(
          baseUrl: url,
          headers: {
            'User-Agent': _userAgent,
          },
        ),
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }

    dio.interceptors.add(DioCacheInterceptor(options: _cacheOptions));
    dio.interceptors.add(_ShowToastInterceptor());
    return dio;
  }

  Future<void> clearAllCache() async {
    try {
      await _cacheOptions.store!.clean();
    } on Exception catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
  }

  Future<File> getSingleFile(String url) async {
    return DefaultCacheManager().getSingleFile(
      url,
      headers: {
        'User-Agent': _userAgent,
      },
    );
  }

  Stream<FileResponse> getFileStream(String url) {
    return DefaultCacheManager().getFileStream(
      url,
      withProgress: true,
      headers: {
        'User-Agent': _userAgent,
      },
    );
  }
}

class _ShowToastInterceptor extends Interceptor {
  final Toast _toast = locator<Toast>();

  @override
  void onError(DioException e, ErrorInterceptorHandler handler) {
    final response = e.response;
    if (response != null) {
      // Check if the error is rate limit
      if (response.headers['x-ratelimit-remaining']?[0] == '0') {
        final resetUnixTime =
            int.parse(response.headers['x-ratelimit-reset']?[0] ?? '0');
        final resetDateTime =
            DateTime.fromMillisecondsSinceEpoch(resetUnixTime * 1000);
        final remainingMinutes =
            resetDateTime.difference(DateTime.now()).inMinutes;
        // Toast length should be LENGTH_SHORT because this toast shows 6-8 times in a row.
        _toast.showShort(
            'GitHub API rate limit exceeded. Change the network or wait $remainingMinutes minutes.');
      } else {
        _toast.showBottom(
            '${response.statusCode} ${response.statusMessage}: ${e.requestOptions.uri}');
      }
    } else {
      // The "DioException" text is unnecessary for users, so remove it to save characters
      _toast.showBottom(e.requestOptions.uri.host +
          e.toString().replaceFirst('DioException', ''));
    }
    super.onError(e, handler);
  }
}