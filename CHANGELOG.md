# Changelog

## 0.0.1-dev

- Initial version

## 0.0.2-dev

- Fixed embedding the Excel template
- Fixed ARB format

## 0.0.3-dev

- Add condition formats to the template
- Fixed default translation

## 0.0.4

- Support `ShareString`

## 0.1.0

- Support generating Excel Files from ARB Files
- Added command line option to determine name of the output file to generate
- Added command line option to define the *lead locale* used as the source locale in translation excels created.
- Migrated to Flutter 3.27.x and newer versions of used Excel Plugin.
- Added support for importing and exporting selected languages only (including and not including the lead locale resources).
- Added option for filtering resources depending on review markers (e.g. "x-reviewed": false) and option to merge existing
  ARB file with translated contents from Excel.
- Removed useless -n command line option.
- Added flag to place all messages for all languages in generated Excel on one sheet.
