// Copyright 2017 Google Inc.
//
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file or at
// https://developers.google.com/open-source/licenses/bsd

import 'package:recase/recase.dart';
import 'package:test/test.dart';

void main() {
  group('Entity name', () {
    test('should produce correct formats of names', () {
      final name = new ReCase('abc_bcd_cde');
      expect(name.titleCase, 'Abc Bcd Cde');
      expect(name.camelCase, 'AbcBcdCde');
      expect(name.camelCase.toLowerCase(), 'abcBcdCde');
      expect(name.paramCase, 'abc-bcd-cde');
      expect(name.snakeCase, 'abc_bcd_cde');
    });
    test('should be handle to handle different types of input', () {
      final camelCasedName1 = new ReCase('AbcBcdCde');
      expect(camelCasedName1.snakeCase, 'abc_bcd_cde');
      final camelCasedName2 = new ReCase('abcBcdCde');
      expect(camelCasedName2.snakeCase, 'abc_bcd_cde');
      final dashedName = new ReCase('abc-bcd-cde');
      expect(dashedName.snakeCase, 'abc_bcd_cde');
    });
    test('should throw for incorrect formats', () {
      expect(() => new ReCase('Abc-bcd'), throwsArgumentError);
      expect(() => new ReCase('abc-bcd_cde'), throwsArgumentError);
      expect(() => new ReCase('_abc'), throwsArgumentError);
    });
  });
}
