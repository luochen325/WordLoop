class Word {
  const Word({
    required this.id,
    required this.word,
    required this.rank,
    required this.sfi,
    required this.freq,
    required this.definitionEn,
    required this.h0,
    required this.d0,
  });

  final int id;
  final String word;
  final int rank;
  final double sfi;
  final int freq;
  final String definitionEn;
  final double h0;
  final double d0;

  /// 不在 NGSL 词库、由知识网络或 AI 查询生成的本地自定义词
  bool get isCustom => rank < 0;

  /// 短语/搭配：只查看，不进入记忆复习
  bool get isPhrase => isCustom && word.trim().contains(' ');

  Map<String, dynamic> toJson() => {
        'id': id,
        'word': word,
        'rank': rank,
        'sfi': sfi,
        'freq': freq,
        'definition_en': definitionEn,
        'h0': h0,
        'd0': d0,
      };

  factory Word.fromJson(Map<String, dynamic> json) {
    return Word(
      id: (json['id'] as num).toInt(),
      word: json['word'] as String,
      rank: (json['rank'] as num).toInt(),
      sfi: (json['sfi'] as num?)?.toDouble() ?? 0,
      freq: (json['freq'] as num?)?.toInt() ?? 0,
      definitionEn: (json['definition_en'] as String?) ?? '',
      h0: (json['h0'] as num).toDouble(),
      d0: (json['d0'] as num).toDouble(),
    );
  }
}
