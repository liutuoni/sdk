// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analysis_server/src/services/linter/lint_names.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_processor.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RemoveArgumentBulkTest);
    defineReflectiveTests(RemoveArgumentTest);
  });
}

@reflectiveTest
class RemoveArgumentBulkTest extends BulkFixProcessorTest {
  @override
  String get lintCode => LintNames.avoid_redundant_argument_values;

  Future<void> test_independentInvocations() async {
    await resolveTestCode('''
void f({bool valWithDefault = true, bool val}) {}
void f2({bool valWithDefault = true, bool val}) {}

void main() {
  f(valWithDefault: true);
  f2(valWithDefault: true, val: false);
}
''');
    await assertHasFix('''
void f({bool valWithDefault = true, bool val}) {}
void f2({bool valWithDefault = true, bool val}) {}

void main() {
  f();
  f2(val: false);
}
''');
  }

  Future<void> test_multipleInSingleInvocation() async {
    await resolveTestCode('''
void f() {
  g(a: 0, b: 1, c: 2);
}

void g({int a = 0, int b = 1, int c = 2}) {}
''');
    await assertHasFix('''
void f() {
  g();
}

void g({int a = 0, int b = 1, int c = 2}) {}
''');
  }
}

@reflectiveTest
class RemoveArgumentTest extends FixProcessorLintTest {
  @override
  FixKind get kind => DartFixKind.REMOVE_ARGUMENT;

  @override
  String get lintCode => LintNames.avoid_redundant_argument_values;

  Future<void> test_named_param() async {
    await resolveTestCode('''
void f({bool valWithDefault = true, bool? val}) {}

void main() {
  f(valWithDefault: true);
}
''');
    await assertHasFix('''
void f({bool valWithDefault = true, bool? val}) {}

void main() {
  f();
}
''');
  }

  Future<void> test_named_param_2() async {
    await resolveTestCode('''
void f({bool valWithDefault = true, bool? val}) {}

void main() {
  f(valWithDefault: true, val: false);
}
''');
    await assertHasFix('''
void f({bool valWithDefault = true, bool? val}) {}

void main() {
  f(val: false);
}
''');
  }

  Future<void> test_optional_positional() async {
    await resolveTestCode('''
void g(int x, [int y = 0]) {}

void main() {
  g(1, 0);
}
''');
    await assertHasFix('''
void g(int x, [int y = 0]) {}

void main() {
  g(1);
}
''');
  }
}
