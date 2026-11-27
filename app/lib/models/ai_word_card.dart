class Meaning {
  const Meaning({required this.pos, required this.zh, required this.en});

  final String pos;
  final String zh;
  final String en;

  factory Meaning.fromJson(Map<String, dynamic> json) => Meaning(
        pos: (json['pos'] as String?) ?? '',
        zh: (json['zh'] as String?) ?? '',
        en: (json['en'] as String?) ?? '',
      );
}

class Example {
  const Example({required this.en, required this.zh});

  final String en;
  final String zh;

  factory Example.fromJson(Map<String, dynamic> json) => Example(
        en: (json['en'] as String?) ?? '',
        zh: (json['zh'] as String?) ?? '',
      );
}

class Collocation {
  const Collocation({required this.phrase, required this.zh});

  final String phrase;
  final String zh;

  factory Collocation.fromJson(Map<String, dynamic> json) => Collocation(
        phrase: (json['phrase'] as String?) ?? '',
        zh: (json['zh'] as String?) ?? '',
      );
}

class WordFamily {
  const WordFamily({required this.word, required this.pos, required this.zh});

  final String word;
  final String pos;
  final String zh;

  factory WordFamily.fromJson(Map<String, dynamic> json) => WordFamily(
        word: (json['word'] as String?) ?? '',
        pos: (json['pos'] as String?) ?? '',
        zh: (json['zh'] as String?) ?? '',
      );
}

class AiWordCard {
  const AiWordCard({
    required this.word,
    required this.phoneticUs,
    required this.phoneticUk,
    required this.partOfSpeech,
    required this.meanings,
    required this.examples,
    required this.collocations,
    required this.wordFamily,
    required this.synonyms,
    required this.antonyms,
    required this.etymology,
    required this.memoryTip,
    required this.scenario,
    required this.imagePrompt,
  });

  final String word;
  final String phoneticUs;
  final String phoneticUk;
  final List<String> partOfSpeech;
  final List<Meaning> meanings;
  final List<Example> examples;
  final List<Collocation> collocations;
  final List<WordFamily> wordFamily;
  final List<String> synonyms;
  final List<String> antonyms;
  final String etymology;
  final String memoryTip;
  final String scenario;
  final String imagePrompt;

  bool get isEmpty => meanings.isEmpty && examples.isEmpty;

  factory AiWordCard.fromJson(Map<String, dynamic> json) {
    List<T> parseList<T>(String key, T Function(Map<String, dynamic>) build) {
      final raw = json[key];
      if (raw is! List) return <T>[];
      return raw
          .whereType<Map>()
          .map((item) => build(Map<String, dynamic>.from(item)))
          .toList();
    }

    List<String> parseStrings(String key) {
      final raw = json[key];
      if (raw is! List) return const [];
      return raw.map((item) => item.toString()).where((s) => s.isNotEmpty).toList();
    }

    return AiWordCard(
      word: (json['word'] as String?) ?? '',
      phoneticUs: (json['phonetic_us'] as String?) ?? '',
      phoneticUk: (json['phonetic_uk'] as String?) ?? '',
      partOfSpeech: parseStrings('part_of_speech'),
      meanings: parseList('meanings', Meaning.fromJson),
      examples: parseList('examples', Example.fromJson),
      collocations: parseList('collocations', Collocation.fromJson),
      wordFamily: parseList('word_family', WordFamily.fromJson),
      synonyms: parseStrings('synonyms'),
      antonyms: parseStrings('antonyms'),
      etymology: (json['etymology'] as String?) ?? '',
      memoryTip: (json['memory_tip'] as String?) ?? '',
      scenario: (json['scenario'] as String?) ?? '',
      imagePrompt: (json['image_prompt'] as String?) ?? '',
    );
  }
}
