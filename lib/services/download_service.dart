import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class DownloadService {
  static final Dio _dio = Dio();

  static Future<File> download({
    required String url,
    required String filename,
    void Function(int received, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await getApplicationDocumentsDirectory();
    final downloadDir = Directory('${dir.path}/downloads');
    if (!await downloadDir.exists()) {
      await downloadDir.create(recursive: true);
    }
    final savePath = '${downloadDir.path}/$filename';
    await _dio.download(url, savePath,
        onReceiveProgress: onProgress, cancelToken: cancelToken);
    return File(savePath);
  }
}
