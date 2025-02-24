import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart';

import 'package:arb_excel/arb_excel.dart';

const _kVersion = '1.0.0';

void main(List<String> args) {
  final parse = ArgParser();
  parse.addOption('output',
      abbr: 'o', help: 'Name of output file to create');
  parse.addFlag('arb',
      abbr: 'a', help: 'Convert Excel Sheet to ARB files');
  parse.addFlag('excel',
      abbr: 'e', help: 'Convert ARB files to Excel Sheet. Specify director(ies) or name(s) of ARB files to convert as additional arguments.');
  parse.addFlag('merge',
      abbr: 'm', help: 'Merge data from Excel Sheet into ARB file. Specify name of Excel Sheet and ARB file to import.');
  parse.addOption('leadLocale',
      abbr: 'l', help: 'Name of the primary (aka lead) locale.');
  parse.addFlag('singleSheet',
      help: 'Whether all messages for all languages should be exported to a single Excel sheet.');
  parse.addOption('targetLocales',
      abbr: 't', help: 'A comma separated list of locale names to be included in the Excel file created.');
  parse.addFlag('includeLeadLocale',
      abbr: 'i', help: 'Whether the ARB file for the lead locale should be extracted from the Excel as well.');
  parse.addOption('review-marker',
      abbr: 'r', help: 'Filter ARB resources to export depending on a review marker. Example: -r x-reviewed:false. Maybe also used with merge option to update the review markers in merged ARB files.');

  ArgResults flags;
  try {
    flags = parse.parse(args);
    // Not enough args
    if (args.length < 2) {
      usage(parse);
    }
  } on FormatException {
    usage(parse);
  }

  var filename = flags.rest.first;
  var outputFile = flags.option('output');
  var leadLocale = flags.option('leadLocale');
  var reviewMarkerSpec = flags['review-marker'];
  var filter = reviewMarkerSpec is! String ? null : ARBFilter.parse(reviewMarkerSpec);

  var merge = flags.flag('merge');
  if (flags.flag('arb') || merge) {
    var includeLeadLocale = flags.flag('includeLeadLocale');
    var data = parseExcel(filename: filename, includeLeadLocale: includeLeadLocale);
    writeARB(filename, [outputFile ?? withoutExtension(filename)], data, includeLeadLocale: includeLeadLocale,
        merge: merge, leadLocale: leadLocale, filter: filter);
    exit(0);
  }

  if (flags.flag('excel')) {
    if (outputFile == null) {
      usage(parse);
    }
    var targetLocales = flags.option('targetLocales');
    var targetLocaleList = targetLocales?.split(",");
    var inputFiles = flags.rest;
    var data = parseARB(inputFiles, targetLocales: targetLocaleList, leadLocale: leadLocale, filter: filter);
    stdout.writeln('Generating Excel file named $outputFile from: ${data.$2.join(', ')}');
    leadLocale ??= data.$1.languages.firstOrNull ?? 'en';
    writeExcel(outputFile, data: data.$1, leadLocale: leadLocale, singleSheet: flags.flag("singleSheet"));
    exit(0);
  }
}

Never usage(ArgParser parse) {
  stdout.writeln('arb_sheet v$_kVersion\n');
  stdout.writeln('USAGE:');
  stdout.writeln(
    '  arb_sheet [OPTIONS] path_or_filename[s]\n',
  );
  stdout.writeln('OPTIONS');
  stdout.writeln(parse.usage);
  exit(1);
}
