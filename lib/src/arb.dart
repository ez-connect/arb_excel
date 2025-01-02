import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

/// To match all args from a text.
final _kRegArgs = RegExp(r'{(\w+)}');

String? determineLocale(String path) {
  var idx = path.lastIndexOf(".");
  path = path.substring(0, idx);
  idx = path.lastIndexOf("_");
  if (idx < 0) {
    return null;
  }
  var result = path.substring(idx+1);
  if (result.toLowerCase() != result) {
    idx = path.lastIndexOf("_", idx-1);
  }
  return path.substring(idx+1);
}

void readArbItems(File f, Map<String, ARBItem> items, String locale, {ARBFilter? filter}) {
  final s = f.readAsStringSync();
  final m = jsonDecode(s);
  if (m is Map) {
    for (final e in m.entries) {
      if (e.key.startsWith('@')) {
        continue;
      }
      final meta = m['@${e.key}'];
      if (filter != null && !filter.accept(meta)) {
        continue;
      }
      final item = items.putIfAbsent(e.key, () => ARBItem(text: e.key, translations: {}));
      item.translations[locale] = e.value.toString();
      if (meta is Map) {
        final d = meta['description'];
        if (d != null) {
          item.description = d;
        }
        final c = meta['context'];
        if (c != null) {
          item.context = c;
        }
      }
    }
  }
}

///
/// Parses .arb files to [Translation].
/// The [filename] is the main language arb file or the name of the directory.
///
(Translation translation, String? file) parseARB(String filename, {List<String>? targetLocales, String? leadLocale, ARBFilter? filter}) {
  var d = Directory(filename);
  var locales = <String>[];
  var arbItems = <String, ARBItem>{};
  if (!d.existsSync()) {
    d = File(filename).parent;
    if (!d.existsSync()) {
      throw Exception("Directory $d cannot be found");
    }
  }
  String? file;
  for (final f in d.listSync()) {
    final p = basename(f.path);
    if (f is! File || !p.endsWith(".arb")) {
      continue;
    }
    final locale = determineLocale(p);
    if (locale == null) {
      continue;
    }
    if (locale == leadLocale || (leadLocale == null && locales.isEmpty) || (targetLocales == null || targetLocales.contains(locale))) {
      file = f.path.substring(0, f.path.length - 4 - 1 - locale.length);
      locales.add(locale);
      readArbItems(f, arbItems, locale, filter: filter);
    }
  }
  final t = Translation(languages: locales, items: arbItems.values.toList());
  return (t, file);
}

Translation mergeARB(String filename, Translation data) {
  Translation existing = parseARB(filename).$1;
  var m = existing.itemsAsMap;
  for (final item in data.items) {
    var merged = m[item.text];
    if (merged == null) {
      existing.items.add(item);
    } else {
      merged.translations.addAll(item.translations);
    }
  }
  return existing;
}

/// Writes [Translation] to .arb files.
void writeARB(String filename, Translation data, {required bool includeLeadLocale, bool merge = false}) {
  if (merge) {
    data = mergeARB(filename, data);
  }
  for (var i = 0; i < data.languages.length; i++) {
    final lang = data.languages[i];
    final isDefault = includeLeadLocale && i == 0;
    final f = File('${withoutExtension(filename)}_$lang.arb');
    var buf = <String?>[];
    for (final item in data.items) {
      final data = item.toJSON(lang, isDefault);
      if (data != null) {
        buf.add(item.toJSON(lang, isDefault));
      }
    }

    buf = ['{', buf.join(',\n'), '}\n'];
    f.writeAsStringSync(buf.join('\n'));
  }
}

///
/// Describes a filter allowing to filter ARB items to be exported to Excel.
///
class ARBFilter {
  late final String property;
  late final Object? value;

  ARBFilter.parse(String filterDefinition) {
    var idx = filterDefinition.indexOf(":");
    if (idx < 0) {
      throw Exception("Wrong ARB filter definition. Use syntax: propertyname:value");
    }
    property = filterDefinition.substring(0, idx);
    var f = filterDefinition.substring(idx+1);
    value = bool.tryParse(f) ?? f;
  }

  bool accept(Map<String, dynamic>? meta) => meta?[property] == value;
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
    this.context,
    required this.text,
    this.description,
    this.translations = const {},
  });

  final String text;
  String? context;
  String? description;
  final Map<String, String> translations;

  /// Serialize in JSON.
  String? toJSON(String lang, [bool isDefault = false]) {
    final value = translations[lang];
    if (value == null || value.isEmpty) {
      return null;
    }

    final args = getArgs(value);
    final hasMetadata = isDefault && (args.isNotEmpty || description != null || context != null);

    final List<String> buf = [];

    if (hasMetadata) {
      buf.add('  "$text": "$value",');
      buf.add('  "@$text": {');
      var meta = <String>[];
      if (description != null) {
        meta.add('    "description": "$description"');
      }
      if (context != null) {
        meta.add('    "context": "$context"');
      }
      if (args.isNotEmpty) {
        final sb = StringBuffer();
        sb.writeln('    "placeholders": {');
        final List<String> group = [];
        for (final arg in args) {
          group.add('      "$arg": {"type": "String"}');
        }
        sb.writeln(group.join(',\n'));
        sb.write('    }');
        meta.add(sb.toString());
      }
      buf.add(meta.join(',\n'));
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

  Map<String, ARBItem> get itemsAsMap => {for (final i in items) i.text: i};
}
