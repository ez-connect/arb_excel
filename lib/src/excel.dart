import 'dart:convert';
import 'dart:io';

import 'package:arb_excel/src/assets.dart';
import 'package:excel/excel.dart';

import 'arb.dart';

const _kRowHeader = 0;
const _kRowValue = 1;
const _kColContext = 0;
const _kColText = 1;
const _kColDescription = 2;
const _kColValue = 3;
const _kColTargetLangValue = 4;

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
  int valueRow = _kRowValue,
}) {
  final buf = File(filename).readAsBytesSync();
  final excel = Excel.decodeBytes(buf);
  final languages = <String>[];
  final items = <String,ARBItem>{};
  bool firstLocale = true;
  for (final sheet in excel.sheets.values) {
    var idx = sheet.sheetName.lastIndexOf(" - ");
    if (idx < 0) {
      // Support for original format.
      if (sheet.sheetName != 'Text') {
        continue;
      }
    }
    var rowHeader = sheet.rows[_kRowHeader];
    var locale = rowHeader[_kColTargetLangValue]?.value?.toString() ?? 'vi';
    var leadLocale = rowHeader[_kColValue]?.value?.toString() ?? 'en';
    if (firstLocale && includeLeadLocale) {
      languages.add(leadLocale);
      for (int i = valueRow; i < sheet.rows.length; i++) {
        final row = sheet.rows[i];
        var text = row[_kColText]?.value?.toString() ?? '';

        final item = items.putIfAbsent(text, () => ARBItem(
          text: text,
          context: row[_kColContext]?.value?.toString(),
          description: row[_kColDescription]?.value?.toString(),
          translations: {},
        ));
        item.translations[leadLocale] = row[_kColValue]?.value?.toString() ?? '';
      }
      firstLocale = false;
    }
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
    var bgColorDoNotEdit = ExcelColor.fromHexString("#D6DCE4");
    var bgColorHeader = ExcelColor.fromHexString("#4472C4");
    sheetObject.setColumnWidth(_kColContext, 20);
    sheetObject.setColumnWidth(_kColText, 25);
    sheetObject.setColumnWidth(_kColValue, 60);
    sheetObject.setColumnWidth(_kColTargetLangValue, 60);
    sheetObject.setColumnWidth(_kColDescription, 90);
    sheetObject.appendRow([
      TextCellValue('Context'),
      TextCellValue('Key'),
      TextCellValue('Description'),
      TextCellValue(leadLocale),
      TextCellValue(targetLocale),
    ]);
    var boldStyle = CellStyle(backgroundColorHex: bgColorHeader, bold: true,
        fontColorHex: ExcelColor.white,
        bottomBorder: Border(borderColorHex: ExcelColor.black, borderStyle: BorderStyle.Thick));
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
    var disabledStyle = CellStyle(backgroundColorHex: bgColorDoNotEdit);
    int rowIdx = _kRowValue;
    for (var item in data.items) {
      var row = <CellValue?>[];
      row.length = 5;
      row[_kColContext] = TextCellValue(item.context ?? '');
      row[_kColText] = TextCellValue(item.text);
      row[_kColValue] = TextCellValue(_quote(item.translations[leadLocale]) ?? '?');
      row[_kColTargetLangValue] = TextCellValue(_quote(item.translations[targetLocale]) ?? '');
      row[_kColDescription] = TextCellValue(item.description ?? '');
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
