import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<File> _fileFor(String key) async {
  final base = await getApplicationSupportDirectory();
  final dir = Directory('${base.path}${Platform.pathSeparator}word_images');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  return File('${dir.path}${Platform.pathSeparator}$key.png');
}

/// 本地已有缓存则返回文件路径。
Future<String?> localPath(String key) async {
  final file = await _fileFor(key);
  if (await file.exists() && await file.length() > 0) return file.path;
  return null;
}

/// 下载远端图片并写入本地缓存，返回文件路径；失败返回 null。
Future<String?> saveFromUrl(String key, String url) async {
  try {
    final resp = await http.get(Uri.parse(url));
    if (resp.statusCode >= 400) return null;
    final file = await _fileFor(key);
    await file.writeAsBytes(resp.bodyBytes, flush: true);
    // 同名文件被覆盖后，清掉 Flutter 已解码的缓存，避免「换一张」仍显示旧图。
    await FileImage(file).evict();
    return file.path;
  } catch (_) {
    return null;
  }
}

Widget buildImage(
  String source, {
  required BoxFit fit,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  final remote = source.startsWith('http://') || source.startsWith('https://');
  if (remote) {
    return Image.network(
      source,
      fit: fit,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
  }
  return Image.file(File(source), fit: fit, errorBuilder: errorBuilder);
}
