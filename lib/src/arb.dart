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
  var filename = withoutExtension(basename(f.path));
  if (m is Map<String, dynamic>) {
    for (final e in m.entries) {
      if (e.key.startsWith('@')) {
        continue;
      }
      final meta = m['@${e.key}'];
      if (filter != null && meta is Map<String, dynamic>? && !filter.accept(meta)) {
        continue;
      }
      final item = items.putIfAbsent(e.key, () => ARBItem(messageKey: e.key, filename: filename, translations: {}));
      item.translations[locale] = e.value.toString();
      if (meta is Map) {
        final d = meta['description'];
        if (d is String) {
          item.description = d;
        }
        final c = meta['context'];
        if (c is String) {
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
(Translation translation, List<String> files) parseARB(List<String> filenames, {List<String>? targetLocales, String? leadLocale, ARBFilter? filter}) {
  var arbItems = <String, ARBItem>{};
  var locales = <String>[];
  List<String> files = [];
  for (final filename in filenames) {
    var d = Directory(filename);
    if (!d.existsSync()) {
      d = File(filename).parent;
      if (!d.existsSync()) {
        throw Exception("Directory $d cannot be found");
      }
    }
    for (final f in d.listSync()) {
      final p = basename(f.path);
      if (f is! File || !p.endsWith(".arb")) {
        continue;
      }
      final locale = determineLocale(p);
      if (locale == null) {
        continue;
      }
      if (locale == leadLocale || (leadLocale == null && locales.isEmpty) ||
          (targetLocales == null || targetLocales.contains(locale))) {
        files.add(f.path);
        locales.add(locale);
        readArbItems(f, arbItems, locale, filter: filter);
      }
    }
  }
  final t = Translation(languages: locales, items: arbItems.values.toList());
  return (t, files);
}

Translation mergeARB(List<String> filenames, Translation data) {
  Translation existing = parseARB(filenames).$1;
  var m = existing.itemsAsMap;
  for (final item in data.items) {
    var merged = m[item.messageKey];
    if (merged == null) {
      existing.items.add(item);
    } else {
      merged.translations.addAll(item.translations);
    }
  }
  return existing;
}

/// Writes [Translation] to .arb files.
void writeARB(String inputFilename, List<String> filenames, Translation data, {required bool includeLeadLocale, bool merge = false}) {
  if (merge) {
    data = mergeARB(filenames, data);
  }
  var basename = withoutExtension(filenames.first);
  for (var i = 0; i < data.languages.length; i++) {
    final lang = data.languages[i];
    final isDefault = includeLeadLocale && i == 0;
    final f = File('${basename}_$lang.arb');
    var buf = <String?>[];
    for (final item in data.items) {
      final data = item.toJSON(lang, isDefault: isDefault);
      if (data != null) {
        buf.add(item.toJSON(lang, isDefault: isDefault));
      }
    }

    buf = ['{', buf.join(',\n'), '}\n'];
    if (merge) {
      stdout.writeln('Merging ARB file ${f.path} with input from: $inputFilename');
    } else {
      stdout.writeln('Generating ARB file ${f.path} from: $inputFilename');
    }
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
    this.filename,
    required this.messageKey,
    this.description,
    this.translations = const {},
  });

  final String messageKey;
  ///
  /// The base file name of the file, where this message is defined (e.g. test.arb rather than test_de.arb).
  ///
  final String? filename;
  String? context;
  String? description;
  final Map<String, String> translations;

  /// Serialize in JSON.
  String? toJSON(String lang, {bool isDefault = false}) {
    final value = translations[lang];
    if (value == null || value.isEmpty) {
      return null;
    }

    final args = getArgs(value);
    final hasMetadata = isDefault && (args.isNotEmpty || description != null || context != null);

    final List<String> buf = [];

    if (hasMetadata) {
      buf.add('  "$messageKey": "$value",');
      buf.add('  "@$messageKey": {');
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
      buf.add('  "$messageKey": "$value"');
    }

    return buf.join('\n');
  }
}

/// Describes all arb records.
class Translation {
  Translation({this.languages = const [], this.items = const []});

  final List<String> languages;
  final List<ARBItem> items;

  Map<String, ARBItem> get itemsAsMap => {for (final i in items) i.messageKey: i};
}
