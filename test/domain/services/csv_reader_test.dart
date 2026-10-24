import 'package:flutter_test/flutter_test.dart';
import 'package:intellispendiq/domain/services/csv_reader.dart';

void main() {
  group('readCsv', () {
    test('reads plain rows and drops blank lines', () {
      expect(readCsv('a,b\n1,2\n\n3,4\n'), [
        ['a', 'b'],
        ['1', '2'],
        ['3', '4'],
      ]);
    });

    test('handles quotes, escaped quotes, commas and newlines in fields', () {
      expect(readCsv('a,b\r\n"x, y","say ""hi""\nbye"\r\n'), [
        ['a', 'b'],
        ['x, y', 'say "hi"\nbye'],
      ]);
    });

    test('strips a BOM and reads semicolon-separated files', () {
      expect(readCsv('﻿a;b\n1;2'), [
        ['a', 'b'],
        ['1', '2'],
      ]);
    });

    test('keeps empty trailing fields', () {
      expect(readCsv('a,b,c\n1,,'), [
        ['a', 'b', 'c'],
        ['1', '', ''],
      ]);
    });
  });
}
