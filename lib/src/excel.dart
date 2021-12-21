import 'dart:io';

import 'package:excel/excel.dart';

import 'arb.dart';

const _kRowHeader = 0;
const _kRowValue = 1;
const _kColCategory = 0;
const _kColText = 1;
const _kColDescription = 2;
const _kColValue = 3;

/// Reads Excel sheet.
///
/// Uses `arb_sheet -n path/to/file` to create a translation file
/// from the template.
Translation parseExcel({
  required String filename,
  String sheetname = 'Text',
  int headerRow = _kRowHeader,
  int valueRow = _kRowValue,
}) {
  final buf = File(filename).readAsBytesSync();
  final excel = Excel.decodeBytes(buf);
  final sheet = excel.sheets[sheetname];
  if (sheet == null) {
    return Translation();
  }

  final List<ARBItem> items = [];
  final columns = sheet.rows[headerRow];
  for (int i = valueRow; i < sheet.rows.length; i++) {
    final row = sheet.rows[i];
    final item = ARBItem(
      category: row[_kColCategory]?.value,
      text: row[_kColText]?.value,
      description: row[_kColDescription]?.value,
      translations: {},
    );

    for (int i = _kColValue; i < sheet.maxCols; i++) {
      final lang = columns[i]?.value ?? i.toString();
      item.translations[lang] = row[i]?.value ?? '';
    }

    items.add(item);
  }

  final languages = columns
      .where((e) => e != null && e.colIndex >= _kColValue)
      .map<String>((e) => e?.value)
      .toList();
  return Translation(languages: languages, items: items);
}

/// Writes a Excel file, includes all translations.
void writeExcel(String filename, Translation data) {
  throw UnimplementedError();
}
