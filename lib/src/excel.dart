import 'dart:convert';
import 'dart:io';

import 'package:arb_excel/src/assets.dart';
import 'package:excel/excel.dart';

import 'arb.dart';

const _kRowHeader = 0;
const _kRowValue = 1;
const _kColText = 0;
const _kColValue = 1;
const _kColTargetLangValue = 2;
const _kColDescription = 3;
const _kColContext = 4;

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
  bool includeLeadLocale = false,
  int headerRow = _kRowHeader,
  int valueRow = _kRowValue,
}) {
  final buf = File(filename).readAsBytesSync();
  final excel = Excel.decodeBytes(buf);
  final languages = <String>[];
  final items = <String,ARBItem>{};
  bool firstLocale = true;
  for (final sheet in excel.sheets.values) {
    final idx = sheet.sheetName.lastIndexOf(" - ");
    if (idx < 0) {
      continue;
    }
    if (firstLocale && includeLeadLocale) {
      final leadLocale = sheet.sheetName.substring(0, idx);
      languages.add(leadLocale);
      for (int i = valueRow; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        var text = row[_kColText]?.value?.toString() ?? '';

        final item = items.putIfAbsent(text, () => ARBItem(
          text: text,
          description: row[_kColDescription]?.value?.toString(),
          translations: {},
        ));
        item.translations[leadLocale] = row[_kColValue]?.value?.toString() ?? '';
      }
      firstLocale = false;
    }
    final locale = sheet.sheetName.substring(idx+3);
    languages.add(locale);
    for (int i = valueRow; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      var text = row[_kColText]?.value?.toString() ?? '';

      final item = items.putIfAbsent(text, () => ARBItem(
        text: text,
        translations: {},
      ));
      item.translations[locale] = row[_kColTargetLangValue]?.value?.toString() ?? '';
    }

  }
  return Translation(languages: languages, items: items.values.toList());
}

String? _quote(String? text) => text?.replaceAll('\n', r'\n');

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
    var bgColor = ExcelColor.grey200;
    sheetObject.setColumnWidth(_kColText, 30);
    sheetObject.setColumnWidth(_kColValue, 60);
    sheetObject.setColumnWidth(_kColTargetLangValue, 60);
    sheetObject.setColumnWidth(_kColDescription, 90);
    sheetObject.setColumnWidth(_kColContext, 30);
    sheetObject.appendRow([
      TextCellValue('Key'),
      TextCellValue('Text'),
      TextCellValue('Target Language Text'),
      TextCellValue('Description'),
      TextCellValue('Context')
    ]);
    var boldStyle = CellStyle(backgroundColorHex: bgColor, bold: true, bottomBorder: Border(borderColorHex: ExcelColor.black, borderStyle: BorderStyle.Thick));
    var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColText, rowIndex: _kRowHeader));
    cell.cellStyle = boldStyle;
    cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColValue, rowIndex: _kRowHeader));
    cell.cellStyle = boldStyle;
    cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColTargetLangValue, rowIndex: _kRowHeader));
    cell.cellStyle = boldStyle;
    cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColDescription, rowIndex: _kRowHeader));
    cell.cellStyle = boldStyle;
    cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColContext, rowIndex: _kRowHeader));
    cell.cellStyle = boldStyle;
    var disabledStyle = CellStyle(backgroundColorHex: bgColor);
    int rowIdx = _kRowValue;
    for (var item in data.items) {
      var row = <CellValue>[
        TextCellValue(item.text),
        TextCellValue(_quote(item.translations[leadLocale]) ?? '?'),
        TextCellValue(_quote(item.translations[targetLocale]) ?? ''),
        TextCellValue(item.description ?? ''),
        TextCellValue(item.context ?? '')
      ];
      sheetObject.appendRow(row);
      var cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColText, rowIndex: rowIdx));
      cell.cellStyle = disabledStyle;
      cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColValue, rowIndex: rowIdx));
      cell.cellStyle = disabledStyle;
      cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColDescription, rowIndex: rowIdx));
      cell.cellStyle = disabledStyle;
      cell = sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: _kColContext, rowIndex: rowIdx));
      cell.cellStyle = disabledStyle;
      rowIdx++;
    }
  }
  var bytes = excel.save(fileName: filename);
  if (bytes == null) {
    throw Exception("Error generating excel. Cannot encode");
  }
  stdout.writeln('Generating Excel file named $filename');
  File(filename).writeAsBytesSync(bytes);
}
