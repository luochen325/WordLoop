import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../models/ai_word_card.dart';
import '../models/context_story.dart';
import '../models/graph_data.dart';

class ApiException implements Exception {
  ApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ApiClient {
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? defaultBaseUrl;

  static String get defaultBaseUrl =>
      kIsWeb ? 'http://127.0.0.1:8000' : 'http://10.0.2.2:8000';

  String baseUrl;
  final http.Client _client = http.Client();

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Map<String, String> get _headers => {'Content-Type': 'application/json'};

  Future<Map<String, dynamic>> _decode(http.Response resp) async {
    final text = utf8.decode(resp.bodyBytes);
    if (resp.statusCode >= 400) {
      String detail = text;
      try {
        final data = jsonDecode(text);
        if (data is Map && data['detail'] != null) {
          detail = data['detail'].toString();
        }
      } catch (_) {}
      throw ApiException('请求失败 (${resp.statusCode}): $detail');
    }
    if (text.isEmpty) return {};
    final data = jsonDecode(text);
    return data is Map<String, dynamic> ? data : {'data': data};
  }

  Future<Map<String, dynamic>> health() async {
    final resp = await _client
        .get(_uri('/api/health'))
        .timeout(const Duration(seconds: 8));
    return _decode(resp);
  }

  Future<AiWordCard?> fetchCard(int wordId) async {
    final resp = await _client
        .get(_uri('/api/ai/words/$wordId/card'))
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode == 404) return null;
    return AiWordCard.fromJson(await _decode(resp));
  }

  Future<AiWordCard> generateCard(int wordId, {bool force = false}) async {
    final resp = await _client
        .post(_uri('/api/ai/words/$wordId/card?force=$force'), headers: _headers)
        .timeout(const Duration(seconds: 120));
    return AiWordCard.fromJson(await _decode(resp));
  }

  Future<String?> generateImage(int wordId, {bool force = false}) async {
    final resp = await _client
        .post(_uri('/api/ai/words/$wordId/image?force=$force'), headers: _headers)
        .timeout(const Duration(seconds: 180));
    final data = await _decode(resp);
    final url = data['url'] as String?;
    if (url == null) return null;
    return _resolveImageUrl(url, bustCache: force);
  }

  /// 非词库词/短语：按文本生成并缓存配图
  Future<String?> generateImageByText(String word, {bool force = false}) async {
    final resp = await _client
        .post(
          _uri('/api/ai/image-by-text?force=$force'),
          headers: _headers,
          body: jsonEncode({'word': word}),
        )
        .timeout(const Duration(seconds: 180));
    final data = await _decode(resp);
    final url = data['url'] as String?;
    if (url == null) return null;
    return _resolveImageUrl(url, bustCache: force);
  }

  /// 拼接完整图片地址；重新生成时追加时间戳，绕过 Flutter 的图片缓存，
  /// 否则「换一张」拿到的仍是同一 URL 的旧图。
  String _resolveImageUrl(String url, {bool bustCache = false}) {
    final full = url.startsWith('http') ? url : '$baseUrl$url';
    if (!bustCache) return full;
    final sep = full.contains('?') ? '&' : '?';
    return '$full${sep}v=${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<AiWordCard> lookupWord(String word) async {
    final resp = await _client
        .post(
          _uri('/api/ai/lookup'),
          headers: _headers,
          body: jsonEncode({'word': word}),
        )
        .timeout(const Duration(seconds: 120));
    return AiWordCard.fromJson(await _decode(resp));
  }

  Future<GraphData> fetchGraph(String word, {bool force = false}) async {
    final resp = await _client
        .post(
          _uri('/api/graph'),
          headers: _headers,
          body: jsonEncode({'word': word, 'force': force}),
        )
        .timeout(const Duration(seconds: 90));
    return GraphData.fromJson(await _decode(resp));
  }

  /// 用一组目标词生成语境短文或对话。
  Future<ContextStory> generateContext({
    required List<String> words,
    required String mode,
    bool force = false,
  }) async {
    final resp = await _client
        .post(
          _uri('/api/ai/context'),
          headers: _headers,
          body: jsonEncode({
            'words': words,
            'mode': mode,
            'force': force,
          }),
        )
        .timeout(const Duration(seconds: 120));
    return ContextStory.fromJson(await _decode(resp));
  }

  Future<Map<String, dynamic>> plan({
    required double h,
    required double d,
    required double daysSince,
    bool? recalled,
    double? lastInterval,
  }) async {
    final resp = await _client
        .post(
          _uri('/api/review/plan'),
          headers: _headers,
          body: jsonEncode({
            'h': h,
            'd': d,
            'days_since_review': daysSince,
            'recalled': recalled,
            'last_interval': lastInterval,
          }),
        )
        .timeout(const Duration(seconds: 15));
    return _decode(resp);
  }
}
