import 'package:flutter/foundation.dart';

/// A single lyric line with an optional concise translation.
@immutable
class LyricLine {
  const LyricLine({required this.text, this.translation});

  /// Primary lyric line text (JSON key: `t`).
  final String text;

  /// Optional concise translation displayed below [text] (JSON key: `tr`).
  final String? translation;

  bool get hasTranslation =>
      translation != null && translation!.trim().isNotEmpty;

  LyricLine copyWith({
    String? text,
    String? translation,
    bool clearTranslation = false,
  }) {
    return LyricLine(
      text: text ?? this.text,
      translation: clearTranslation ? null : (translation ?? this.translation),
    );
  }

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    final rawText = json['t'];
    if (rawText is! String) {
      throw const FormatException('LyricLine requires string field "t".');
    }
    final rawTr = json['tr'];
    final tr = rawTr is String && rawTr.trim().isNotEmpty ? rawTr.trim() : null;
    return LyricLine(text: rawText, translation: tr);
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{'t': text};
    if (hasTranslation) {
      map['tr'] = translation!.trim();
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LyricLine &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          translation == other.translation;

  @override
  int get hashCode => Object.hash(text, translation);

  @override
  String toString() => 'LyricLine(text: $text, translation: $translation)';
}
