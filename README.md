# ARB Excel

For reading, creating and updating ARB files from XLSX files.

## Install

```bash
pub global activate arb_excel
```

## Usage

```bash
pub global run arb_excel

USAGE:
  arb_sheet [OPTIONS] path_or_filename[s]

OPTIONS
-o, --output                    Name of output file to create
-a, --[no-]arb                  Convert Excel Sheet to ARB files
-e, --[no-]excel                Convert ARB files to Excel Sheet. Specify director(ies) or name(s) of ARB files to convert as additional arguments.
-m, --[no-]merge                Merge data from Excel Sheet into ARB file. Specify name of Excel Sheet and ARB file to import.
-l, --leadLocale                Name of the primary (aka lead) locale.
-t, --targetLocales             A comma separated list of locale names to be included in the Excel file created.
-i, --[no-]includeLeadLocale    Whether the ARB file for the lead locale should be extracted from the Excel as well.
-f, --filter                    Filter ARB resources to export depending on meta tag. Example: -f x-reviewed:false
```

Examples:

Generates ARB files from an XLSX file.

Creates an Excel file (`-e`) named `example/example.xlsx` (`-o ...`) from ARB files from directory `example`,
lead locale is `en` (`-l en`).

```bash
dart pub global run arb_excel -l en -e -o example/example.xlsx example
```

Merge (`-m`) the contents of file `exmample/example.xlsx` back into the ARB files located in directory `example`.
Lead locale is `en` (`-l en`). Also extract the entries from the lead locale (`-i`).

```bash
dart pub global run arb_excel -l en -i -m example/example.xlsx
```

Create an ARB file (`-a`) named `test_vi.arb` (`-o test.arb`) from the contents of file `exmample/example.xlsx`.

```bash
dart pub global run arb_excel -a example/example.xlsx -o test.arb
```

