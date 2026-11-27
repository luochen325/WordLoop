import 'package:flutter/widgets.dart';

/// Web 端没有可写的本地目录，始终回退到网络图片。
Future<String?> localPath(String key) async => null;

Future<String?> saveFromUrl(String key, String url) async => null;

Widget buildImage(
  String source, {
  required BoxFit fit,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) =>
    Image.network(
      source,
      fit: fit,
      loadingBuilder: loadingBuilder,
      errorBuilder: errorBuilder,
    );
