/// Minimal RFC 4180 reader: quoted fields, `""` escapes, commas and
/// newlines inside quotes, `\r\n` or `\n` line ends, and a leading BOM.
///
/// The delimiter is sniffed from the first line (`,`, `;` or tab), since
/// spreadsheets in some locales save semicolon-separated files. Fully
/// blank lines are dropped.
List<List<String>> readCsv(String text) {
  final source = text.startsWith('﻿') ? text.substring(1) : text;
  final delimiter = _sniffDelimiter(source);

  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    if (row.any((value) => value.trim().isNotEmpty)) rows.add(row);
    row = <String>[];
  }

  for (var i = 0; i < source.length; i++) {
    final char = source[i];
    if (inQuotes) {
      if (char == '"') {
        if (i + 1 < source.length && source[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(char);
      }
    } else if (char == '"') {
      inQuotes = true;
    } else if (char == delimiter) {
      endField();
    } else if (char == '\n') {
      endRow();
    } else if (char != '\r') {
      field.write(char);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

String _sniffDelimiter(String source) {
  final newline = source.indexOf('\n');
  final firstLine = newline == -1 ? source : source.substring(0, newline);
  var best = ',';
  var bestCount = 0;
  for (final candidate in const [',', ';', '\t']) {
    final count = candidate.allMatches(firstLine).length;
    if (count > bestCount) {
      best = candidate;
      bestCount = count;
    }
  }
  return best;
}
