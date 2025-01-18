# ARB Excel

For reading, creating and updating ARB files from XLSX files.

## Install

```bash
pub global activate arb_excel
```

## Usage

```bash
pub global run arb_excel

arb_sheet [OPTIONS] path_or_filename(s)

OPTIONS
-e, --excel    Import ARB files to sheet. Specify directory or name of main ARB file to import.
-a, --arb      Export to ARB files
-m, --merge    Merge data from excel file into ARB file. Specify name of Excel and ARB file to import.
-f, --filter   Filter ARB resources to export depending on meta tag. Example: -f x-reviewed:false.
-t, --targetLocales An optional comma separated list of locale names to be included in the Excel file created.
-o, --output   Name of the output file to create. If not specified, the name is derived from the input file name.
-l, --leadLocale The primary locale (aka lead or developer locale). When generating Excel files, it is assumed, this is the source locale.
-i, --includeLeadLocale Whether the ARB file for the lead locale should be extracted from the Excel as well.
```

Examples:

Generates ARB files from a XLSX file.

Creates an Excel file (`-e`) named `example/example.xlsx` (`-o ...`) from ARB files from directory `example`,
lead locale is `en` (`-l en`).

```bash
dart pub global run arb_excel -l en -e -o example/example.xlsx example
```

Merge (`-m`) the contents of file `exmample/example.xlsx` back into the ARB files located in directory example.
Lead locale is `en` (`-l en`). Also extract the entries from the lead locale (`-i`).

```bash
dart pub global run arb_excel -l en -i -m example/example.xlsx
```

