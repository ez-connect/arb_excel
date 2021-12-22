import 'dart:convert';
import 'dart:io';

void main() {
  final buf = File('example/example.xlsx').readAsBytesSync();
  final data =
      "/// Embeded Excel template data.\nconst kTemplate = '${base64Encode(buf)}';\n";
  File('lib/src/assets.dart').writeAsString(data);
}
