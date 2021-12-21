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
      abbr: 'e', defaultsTo: false, help: 'Import ARB files to sheet');
  final flags = parse.parse(args);

  // Not enough args
  if (args.length < 2) {
    usage(parse);
    exit(1);
  }

  final filename = flags.rest.first;

  if (flags['new']) {
    stdout.writeln('Create new Excel file for translation: $filename');
    File('example/example.xlsx').copySync(filename);
    exit(0);
  }

  if (flags['arb']) {
    stdout.writeln('Generate ARB from: $filename');
    final data = parseExcel(filename: filename);
    writeARB('${withoutExtension(filename)}.arb', data);
    exit(0);
  }

  if (flags['excel']) {
    stdout.writeln('Generate Excel from: $filename');
    final data = parseARB(filename);
    writeExcel('${withoutExtension(filename)}.xlsx', data);
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
