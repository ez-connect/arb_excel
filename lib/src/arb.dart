import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';

/// To match all args from a text.
final _kRegArgs = RegExp(r'{(\w+)}');

String baseFilename(String path) {
  var p = withoutExtension(path);
  var idx = p.lastIndexOf("_");
  if (idx < 0) {
    return p;
  }
  return p.substring(0, idx);
}

String? determineLocale(String path) {
  var idx = path.lastIndexOf(".");
  path = path.substring(0, idx);
  idx = path.lastIndexOf("_");
  if (idx < 0) {
    return null;
  }
  var result = path.substring(idx + 1);
  if (result.toLowerCase() != result) {
    idx = path.lastIndexOf("_", idx - 1);
  }
  return path.substring(idx + 1);
}

void readArbItems(File f, Map<String, ARBItem> items, String locale,
    {ARBFilter? filter, String? reviewMarkerProperty}) {
  final s = f.readAsStringSync();
  final m = jsonDecode(s);
  var filename = withoutExtension(basename(f.path));
  if (m is Map<String, dynamic>) {
    for (final e in m.entries) {
      if (e.key.startsWith('@')) {
        continue;
      }
      final meta = m['@${e.key}'];
      if (filter != null &&
          meta is Map<String, dynamic>? &&
          !filter.accept(meta)) {
        continue;
      }
      final item = items.putIfAbsent(
          e.key,
          () =>
              ARBItem(messageKey: e.key, filename: filename, translations: {}));
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
        final placeholders = meta['placeholders'];
        if (placeholders is Map) {
          for (final placeholder in placeholders.entries) {
            var value = placeholder.value;
            if (value is Map) {
              var d = value["description"];
              if (d is String) {
                item.placeHolderDescriptions[placeholder.key.toString()] = d;
              }
            }
          }
        }
        var reviewed = meta[reviewMarkerProperty];
        if (reviewed is bool) {
          item.reviewedMarker[locale] = reviewed;
        }
      }
    }
  }
}

///
/// Parses .arb files to [Translation].
/// The [filename] is the main language arb file or the name of the directory.
///
(Translation translation, List<String> files) parseARB(List<String> filenames,
    {List<String>? targetLocales,
    String? leadLocale,
    ARBFilter? filter,
    String? reviewMarkerProperty}) {
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
      if (locale == leadLocale ||
          (leadLocale == null && locales.isEmpty) ||
          (targetLocales == null || targetLocales.contains(locale))) {
        files.add(f.path);
        locales.add(locale);
        readArbItems(f, arbItems, locale,
            filter: filter, reviewMarkerProperty: reviewMarkerProperty);
      }
    }
  }
  final t = Translation(languages: locales, items: arbItems.values.toList());
  return (t, files);
}

///
/// Read the existing translations from the ARB files defined by [filenames]
/// and merge the data from an excel input into the ARB files.
///
Translation mergeARB(List<String> filenames, Translation excelInputData,
    {ARBFilter? filter}) {
  Translation arbFileItems =
      parseARB(filenames, reviewMarkerProperty: filter?.property).$1;
  arbFileItems.quoteMessages();
  var existingArbItems = arbFileItems.itemsAsMap;
  for (final item in excelInputData.items) {
    var merged = existingArbItems[item.messageKey];
    if (merged == null) {
      arbFileItems.items.add(item);
    } else {
      merged.importTranslations(item.translations);
    }
  }
  return arbFileItems;
}

/// Writes [Translation] to .arb files.
void writeARB(String inputFilename, List<String> filenames, Translation data,
    {required bool includeLeadLocale,
    bool merge = false,
    String? leadLocale,
    ARBFilter? filter}) {
  var basename = withoutExtension(filenames.first);
  if (merge) {
    data = mergeARB(filenames, data, filter: filter);
  }
  var fn = data.items.first.filename;
  if (fn != null &&
      filenames.length == 1 &&
      FileSystemEntity.isDirectorySync(filenames.first)) {
    basename = join(filenames.first, withoutExtension(fn));
  }
  basename = baseFilename(basename);
  for (var i = 0; i < data.languages.length; i++) {
    final lang = data.languages[i];
    final isDefault = includeLeadLocale &&
        ((leadLocale != null && lang == leadLocale) ||
            (leadLocale == null && i == 0));
    final f = File('${basename}_$lang.arb');
    var buf = <String?>[];
    buf.add('  "@@locale": "$lang"');
    for (final item in data.items) {
      final data = item.toJSON(lang,
          isDefault: isDefault, reviewedProperty: filter?.property);
      if (data != null) {
        buf.add(data);
      }
    }
    final nl = Platform.lineTerminator;
    buf = ['{', buf.join(',$nl'), '}$nl'];
    if (merge) {
      stdout.writeln(
          'Merging ARB file ${f.path} with input from: $inputFilename');
    } else {
      stdout.writeln('Generating ARB file ${f.path} from: $inputFilename');
    }
    f.writeAsStringSync(buf.join(nl));
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
      throw Exception(
          "Wrong ARB filter definition. Use syntax: propertyname:value");
    }
    property = filterDefinition.substring(0, idx);
    var f = filterDefinition.substring(idx + 1);
    value = bool.tryParse(f) ?? f;
  }

  bool accept(Map<String, dynamic>? meta) => meta?[property] == value;
}

///
/// Describes an ARB record holding the translations and meta information for one message key.
///
class ARBItem {
  ARBItem({
    this.context,
    this.filename,
    required this.messageKey,
    this.description,
    this.translations = const {},
  });

  Map<String, String> getPlaceholders(String text) {
    final matches = _kRegArgs.allMatches(text);
    for (final m in matches) {
      final arg = m.group(1);
      if (arg != null && placeHolderDescriptions[arg] == null) {
        placeHolderDescriptions[arg] = "@@ TODO $arg";
      }
    }
    return placeHolderDescriptions;
  }

  ///
  /// The message key used in the translation process to refer to the message.
  ///
  final String messageKey;

  ///
  /// The base file name of the file, where this message is defined (e.g. test.arb rather than test_de.arb).
  ///
  final String? filename;

  ///
  /// An optional context
  String? context;
  String? description;

  ///
  /// Whether the entry for a locale was marked for review.
  ///
  final Map<String, bool> reviewedMarker = {};
  final Map<String, String> translations;
  final Map<String, String> placeHolderDescriptions = {};

  /// Serialize in JSON.
  String? toJSON(String lang,
      {bool isDefault = false, String? reviewedProperty = "x-reviewed"}) {
    final value = translations[lang];
    if (value == null || value.isEmpty) {
      return null;
    }

    final placeHolders = getPlaceholders(value);
    final needsReview = reviewedMarker[lang] == false;
    final hasMetadata = needsReview ||
        (isDefault &&
            (placeHolders.isNotEmpty ||
                description != null ||
                context != null));

    final List<String> buf = [];
    final nl = Platform.lineTerminator;

    if (hasMetadata) {
      buf.add('  "$messageKey": "$value",');
      buf.add('  "@$messageKey": {');
      var meta = <String>[];
      if (description != null && isDefault) {
        meta.add('    "description": "$description"');
      }
      if (context != null && isDefault) {
        meta.add('    "context": "$context"');
      }
      if (needsReview) {
        meta.add('    "$reviewedProperty": false');
      }
      if (placeHolders.isNotEmpty && isDefault) {
        final sb = StringBuffer();
        sb.writeln('    "placeholders": {');
        final List<String> group = [];
        for (final placeholder in placeHolders.entries) {
          group.add(
              '      "${placeholder.key}": {"description": "${placeholder.value}"}');
        }
        sb.writeln(group.join(',$nl'));
        sb.write('    }');
        meta.add(sb.toString());
      }
      buf.add(meta.join(',$nl'));
      buf.add('  }');
    } else {
      buf.add('  "$messageKey": "$value"');
    }

    return buf.join(nl);
  }

  ///
  /// Import the translations from an external source.
  ///
  void importTranslations(Map<String, String> imported) {
    for (final localeEntry in imported.entries) {
      final existing = translations[localeEntry.key];
      if (existing == null || existing != localeEntry.value) {
        reviewedMarker[localeEntry.key] = true;
        translations[localeEntry.key] = localeEntry.value;
      }
    }
  }
}

/// Describes all arb records.
class Translation {
  Translation({this.languages = const [], this.items = const []});

  final List<String> languages;
  final List<ARBItem> items;

  Map<String, ARBItem> get itemsAsMap =>
      {for (final i in items) i.messageKey: i};

  String _quote(String s) => s.replaceAll("\n", "\\n");

  void quoteMessages() {
    for (final a in items) {
      for (final l in languages) {
        var m = a.translations[l];
        if (m != null) {
          a.translations[l] = _quote(m);
        }
      }
    }
  }
}
