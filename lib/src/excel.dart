import 'dart:convert';
import 'dart:io';

import 'package:arb_excel/src/assets.dart';
import 'package:excel/excel.dart';

import 'arb.dart';

const _kRowHeader = 0;
const _kRowValue = 1;
const _kColCategory = 0;
const _kColText = 1;
const _kColDescription = 2;
const _kColValue = 3;

/// Create a new Excel template file.
///
/// Embedded data will be packed via `template.dart`.
void newTemplate(String filename) {
  final buf = base64Decode(kTemplate);
  File(filename).writeAsBytesSync(buf);
}

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
      category: row[_kColCategory]?.value?.toString(),
      text: row[_kColText]?.value?.toString() ?? '',
      description: row[_kColDescription]?.value?.toString(),
      translations: {},
    );

    for (int i = _kColValue; i < sheet.maxColumns; i++) {
      final lang = columns[i]?.value?.toString() ?? i.toString();
      item.translations[lang] = row[i]?.value?.toString() ?? '';
    }

    items.add(item);
  }

  final languages = columns
      .where((e) => e != null && e.columnIndex >= _kColValue)
      .map<String>((e) => e?.value?.toString() ?? '')
      .toList();
  return Translation(languages: languages, items: items);
}

/// Writes a Excel file, includes all translations.
void writeExcel(String filename, Translation data, String leadLocale) {
  var excel = Excel.createExcel();
  var sheets = excel.sheets;
  var defaultSheet = sheets.isNotEmpty ? sheets.keys.first : null;
  for (var targetLocale in data.languages) {
    if (targetLocale == leadLocale) {
      continue;
    }
    var name = '$leadLocale - $targetLocale';
    var sheetObject = excel[name];
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
      defaultSheet = null;
    }
    sheetObject.setColumnWidth(0, 30);
    sheetObject.setColumnWidth(1, 60);
    sheetObject.setColumnWidth(2, 60);
    sheetObject.setColumnWidth(3, 90);
    sheetObject.appendRow([
      TextCellValue('Key'),
      TextCellValue('Text'),
      TextCellValue('Target Language Text'),
      TextCellValue('Description')
    ]);
    var cell = sheetObject.cell(CellIndex.indexByString('A1'));
    cell.cellStyle = CellStyle(bold: true);
    cell = sheetObject.cell(CellIndex.indexByString('B1'));
    cell.cellStyle = CellStyle(bold: true);
    cell = sheetObject.cell(CellIndex.indexByString('C1'));
    cell.cellStyle = CellStyle(bold: true);
    cell = sheetObject.cell(CellIndex.indexByString('D1'));
    cell.cellStyle = CellStyle(bold: true);
    for (var item in data.items) {
      var row = <CellValue>[
        TextCellValue(item.text),
        TextCellValue(item.translations[leadLocale] ?? '?'),
        TextCellValue(item.translations[targetLocale] ?? ''),
        TextCellValue(item.description ?? '')
      ];
      sheetObject.appendRow(row);
    }
  }
  var bytes = excel.save(fileName: filename);
  if (bytes == null) {
    throw Exception("Error generating excel. Cannot encode");
  }
  stdout.writeln('Generating Excel file named $filename');
  File(filename).writeAsBytesSync(bytes);
}
