import 'dart:io';

import 'package:path/path.dart';

/// To match all args from a text.
final _kRegArgs = RegExp(r'{(\w+)}');

/// Parses .arb files to [Translation].
/// The [filename] is the main language.
Translation parseARB(String filename) {
  throw UnimplementedError();
}

/// Writes [Translation] to .arb files.
void writeARB(String filename, Translation data) {
  for (final lang in data.languages) {
    final f = File('${withoutExtension(filename)}_$lang.arb');

    final bufItems = [];
    for (final item in data.items) {
      bufItems.add(item.toJSON(lang));
    }

    final buf = ['{', bufItems.join(',\n'), '}'];
    f.writeAsStringSync(buf.join('\n'));
  }
}

/// Describes an ARB record.
class ARBItem {
  static List<String> getArgs(String text) {
    final List<String> args = [];
    final matches = _kRegArgs.allMatches(text);
    for (final m in matches) {
      final arg = m.group(1);
      if (arg != null) {
        args.add(arg);
      }
    }

    return args;
  }

  ARBItem({
    this.category,
    required this.text,
    this.description,
    this.translations = const {},
  });

  final String? category;
  final String text;
  final String? description;
  final Map<String, String> translations;

  /// Serialize in JSON.
  String toJSON(String lang) {
    final value = translations[lang] ?? '';
    final args = getArgs(value);
    final hasMetadata = args.isNotEmpty || description != null;

    final List<String> buf = [];

    if (hasMetadata) {
      buf.add('  "$text": "$value",');
      buf.add('  "@$text": {');
      if (description != null) {
        buf.add('    "description": "$description"');
      }

      if (args.isNotEmpty) {
        buf.add('    "placeholders": {');
        final List<String> argsBuf = [];
        for (final arg in args) {
          argsBuf.add('      "$arg": {"type": "String"}');
        }
        buf.add(argsBuf.join(',\n'));
        buf.add('    }');
      }

      buf.add('  }');
    } else {
      buf.add('  "$text": "$value"');
    }

    return buf.join('\n');
  }
}

/// Describes all arb records.
class Translation {
  Translation({this.languages = const [], this.items = const []});

  final List<String> languages;
  final List<ARBItem> items;
}
