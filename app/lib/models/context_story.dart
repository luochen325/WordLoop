class ContextParagraph {
  const ContextParagraph({required this.en, required this.zh});

  final String en;
  final String zh;

  factory ContextParagraph.fromJson(Map<String, dynamic> json) {
    return ContextParagraph(
      en: (json['en'] as String?) ?? '',
      zh: (json['zh'] as String?) ?? '',
    );
  }
}

class ContextStory {
  const ContextStory({
    required this.title,
    required this.mode,
    required this.words,
    required this.paragraphs,
    required this.used,
  });

  final String title;
  final String mode;
  final List<String> words;
  final List<ContextParagraph> paragraphs;
  final List<String> used;

  factory ContextStory.fromJson(Map<String, dynamic> json) {
    final paragraphs = (json['paragraphs'] as List? ?? [])
        .whereType<Map>()
        .map((item) => ContextParagraph.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.en.isNotEmpty)
        .toList();
    return ContextStory(
      title: (json['title'] as String?) ?? '语境阅读',
      mode: (json['mode'] as String?) ?? 'story',
      words: (json['words'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
      paragraphs: paragraphs,
      used: (json['used'] as List? ?? [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
