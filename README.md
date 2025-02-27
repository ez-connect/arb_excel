# ARB Excel

For reading, creating and updating ARB files from XLSX files.

## Install

```bash
pub global activate arb_excel
```

## Usage

```bash
pub global run arb_excel

arb_sheet [OPTIONS] path/to/file/name

OPTIONS
-n, --new      New translation sheet
-a, --arb      Export to ARB files
-e, --excel    Import ARB files to sheet. Specify directory or name of main ARB file to import.
-o, --output   Name of the output file to create. If not specified, the name is derived from the input file name.
-l, --leadLocale The primary locale (aka lead or developer locale). When generating Excel files, it is assumed, this is the source locale.
```

Creates a XLSX template file.

```bash
pub global run arb_excel -n app.xlsx
```

Generates ARB files from a XLSX file.

```bash
pub global run arb_excel -a app.xlsx
```

Creates a XLSX file from ARB files.

```bash
pub global run arb_excel -e app_en.arb
```
