import 'package:flutter/widgets.dart';

import 'local_images_web.dart' if (dart.library.io) 'local_images_io.dart' as impl;

/// 生成图片的设备端缓存：同一单词只生成/下载一次，之后直接读本地文件。
class WordImageStore {
  const WordImageStore._();

  static String keyForWord(int wordId) => 'word_$wordId';

  static String keyForText(String text) {
    final safe =
        text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'text_${safe.isEmpty ? 'word' : safe}';
  }

  static Future<String?> localPath(String key) => impl.localPath(key);

  static Future<String?> saveFromUrl(String key, String url) =>
      impl.saveFromUrl(key, url);
}

/// 既能显示 http 图片，也能显示本地缓存文件。
class CachedImage extends StatelessWidget {
  const CachedImage({
    super.key,
    required this.source,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
  });

  final String source;
  final BoxFit fit;
  final ImageLoadingBuilder? loadingBuilder;
  final ImageErrorWidgetBuilder? errorBuilder;

  @override
  Widget build(BuildContext context) => impl.buildImage(
        source,
        fit: fit,
        loadingBuilder: loadingBuilder,
        errorBuilder: errorBuilder,
      );
}
