import 'dart:io';

import 'package:excel/excel.dart';

import 'package:arb_excel/src/arb.dart';

const _kRowHeader = 0;
const _kRowValue = 1;
const _kColContext = 0;
const _kColText = 1;
const _kColDescription = 2;
const _kColValue = 3;
const _kColTargetLangValue = 4;

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
  final items = <String, ARBItem>{};
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

        final item = items.putIfAbsent(
            text,
            () => ARBItem(
                  messageKey: text,
                  context: row[_kColContext]?.value?.toString(),
                  description: row[_kColDescription]?.value?.toString(),
                  translations: {},
                ));
        item.translations[leadLocale] =
            row[_kColValue]?.value?.toString() ?? '';
      }
      firstLocale = false;
    }
    languages.add(locale);
    for (int i = valueRow; i < sheet.rows.length; i++) {
      final row = sheet.rows[i];
      var text = row[_kColText]?.value?.toString() ?? '';

      final item = items.putIfAbsent(
          text,
          () => ARBItem(
                messageKey: text,
                translations: {},
              ));
      item.translations[locale] =
          row[_kColTargetLangValue]?.value?.toString() ?? '';
    }
  }
  return Translation(languages: languages, items: items.values.toList());
}

String? _quote(String? text) => text?.replaceAll('\n', r'\n');

/// Writes a Excel file, includes all translations.
void writeExcel(String filename,
    {required Translation data,
    required String leadLocale,
    required bool singleSheet}) {
  var excel = Excel.createExcel();
  var sheets = excel.sheets;
  var defaultSheet = sheets.isNotEmpty ? sheets.keys.first : null;
  var bgColorDoNotEdit = ExcelColor.fromHexString("#D6DCE4");
  var bgColorHeader = ExcelColor.fromHexString("#4472C4");
  var boldStyle = CellStyle(
      backgroundColorHex: bgColorHeader,
      bold: true,
      fontColorHex: ExcelColor.white,
      bottomBorder: Border(
          borderColorHex: ExcelColor.black, borderStyle: BorderStyle.Thick));
  var disabledStyle = CellStyle(backgroundColorHex: bgColorDoNotEdit);
  if (!singleSheet) {
    for (final targetLocale in data.languages) {
      if (targetLocale == leadLocale) {
        continue;
      }
      var name = '$leadLocale - $targetLocale';
      var sheetObject = excel[name];
      if (defaultSheet != null) {
        excel.delete(defaultSheet);
        defaultSheet = null;
      }
      sheetObject.setColumnWidth(_kColValue, 60);
      sheetObject.setColumnWidth(_kColTargetLangValue, 60);
      sheetObject.setColumnWidth(_kColDescription, 90);
      var headerCells = [
        TextCellValue('Context'),
        TextCellValue('Key'),
        TextCellValue('Description'),
        TextCellValue(leadLocale),
        TextCellValue(targetLocale),
      ];
      sheetObject.appendRow(headerCells);
      makeHeaderCellsBold(sheetObject, headerCells, boldStyle);
      int rowIdx = _kRowValue;
      for (final item in data.items) {
        var t = item.translations[targetLocale];
        if (t == null) {
          continue;
        }
        var row = <CellValue?>[];
        row.length = 5;
        addDefaultCells(row, item, leadLocale);
        row[_kColTargetLangValue] = TextCellValue(_quote(t) ?? '');
        disableCells(sheetObject, rowIdx, disabledStyle);
        sheetObject.appendRow(row);
        rowIdx++;
      }
      sheetObject.setColumnAutoFit(_kColText);
      sheetObject.setColumnAutoFit(_kColContext);
    }
  } else {
    var foreignLanguages =
        data.languages.where((l) => l != leadLocale).toList();
    var sheetObject = excel['Translations'];
    if (defaultSheet != null) {
      excel.delete(defaultSheet);
      defaultSheet = null;
    }
    sheetObject.setColumnWidth(_kColValue, 60);
    sheetObject.setColumnWidth(_kColTargetLangValue, 60);
    sheetObject.setColumnWidth(_kColDescription, 90);
    var headerCells = [
      TextCellValue('Context'),
      TextCellValue('Key'),
      TextCellValue('Description'),
      TextCellValue(leadLocale),
      ...foreignLanguages.map((l) {
        var name = '$leadLocale - $l';
        return TextCellValue(name);
      })
    ];
    sheetObject.appendRow(headerCells);
    makeHeaderCellsBold(sheetObject, headerCells, boldStyle);
    int rowIdx = _kRowValue;
    for (final item in data.items) {
      var row = <CellValue?>[];
      row.length = 5 + foreignLanguages.length;
      addDefaultCells(row, item, leadLocale);
      for (int i = 0; i < foreignLanguages.length; i++) {
        var locale = foreignLanguages[i];
        var t = item.translations[locale];
        if (t == null) {
          continue;
        }
        var cellValue = TextCellValue(_quote(t) ?? '');
        row[_kColTargetLangValue + i] = cellValue;
      }
      sheetObject.appendRow(row);
      disableCells(sheetObject, rowIdx, disabledStyle);
      rowIdx++;
    }
    sheetObject.setColumnAutoFit(_kColText);
    sheetObject.setColumnAutoFit(_kColContext);
    for (int i = 0; i < foreignLanguages.length; i++) {
      sheetObject.setColumnAutoFit(_kColTargetLangValue + i);
    }
  }
  var bytes = excel.save(fileName: filename);
  if (bytes == null) {
    throw Exception("Error generating excel. Cannot encode");
  }
  File(filename).writeAsBytesSync(bytes);
}

void makeHeaderCellsBold(
    Sheet sheetObject, List<TextCellValue> headerCells, CellStyle boldStyle) {
  for (int i = 0; i < headerCells.length; i++) {
    var cell = sheetObject.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: _kRowHeader));
    cell.cellStyle = boldStyle;
  }
}

void addDefaultCells(List<CellValue?> row, ARBItem item, String leadLocale) {
  row[_kColContext] = TextCellValue(item.context ?? '');
  row[_kColText] = TextCellValue(item.messageKey);
  row[_kColValue] = TextCellValue(_quote(item.translations[leadLocale]) ?? '?');
  row[_kColDescription] = TextCellValue(item.description ?? '');
}

void disableCells(Sheet sheetObject, int rowIdx, CellStyle disabledStyle) {
  var cell = sheetObject.cell(
      CellIndex.indexByColumnRow(columnIndex: _kColText, rowIndex: rowIdx));
  cell.cellStyle = disabledStyle;
  cell = sheetObject.cell(
      CellIndex.indexByColumnRow(columnIndex: _kColValue, rowIndex: rowIdx));
  cell.cellStyle = disabledStyle;
  cell = sheetObject.cell(CellIndex.indexByColumnRow(
      columnIndex: _kColDescription, rowIndex: rowIdx));
  cell.cellStyle = disabledStyle;
  cell = sheetObject.cell(
      CellIndex.indexByColumnRow(columnIndex: _kColContext, rowIndex: rowIdx));
  cell.cellStyle = disabledStyle;
}
