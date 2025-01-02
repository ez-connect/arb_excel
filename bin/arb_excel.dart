import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

import 'package:arb_excel/arb_excel.dart';

const _kVersion = '0.0.1';

void main(List<String> args) {
  final parse = ArgParser();
  parse.addFlag('new',
      abbr: 'n', help: 'New translation sheet');
  parse.addFlag('arb',
      abbr: 'a', help: 'Export to ARB files');
  parse.addFlag('excel',
      abbr: 'e', help: 'Import ARB files to sheet. Specify directory or name of main ARB file to import.');
  parse.addFlag('merge',
      abbr: 'm', help: 'Merge data from excel file into ARB file. Specify name of Excel and ARB file to import.');
  parse.addOption('output',
      abbr: 'o', help: 'Name of output file to create');
  parse.addOption('leadLocale',
      abbr: 'l', help: 'Name of the primary (aka lead) locale.');
  parse.addOption('targetLocales',
      abbr: 't', help: 'A comma separated list of locale names to be included in the Excel file created.');
  parse.addFlag('includeLeadLocale',
      abbr: 'i', help: 'Whether the ARB file for the lead locale should be extracted from the Excel as well.');
  parse.addOption('filter',
      abbr: 'f', help: 'Filter ARB resources to export depending on meta tag. Example: -f x-reviewed:false');
  final flags = parse.parse(args);

  // Not enough args
  if (args.length < 2) {
    usage(parse);
    exit(1);
  }

  var filename = flags.rest.first;
  var inputFile = filename;
  var outputFile = flags.option('output');
  if (flags['new'] == true) {
    stdout.writeln('Create new Excel file for translation: $filename');
    newTemplate(filename);
    exit(0);
  }

  var merge = flags.flag('merge');
  if (flags['arb'] == true || merge) {
    stdout.writeln('Generate ARB from: $filename');
    var includeLeadLocale = flags.flag('includeLeadLocale');
    var data = parseExcel(filename: filename, includeLeadLocale: includeLeadLocale);
    writeARB('${withoutExtension(filename)}.arb', data, includeLeadLocale: includeLeadLocale, merge: merge);
    exit(0);
  }

  if (flags.flag('excel')) {
    var targetLocales = flags.option('targetLocales');
    var targetLocaleList = targetLocales?.split(",");
    var leadLocale = flags.option('leadLocale');
    var filter = flags['filter'];
    var data = parseARB(filename, targetLocales: targetLocaleList, leadLocale: leadLocale, filter: filter is! String ? null : ARBFilter.parse(filter));
    var d = Directory(filename);
    if (outputFile == null && d.existsSync() && data.$2 != null) {
      outputFile = '${data.$2}.xlsx';
    }
    outputFile ??= '${withoutExtension(inputFile)}.xlsx';
    stdout.writeln('Generate Excel file named $outputFile from: $inputFile');
    leadLocale ??= data.$1.languages.firstOrNull ?? 'en';
    writeExcel(outputFile, data.$1, leadLocale);
    exit(0);
  }
}

void usage(ArgParser parse) {
  stdout.writeln('arb_sheet v$_kVersion\n');
  stdout.writeln('USAGE:');
  stdout.writeln(
    '  arb_sheet [OPTIONS] path/to/file/name\n',
  );
  stdout.writeln('OPTIONS');
  stdout.writeln(parse.usage);
}
