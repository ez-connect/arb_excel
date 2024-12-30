import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

import 'package:arb_excel/arb_excel.dart';

const _kVersion = '0.0.1';

void main(List<String> args) {
  final parse = ArgParser();
  parse.addFlag('new',
      abbr: 'n', defaultsTo: false, help: 'New translation sheet');
  parse.addFlag('arb',
      abbr: 'a', defaultsTo: false, help: 'Export to ARB files');
  parse.addFlag('excel',
      abbr: 'e', defaultsTo: false, help: 'Import ARB files to sheet. Specify directory or name of main ARB file to import.');
  parse.addOption('output',
      abbr: 'o', help: 'Name of output file to create');
  parse.addOption('leadLocale',
      abbr: 'l', help: 'Name of the primary (aka lead) locale.');
  parse.addOption('targetLocales',
      abbr: 't', help: 'A comma separated list of locale names to be included in the Excel file created.');
  parse.addFlag('includeLeadLocale',
      abbr: 'i', help: 'Whether the ARB file for the lead locale should be extracted from the Excel as well.');
  final flags = parse.parse(args);

  // Not enough args
  if (args.length < 2) {
    usage(parse);
    exit(1);
  }

  var filename = flags.rest.first;
  var inputFile = filename;
  var outputFile = flags['output'];
  if (flags['new']) {
    stdout.writeln('Create new Excel file for translation: $filename');
    newTemplate(filename);
    exit(0);
  }

  if (flags['arb']) {
    stdout.writeln('Generate ARB from: $filename');
    var includeLeadLocale = flags['includeLeadLocale'] ?? false;
    final data = parseExcel(filename: filename, includeLeadLocale: includeLeadLocale);
    writeARB('${withoutExtension(filename)}.arb', data, includeLeadLocale);
    exit(0);
  }

  if (flags['excel']) {
    final targetLocales = flags['targetLocales'];
    var targetLocaleList = targetLocales?.split(",");
    var leadLocale = flags['leadLocale'];
    final data = parseARB(filename, targetLocales: targetLocaleList, leadLocale: leadLocale);
    final d = Directory(filename);
    if (outputFile == null && d.existsSync() && data.$2 != null) {
      outputFile = '${data.$2}.xlsx';
    }
    outputFile ??= '${withoutExtension(inputFile)}.xlsx';
    stdout.writeln('Generate Excel file named $outputFile from: $inputFile');
    leadLocale ??= data.$1.languages.firstOrNull;
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
