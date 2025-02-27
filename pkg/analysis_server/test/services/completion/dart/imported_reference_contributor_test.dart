// Copyright (c) 2014, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/protocol_server.dart';
import 'package:analysis_server/src/provisional/completion/dart/completion_dart.dart';
import 'package:analysis_server/src/services/completion/dart/completion_manager.dart';
import 'package:analysis_server/src/services/completion/dart/imported_reference_contributor.dart';
import 'package:analysis_server/src/services/completion/dart/suggestion_builder.dart';
import 'package:analyzer/src/dart/analysis/experiments.dart';
import 'package:test/test.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'completion_contributor_util.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ImportedReferenceContributorTest);
  });
}

mixin ImportedReferenceContributorMixin on DartCompletionContributorTest {
  @override
  bool get isNullExpectedReturnTypeConsideredDynamic => false;

  @override
  DartCompletionContributor createContributor(
    DartCompletionRequest request,
    SuggestionBuilder builder,
  ) {
    return ImportedReferenceContributor(request, builder);
  }
}

@reflectiveTest
class ImportedReferenceContributorTest extends DartCompletionContributorTest
    with ImportedReferenceContributorMixin {
  Future<void> test_Annotation_typeArguments() async {
    addSource('/home/test/lib/a.dart', '''
class C {}
typedef T1 = void Function();
typedef T2 = List<int>;
''');

    addTestSource('''
import 'a.dart';

class A<T> {
  const A();
}

@A<^>()
void f() {}
''');
    await computeSuggestions();

    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('C');
    assertSuggestTypeAlias('T1',
        aliasedType: 'void Function()', returnType: 'void');
    assertSuggestTypeAlias('T2', aliasedType: 'List<int>');
    assertNotSuggested('identical');
  }

  /// Sanity check.  Permutations tested in local_ref_contributor.
  Future<void> test_ArgDefaults_function_with_required_named() async {
    writeTestPackageConfig(meta: true);

    resolveSource('/home/test/lib/b.dart', '''
lib B;
import 'package:meta/meta.dart';

bool foo(int bar, {bool boo, @required int baz}) => false;
''');

    addTestSource('''
import 'b.dart';

void f() {f^}''');
    await computeSuggestions();

    assertSuggestFunction('foo', 'bool', defaultArgListString: 'bar, baz: baz');
  }

  Future<void> test_ArgumentList() async {
    // ArgumentList  MethodInvocation  ExpressionStatement  Block
    resolveSource('/home/test/lib/a.dart', '''
        library A;
        bool hasLength(int expected) { }
        void baz() { }''');
    addTestSource('''
        import 'a.dart';
        class B { }
        String bar() => true;
        void f() {expect(^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    assertSuggestFunction('hasLength', 'bool');
    assertSuggestFunction('identical', 'bool');
    assertNotSuggested('B');
    assertSuggestClass('Object');
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void> test_ArgumentList_imported_function() async {
    // ArgumentList  MethodInvocation  ExpressionStatement  Block
    resolveSource('/home/test/lib/a.dart', '''
        library A;
        bool hasLength(int expected) { }
        expect(arg) { }
        void baz() { }''');
    addTestSource('''
        import 'a.dart';
        class B { }
        String bar() => true;
        void f() {expect(^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    assertSuggestFunction('hasLength', 'bool');
    assertSuggestFunction('identical', 'bool');
    assertNotSuggested('B');
    assertSuggestClass('Object');
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void>
      test_ArgumentList_InstanceCreationExpression_functionalArg() async {
    // ArgumentList  InstanceCreationExpression  ExpressionStatement  Block
    addSource('/home/test/lib/a.dart', '''
        library A;
        class A { A(f()) { } }
        bool hasLength(int expected) { }
        void baz() { }''');
    addTestSource('''
        import 'dart:async';
        import 'a.dart';
        class B { }
        String bar() => true;
        void f() {new A(^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    assertSuggestFunction('hasLength', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestFunction('identical', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('B');
    assertSuggestClass('A', kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestClass('Object', kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void> test_ArgumentList_InstanceCreationExpression_typedefArg() async {
    // ArgumentList  InstanceCreationExpression  ExpressionStatement  Block
    addSource('/home/test/lib/a.dart', '''
        library A;
        typedef Funct();
        class A { A(Funct f) { } }
        bool hasLength(int expected) { }
        void baz() { }''');
    addTestSource('''
        import 'dart:async';
        import 'a.dart';
        class B { }
        String bar() => true;
        void f() {new A(^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    assertSuggestFunction('hasLength', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestFunction('identical', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('B');
    assertSuggestClass('A', kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestClass('Object', kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void> test_ArgumentList_local_function() async {
    // ArgumentList  MethodInvocation  ExpressionStatement  Block
    resolveSource('/home/test/lib/a.dart', '''
        library A;
        bool hasLength(int expected) { }
        void baz() { }''');
    addTestSource('''
        import 'a.dart';
        expect(arg) { }
        class B { }
        String bar() => true;
        void f() {expect(^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    assertSuggestFunction('hasLength', 'bool');
    assertSuggestFunction('identical', 'bool');
    assertNotSuggested('B');
    assertSuggestClass('Object');
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void> test_ArgumentList_local_method() async {
    // ArgumentList  MethodInvocation  ExpressionStatement  Block
    resolveSource('/home/test/lib/a.dart', '''
        library A;
        bool hasLength(int expected) { }
        void baz() { }''');
    addTestSource('''
        import 'a.dart';
        class B {
          expect(arg) { }
          void foo() {expect(^)}}
        String bar() => true;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    assertSuggestFunction('hasLength', 'bool');
    assertSuggestFunction('identical', 'bool');
    assertNotSuggested('B');
    assertSuggestClass('Object');
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void> test_ArgumentList_MethodInvocation_functionalArg() async {
    // ArgumentList  MethodInvocation  ExpressionStatement  Block
    addSource('/home/test/lib/a.dart', '''
        library A;
        class A { A(f()) { } }
        bool hasLength(int expected) { }
        void baz() { }''');
    addTestSource('''
        import 'dart:async';
        import 'a.dart';
        class B { }
        String bar(f()) => true;
        void f() {bar(^);}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    assertSuggestFunction('hasLength', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestFunction('identical', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('B');
    assertSuggestClass('A', kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestClass('Object', kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void> test_ArgumentList_MethodInvocation_methodArg() async {
    // ArgumentList  MethodInvocation  ExpressionStatement  Block
    addSource('/home/test/lib/a.dart', '''
        library A;
        class A { A(f()) { } }
        bool hasLength(int expected) { }
        void baz() { }''');
    addTestSource('''
        import 'dart:async';
        import 'a.dart';
        class B { String bar(f()) => true; }
        void f() {new B().bar(^);}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestFunction('hasLength', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestFunction('identical', 'bool',
        kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('B');
    assertSuggestClass('A', kind: CompletionSuggestionKind.IDENTIFIER);
    assertSuggestClass('Object', kind: CompletionSuggestionKind.IDENTIFIER);
    assertNotSuggested('f');
    assertNotSuggested('baz');
    assertNotSuggested('print');
  }

  Future<void> test_ArgumentList_namedParam() async {
    // SimpleIdentifier  NamedExpression  ArgumentList  MethodInvocation
    // ExpressionStatement
    addSource('/home/test/lib/a.dart', '''
        library A;
        bool hasLength(int expected) { }''');
    addTestSource('''
        import 'a.dart';
        String bar() => true;
        void f() {expect(foo: ^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('bar');
    // An unresolved imported library will produce suggestions
    // with a null returnType
    // The current DartCompletionRequest#resolveExpression resolves
    // the world (which it should not) and causes the imported library
    // to be resolved.
    assertSuggestFunction('hasLength', /* null */ 'bool');
    assertNotSuggested('f');
  }

  Future<void> test_AsExpression() async {
    // SimpleIdentifier  TypeName  AsExpression
    addTestSource('''
        class A {var b; X _c; foo() {var a; (a as ^).foo();}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertSuggestClass('Object');
    assertNotSuggested('A');
    assertNotSuggested('==');
  }

  @failingTest
  Future<void> test_AsExpression_type_subtype_extends_filter() async {
    // This test fails because we are not filtering out the class `A` when
    // suggesting types. We ought to do so because there's no reason to cast a
    // value to the type it already has.

    // SimpleIdentifier  TypeName  AsExpression  IfStatement
    addSource('/home/test/lib/b.dart', '''
          foo() { }
          class A {} class B extends A {} class C extends B {}
          class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
          import 'b.dart';
         void f(){A a; if (a as ^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('B');
    assertSuggestClass('C');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('a');
    assertNotSuggested('f');
  }

  @failingTest
  Future<void> test_AsExpression_type_subtype_implements_filter() async {
    // This test fails because we are not filtering out the class `A` when
    // suggesting types. We ought to do so because there's no reason to cast a
    // value to the type it already has.

    // SimpleIdentifier  TypeName  AsExpression  IfStatement
    addSource('/home/test/lib/b.dart', '''
          foo() { }
          class A {} class B implements A {} class C implements B {}
          class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
          import 'b.dart';
          void f(){A a; if (a as ^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('B');
    assertSuggestClass('C');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('a');
    assertNotSuggested('f');
  }

  Future<void> test_AssignmentExpression_name() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // VariableDeclarationStatement  Block
    addTestSource('class A {} void f() {int a; int ^b = 1;}');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_AssignmentExpression_RHS() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // VariableDeclarationStatement  Block
    addTestSource('class A {} void f() {int a; int b = ^}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertNotSuggested('A');
    assertSuggestClass('Object');
  }

  Future<void> test_AssignmentExpression_type() async {
    // SimpleIdentifier  TypeName  VariableDeclarationList
    // VariableDeclarationStatement  Block
    addTestSource('''
        class A {} void f() {
          int a;
          ^ b = 1;}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertSuggestClass('int');
    // TODO (danrubel) When entering 1st of 2 identifiers on assignment LHS
    // the user may be either (1) entering a type for the assignment
    // or (2) starting a new statement.
    // Consider suggesting only types
    // if only spaces separates the 1st and 2nd identifiers.
    //assertNotSuggested('a');
    //assertNotSuggested('f');
    //assertNotSuggested('identical');
  }

  Future<void> test_AssignmentExpression_type_newline() async {
    // SimpleIdentifier  TypeName  VariableDeclarationList
    // VariableDeclarationStatement  Block
    addTestSource('''
        class A {} void f() {
          int a;
          ^
          b = 1;}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertSuggestClass('int');
    // Allow non-types preceding an identifier on LHS of assignment
    // if newline follows first identifier
    // because user is probably starting a new statement
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertSuggestFunction('identical', 'bool');
  }

  Future<void> test_AssignmentExpression_type_partial() async {
    // SimpleIdentifier  TypeName  VariableDeclarationList
    // VariableDeclarationStatement  Block
    addTestSource('''
        class A {} void f() {
          int a;
          int^ b = 1;}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 3);
    expect(replacementLength, 3);
    assertNotSuggested('A');
    assertSuggestClass('int');
    // TODO (danrubel) When entering 1st of 2 identifiers on assignment LHS
    // the user may be either (1) entering a type for the assignment
    // or (2) starting a new statement.
    // Consider suggesting only types
    // if only spaces separates the 1st and 2nd identifiers.
    //assertNotSuggested('a');
    //assertNotSuggested('f');
    //assertNotSuggested('identical');
  }

  Future<void> test_AssignmentExpression_type_partial_newline() async {
    // SimpleIdentifier  TypeName  VariableDeclarationList
    // VariableDeclarationStatement  Block
    addTestSource('''
        class A {} void f() {
          int a;
          i^
          b = 1;}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('A');
    assertSuggestClass('int');
    // Allow non-types preceding an identifier on LHS of assignment
    // if newline follows first identifier
    // because user is probably starting a new statement
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertSuggestFunction('identical', 'bool');
  }

  Future<void> test_AwaitExpression() async {
    // SimpleIdentifier  AwaitExpression  ExpressionStatement
    addTestSource('''
        class A {int x; int y() => 0;}
        void f() async {A a; await ^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertNotSuggested('A');
    assertSuggestClass('Object');
  }

  Future<void> test_AwaitExpression_function() async {
    resolveSource('/home/test/lib/a.dart', '''
Future y() async {return 0;}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  int x;
  foo() async {await ^}
}
''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestFunction('y', 'Future<dynamic>');
    assertNotSuggested('A');
    assertSuggestClass('Object');
  }

  Future<void> test_AwaitExpression_inherited() async {
    // SimpleIdentifier  AwaitExpression  ExpressionStatement
    addSource('/home/test/lib/b.dart', '''
lib libB;
class A {
  Future y() async { return 0; }
}''');
    addTestSource('''
import 'b.dart';
class B extends A {
  foo() async {await ^}
}
''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertSuggestClass('A');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
    assertSuggestClass('Object');
    assertNotSuggested('y');
  }

  Future<void> test_BinaryExpression_LHS() async {
    // SimpleIdentifier  BinaryExpression  VariableDeclaration
    // VariableDeclarationList  VariableDeclarationStatement
    addTestSource('void f() {int a = 1, b = ^ + 2;}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertSuggestClass('Object');
    assertNotSuggested('b');
  }

  Future<void> test_BinaryExpression_RHS() async {
    // SimpleIdentifier  BinaryExpression  VariableDeclaration
    // VariableDeclarationList  VariableDeclarationStatement
    addTestSource('void f() {int a = 1, b = 2 + ^;}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertSuggestClass('Object');
    assertNotSuggested('b');
    assertNotSuggested('==');
  }

  Future<void> test_Block() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addSource('/home/test/lib/ab.dart', '''
        export "dart:math" hide max;
        class A {int x;}
        @deprecated D1() {int x;}
        class _B {boo() { partBoo() {}} }''');
    addSource('/home/test/lib/cd.dart', '''
        String T1;
        var _T2;
        class C { }
        class D { }''');
    addSource('/home/test/lib/eef.dart', '''
        class EE { }
        class F { }''');
    addSource('/home/test/lib/g.dart', 'class G { }');
    addSource('/home/test/lib/h.dart', '''
        class H { }
        int T3;
        var _T4;'''); // not imported
    addTestSource('''
        import "ab.dart";
        import "cd.dart" hide D;
        import "eef.dart" show EE;
        import "g.dart" as g;
        int T5;
        var _T6;
        String get T7 => 'hello';
        set T8(int value) { partT8() {} }
        Z D2() {int x;}
        class X {
          int get clog => 8;
          set blog(value) { }
          a() {
            var f;
            localF(int arg1) { }
            {var x;}
            ^ var r;
          }
          void b() { }}
        class Z { }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);

    assertNotSuggested('X');
    assertNotSuggested('Z');
    assertNotSuggested('a');
    assertNotSuggested('b');
    assertNotSuggested('localF');
    assertNotSuggested('f');
    // Don't suggest locals out of scope
    assertNotSuggested('r');
    assertNotSuggested('x');
    assertNotSuggested('partT8');

    assertSuggestClass('A', elemFile: '/home/test/lib/ab.dart');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
    assertNotSuggested('_B');
    assertSuggestClass('C');
    assertNotSuggested('partBoo');
    // hidden element suggested as low relevance
    // but imported results are partially filtered
    //assertSuggestClass('D', COMPLETION_RELEVANCE_LOW);
    //assertSuggestFunction(
    //    'D1', null, true, COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('D2');
    assertSuggestClass('EE');
    // hidden element suggested as low relevance
    //assertSuggestClass('F', COMPLETION_RELEVANCE_LOW);
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('g');
    assertSuggestClass('g.G', elemName: 'G');
    assertNotSuggested('G');
    //assertSuggestClass('H', COMPLETION_RELEVANCE_LOW);
    assertSuggestClass('Object');
//    assertSuggestFunction('min', 'T');
    //assertSuggestFunction(
    //    'max',
    //    'num',
    //    false,
    //    COMPLETION_RELEVANCE_LOW);
    assertSuggestTopLevelVar('T1', null);
    assertNotSuggested('_T2');
    //assertSuggestImportedTopLevelVar('T3', 'int', COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('_T4');
    assertNotSuggested('T5');
    assertNotSuggested('_T6');
    assertNotSuggested('==');
    assertNotSuggested('T7');
    assertNotSuggested('T8');
    assertNotSuggested('clog');
    assertNotSuggested('blog');
    // TODO (danrubel) suggest HtmlElement as low relevance
    assertNotSuggested('HtmlElement');
    assertSuggestClass('Uri');
    assertNotSuggested('parseIPv6Address');
    assertNotSuggested('parseHex');
  }

  Future<void> test_Block_final() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addSource('/home/test/lib/ab.dart', '''
        export "dart:math" hide max;
        class A {int x;}
        @deprecated D1() {int x;}
        class _B {boo() { partBoo() {}} }''');
    addSource('/home/test/lib/cd.dart', '''
        String T1;
        var _T2;
        class C { }
        class D { }''');
    addSource('/home/test/lib/eef.dart', '''
        class EE { }
        class F { }''');
    addSource('/home/test/lib/g.dart', 'class G { }');
    addSource('/home/test/lib/h.dart', '''
        class H { }
        int T3;
        var _T4;'''); // not imported
    addTestSource('''
        import "ab.dart";
        import "cd.dart" hide D;
        import "eef.dart" show EE;
        import "g.dart" as g;
        int T5;
        var _T6;
        String get T7 => 'hello';
        set T8(int value) { partT8() {} }
        Z D2() {int x;}
        class X {
          int get clog => 8;
          set blog(value) { }
          a() {
            var f;
            localF(int arg1) { }
            {var x;}
            final ^
          }
          void b() { }}
        class Z { }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);

    assertNotSuggested('X');
    assertNotSuggested('Z');
    assertNotSuggested('a');
    assertNotSuggested('b');
    assertNotSuggested('localF');
    assertNotSuggested('f');
    // Don't suggest locals out of scope
    assertNotSuggested('r');
    assertNotSuggested('x');
    assertNotSuggested('partT8');

    assertSuggestClass('A');
    assertNotSuggested('_B');
    assertSuggestClass('C');
    assertNotSuggested('partBoo');
    // hidden element suggested as low relevance
    // but imported results are partially filtered
    //assertSuggestClass('D', COMPLETION_RELEVANCE_LOW);
    //assertSuggestFunction(
    //    'D1', null, true, COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('D2');
    assertSuggestClass('EE');
    // hidden element suggested as low relevance
    //assertSuggestClass('F', COMPLETION_RELEVANCE_LOW);
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('g');
    assertSuggestClass('g.G', elemName: 'G');
    //assertSuggestClass('H', COMPLETION_RELEVANCE_LOW);
    assertSuggestClass('Object');
    assertNotSuggested('min');
    //assertSuggestFunction(
    //    'max',
    //    'num',
    //    false,
    //    COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('T1');
    assertNotSuggested('_T2');
    //assertSuggestImportedTopLevelVar('T3', 'int', COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('_T4');
    assertNotSuggested('T5');
    assertNotSuggested('_T6');
    assertNotSuggested('==');
    assertNotSuggested('T7');
    assertNotSuggested('T8');
    assertNotSuggested('clog');
    assertNotSuggested('blog');
    // TODO (danrubel) suggest HtmlElement as low relevance
    assertNotSuggested('HtmlElement');
    assertSuggestClass('Uri');
    assertNotSuggested('parseIPv6Address');
    assertNotSuggested('parseHex');
  }

  Future<void> test_Block_final2() async {
    addTestSource('void f() {final S^ v;}');

    await computeSuggestions();
    assertSuggestClass('String');
  }

  Future<void> test_Block_final3() async {
    addTestSource('void f() {final ^ v;}');

    await computeSuggestions();
    assertSuggestClass('String');
  }

  Future<void> test_Block_final_final() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addSource('/home/test/lib/ab.dart', '''
        export "dart:math" hide max;
        class A {int x;}
        @deprecated D1() {int x;}
        class _B {boo() { partBoo() {}} }''');
    addSource('/home/test/lib/cd.dart', '''
        String T1;
        var _T2;
        class C { }
        class D { }''');
    addSource('/home/test/lib/eef.dart', '''
        class EE { }
        class F { }''');
    addSource('/home/test/lib/g.dart', 'class G { }');
    addSource('/home/test/lib/h.dart', '''
        class H { }
        int T3;
        var _T4;'''); // not imported
    addTestSource('''
        import "ab.dart";
        import "cd.dart" hide D;
        import "eef.dart" show EE;
        import "g.dart" as g hide G;
        int T5;
        var _T6;
        String get T7 => 'hello';
        set T8(int value) { partT8() {} }
        Z D2() {int x;}
        class X {
          int get clog => 8;
          set blog(value) { }
          a() {
            final ^
            final var f;
            localF(int arg1) { }
            {var x;}
          }
          void b() { }}
        class Z { }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);

    assertNotSuggested('X');
    assertNotSuggested('Z');
    assertNotSuggested('a');
    assertNotSuggested('b');
    assertNotSuggested('localF');
    assertNotSuggested('f');
    // Don't suggest locals out of scope
    assertNotSuggested('r');
    assertNotSuggested('x');
    assertNotSuggested('partT8');

    assertSuggestClass('A');
    assertNotSuggested('_B');
    assertSuggestClass('C');
    assertNotSuggested('partBoo');
    // hidden element suggested as low relevance
    // but imported results are partially filtered
    //assertSuggestClass('D', COMPLETION_RELEVANCE_LOW);
    //assertSuggestFunction(
    //    'D1', null, true, COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('D2');
    assertSuggestClass('EE');
    // hidden element suggested as low relevance
    //assertSuggestClass('F', COMPLETION_RELEVANCE_LOW);
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('g');
    assertNotSuggested('G');
    // Hidden elements not suggested
    assertNotSuggested('g.G');
    //assertSuggestClass('H', COMPLETION_RELEVANCE_LOW);
    assertSuggestClass('Object');
    assertNotSuggested('min');
    //assertSuggestFunction(
    //    'max',
    //    'num',
    //    false,
    //    COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('T1');
    assertNotSuggested('_T2');
    //assertSuggestImportedTopLevelVar('T3', 'int', COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('_T4');
    assertNotSuggested('T5');
    assertNotSuggested('_T6');
    assertNotSuggested('==');
    assertNotSuggested('T7');
    assertNotSuggested('T8');
    assertNotSuggested('clog');
    assertNotSuggested('blog');
    // TODO (danrubel) suggest HtmlElement as low relevance
    assertNotSuggested('HtmlElement');
    assertSuggestClass('Uri');
    assertNotSuggested('parseIPv6Address');
    assertNotSuggested('parseHex');
  }

  Future<void> test_Block_final_var() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addSource('/home/test/lib/ab.dart', '''
        export "dart:math" hide max;
        class A {int x;}
        @deprecated D1() {int x;}
        class _B {boo() { partBoo() {}} }''');
    addSource('/home/test/lib/cd.dart', '''
        String T1;
        var _T2;
        class C { }
        class D { }''');
    addSource('/home/test/lib/eef.dart', '''
        class EE { }
        class F { }''');
    addSource('/home/test/lib/g.dart', 'class G { }');
    addSource('/home/test/lib/h.dart', '''
        class H { }
        int T3;
        var _T4;'''); // not imported
    addTestSource('''
        import "ab.dart";
        import "cd.dart" hide D;
        import "eef.dart" show EE;
        import "g.dart" as g;
        int T5;
        var _T6;
        String get T7 => 'hello';
        set T8(int value) { partT8() {} }
        Z D2() {int x;}
        class X {
          int get clog => 8;
          set blog(value) { }
          a() {
            final ^
            var f;
            localF(int arg1) { }
            {var x;}
          }
          void b() { }}
        class Z { }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);

    assertNotSuggested('X');
    assertNotSuggested('Z');
    assertNotSuggested('a');
    assertNotSuggested('b');
    assertNotSuggested('localF');
    assertNotSuggested('f');
    // Don't suggest locals out of scope
    assertNotSuggested('r');
    assertNotSuggested('x');
    assertNotSuggested('partT8');

    assertSuggestClass('A');
    assertNotSuggested('_B');
    assertSuggestClass('C');
    assertNotSuggested('partBoo');
    // hidden element suggested as low relevance
    // but imported results are partially filtered
    //assertSuggestClass('D', COMPLETION_RELEVANCE_LOW);
    //assertSuggestFunction(
    //    'D1', null, true, COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('D2');
    assertSuggestClass('EE');
    // hidden element suggested as low relevance
    //assertSuggestClass('F', COMPLETION_RELEVANCE_LOW);
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('g');
    assertSuggestClass('g.G', elemName: 'G');
    //assertSuggestClass('H', COMPLETION_RELEVANCE_LOW);
    assertSuggestClass('Object');
    assertNotSuggested('min');
    //assertSuggestFunction(
    //    'max',
    //    'num',
    //    false,
    //    COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('T1');
    assertNotSuggested('_T2');
    //assertSuggestImportedTopLevelVar('T3', 'int', COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('_T4');
    assertNotSuggested('T5');
    assertNotSuggested('_T6');
    assertNotSuggested('==');
    assertNotSuggested('T7');
    assertNotSuggested('T8');
    assertNotSuggested('clog');
    assertNotSuggested('blog');
    // TODO (danrubel) suggest HtmlElement as low relevance
    assertNotSuggested('HtmlElement');
    assertSuggestClass('Uri');
    assertNotSuggested('parseIPv6Address');
    assertNotSuggested('parseHex');
  }

  Future<void> test_Block_identifier_partial() async {
    resolveSource('/home/test/lib/ab.dart', '''
        export "dart:math" hide max;
        class A {int x;}
        @deprecated D1() {int x;}
        class _B { }''');
    addSource('/home/test/lib/cd.dart', '''
        String T1;
        var _T2;
        class C { }
        class D { }''');
    addSource('/home/test/lib/eef.dart', '''
        class EE { }
        class DF { }''');
    addSource('/home/test/lib/g.dart', 'class G { }');
    addSource('/home/test/lib/h.dart', '''
        class H { }
        class D3 { }
        int T3;
        var _T4;'''); // not imported
    addTestSource('''
        import "ab.dart";
        import "cd.dart" hide D;
        import "eef.dart" show EE;
        import "g.dart" as g;
        int T5;
        var _T6;
        Z D2() {int x;}
        class X {a() {var f; {var x;} D^ var r;} void b() { }}
        class Z { }''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);

    assertNotSuggested('X');
    assertNotSuggested('Z');
    assertNotSuggested('a');
    assertNotSuggested('b');
    assertNotSuggested('f');
    // Don't suggest locals out of scope
    assertNotSuggested('r');
    assertNotSuggested('x');

    // imported elements are portially filtered
    //assertSuggestClass('A');
    assertNotSuggested('_B');
    // hidden element not suggested
    assertNotSuggested('D');
    assertSuggestFunction('D1', 'dynamic', isDeprecated: true);
    assertNotSuggested('D2');
    // Not imported, so not suggested
    assertNotSuggested('D3');
    //assertSuggestClass('EE');
    // hidden element not suggested
    assertNotSuggested('DF');
    //assertSuggestLibraryPrefix('g');
    assertSuggestClass('g.G', elemName: 'G');
    //assertSuggestClass('H', COMPLETION_RELEVANCE_LOW);
    //assertSuggestClass('Object');
    //assertSuggestFunction('min', 'num', false);
    //assertSuggestFunction(
    //    'max',
    //    'num',
    //    false,
    //    COMPLETION_RELEVANCE_LOW);
    //assertSuggestTopLevelVarGetterSetter('T1', 'String');
    assertNotSuggested('_T2');
    //assertSuggestImportedTopLevelVar('T3', 'int', COMPLETION_RELEVANCE_LOW);
    assertNotSuggested('_T4');
    //assertNotSuggested('T5');
    //assertNotSuggested('_T6');
    assertNotSuggested('==');
    // TODO (danrubel) suggest HtmlElement as low relevance
    assertNotSuggested('HtmlElement');
  }

  Future<void> test_Block_inherited_imported() async {
    // Block  BlockFunctionBody  MethodDeclaration  ClassDeclaration
    addSource('/home/test/lib/b.dart', '''
        lib B;
        class F { var f1; f2() { } get f3 => 0; set f4(fx) { } var _pf; }
        class E extends F { var e1; e2() { } }
        class I { int i1; i2() { } }
        class M { var m1; int m2() { } }''');
    addTestSource('''
        import 'b.dart';
        class A extends E implements I with M {a() {^}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // TODO (danrubel) prefer fields over getters
    // If add `get e1;` to interface I
    // then suggestions include getter e1 rather than field e1
    assertNotSuggested('e1');
    assertNotSuggested('f1');
    assertNotSuggested('i1');
    assertNotSuggested('m1');
    assertNotSuggested('f3');
    assertNotSuggested('f4');
    assertNotSuggested('e2');
    assertNotSuggested('f2');
    assertNotSuggested('i2');
    //assertNotSuggested('m2', null, null);
    assertNotSuggested('==');
  }

  Future<void> test_Block_inherited_local() async {
    // Block  BlockFunctionBody  MethodDeclaration  ClassDeclaration
    addTestSource('''
        class F { var f1; f2() { } get f3 => 0; set f4(fx) { } }
        class E extends F { var e1; e2() { } }
        class I { int i1; i2() { } }
        class M { var m1; int m2() { } }
        class A extends E implements I with M {a() {^}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('e1');
    assertNotSuggested('f1');
    assertNotSuggested('i1');
    assertNotSuggested('m1');
    assertNotSuggested('f3');
    assertNotSuggested('f4');
    assertNotSuggested('e2');
    assertNotSuggested('f2');
    assertNotSuggested('i2');
    assertNotSuggested('m2');
  }

  Future<void> test_Block_local_function() async {
    addSource('/home/test/lib/ab.dart', '''
        export "dart:math" hide max;
        class A {int x;}
        @deprecated D1() {int x;}
        class _B {boo() { partBoo() {}} }''');
    addSource('/home/test/lib/cd.dart', '''
        String T1;
        var _T2;
        class C { }
        class D { }''');
    addSource('/home/test/lib/eef.dart', '''
        class EE { }
        class F { }''');
    addSource('/home/test/lib/g.dart', 'class G { }');
    addSource('/home/test/lib/h.dart', '''
        class H { }
        int T3;
        var _T4;'''); // not imported
    addTestSource('''
        import "ab.dart";
        import "cd.dart" hide D;
        import "eef.dart" show EE;
        import "g.dart" as g;
        int T5;
        var _T6;
        String get T7 => 'hello';
        set T8(int value) { partT8() {} }
        Z D2() {int x;}
        class X {
          int get clog => 8;
          set blog(value) { }
          a() {
            var f;
            localF(int arg1) { }
            {var x;}
            p^ var r;
          }
          void b() { }}
        class Z { }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);

    assertNotSuggested('partT8');
    assertNotSuggested('partBoo');
    assertNotSuggested('parseIPv6Address');
    assertNotSuggested('parseHex');
  }

  Future<void> test_Block_partial_results() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addSource('/home/test/lib/ab.dart', '''
        export "dart:math" hide max;
        class A {int x;}
        @deprecated D1() {int x;}
        class _B { }''');
    addSource('/home/test/lib/cd.dart', '''
        String T1;
        var _T2;
        class C { }
        class D { }''');
    addSource('/home/test/lib/eef.dart', '''
        class EE { }
        class F { }''');
    addSource('/home/test/lib/g.dart', 'class G { }');
    addSource('/home/test/lib/h.dart', '''
        class H { }
        int T3;
        var _T4;'''); // not imported
    addTestSource('''
        import 'b.dart';
        import "cd.dart" hide D;
        import "eef.dart" show EE;
        import "g.dart" as g;
        int T5;
        var _T6;
        Z D2() {int x;}
        class X {a() {var f; {var x;} ^ var r;} void b() { }}
        class Z { }''');
    await computeSuggestions();
    assertSuggestClass('C');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('C');
    }
    assertNotSuggested('H');
  }

  Future<void> test_Block_unimported() async {
    newFile('$testPackageLibPath/a.dart', content: 'class A {}');

    addTestSource('void f() { ^ }');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);

    // Not imported, so not suggested
    assertNotSuggested('A');
    assertNotSuggested('Completer');
  }

  Future<void> test_CascadeExpression_selector1() async {
    // PropertyAccess  CascadeExpression  ExpressionStatement  Block
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import 'b.dart';
        class A {var b; X _c;}
        class X{}
        // looks like a cascade to the parser
        // but the user is trying to get completions for a non-cascade
        void f() {A a; a.^.z}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('Object');
    assertNotSuggested('A');
    assertNotSuggested('B');
    assertNotSuggested('X');
    assertNotSuggested('z');
    assertNotSuggested('==');
  }

  Future<void> test_CascadeExpression_selector2() async {
    // SimpleIdentifier  PropertyAccess  CascadeExpression  ExpressionStatement
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import 'b.dart';
        class A {var b; X _c;}
        class X{}
        void f() {A a; a..^z}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 1);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('Object');
    assertNotSuggested('A');
    assertNotSuggested('B');
    assertNotSuggested('X');
    assertNotSuggested('z');
    assertNotSuggested('==');
  }

  Future<void> test_CascadeExpression_selector2_withTrailingReturn() async {
    // PropertyAccess  CascadeExpression  ExpressionStatement  Block
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import 'b.dart';
        class A {var b; X _c;}
        class X{}
        void f() {A a; a..^ return}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('Object');
    assertNotSuggested('A');
    assertNotSuggested('B');
    assertNotSuggested('X');
    assertNotSuggested('z');
    assertNotSuggested('==');
  }

  Future<void> test_CascadeExpression_target() async {
    // SimpleIdentifier  CascadeExpression  ExpressionStatement
    addTestSource('''
        class A {var b; X _c;}
        class X{}
        void f() {A a; a^..b}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('a');
    assertNotSuggested('A');
    assertNotSuggested('X');
    // top level results are partially filtered
    //assertSuggestClass('Object');
    assertNotSuggested('==');
  }

  Future<void> test_CatchClause_onType() async {
    // TypeName  CatchClause  TryStatement
    addTestSource('class A {a() {try{var x;} on ^ {}}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertSuggestClass('Object');
    assertNotSuggested('a');
    assertNotSuggested('x');
  }

  Future<void> test_CatchClause_onType_noBrackets() async {
    // TypeName  CatchClause  TryStatement
    addTestSource('class A {a() {try{var x;} on ^}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertSuggestClass('Object');
    assertNotSuggested('x');
  }

  Future<void> test_CatchClause_typed() async {
    // Block  CatchClause  TryStatement
    addTestSource('class A {a() {try{var x;} on E catch (e) {^}}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('e');
    assertNotSuggested('a');
    assertSuggestClass('Object');
    assertNotSuggested('x');
  }

  Future<void> test_CatchClause_untyped() async {
    // Block  CatchClause  TryStatement
    addTestSource('class A {a() {try{var x;} catch (e, s) {^}}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('e');
    assertNotSuggested('s');
    assertNotSuggested('a');
    assertSuggestClass('Object');
    assertNotSuggested('x');
  }

  Future<void> test_ClassDeclaration_body() async {
    // ClassDeclaration  CompilationUnit
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import "b.dart" as x;
        @deprecated class A {^}
        class _B {}
        A T;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertNotSuggested('_B');
    var suggestionO = assertSuggestClass('Object').element;
    if (suggestionO != null) {
      expect(suggestionO.isDeprecated, isFalse);
      expect(suggestionO.isPrivate, isFalse);
    }
    assertNotSuggested('T');
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('x');
  }

  Future<void> test_ClassDeclaration_body_final() async {
    // ClassDeclaration  CompilationUnit
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import "b.dart" as x;
        class A {final ^}
        class _B {}
        A T;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertNotSuggested('_B');
    assertSuggestClass('Object');
    assertNotSuggested('T');
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('x');
  }

  Future<void> test_ClassDeclaration_body_final_field() async {
    // ClassDeclaration  CompilationUnit
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import "b.dart" as x;
        class A {final ^ A(){}}
        class _B {}
        A T;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertNotSuggested('_B');
    assertSuggestClass('String');
    assertNotSuggested('T');
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('x');
  }

  Future<void> test_ClassDeclaration_body_final_field2() async {
    // ClassDeclaration  CompilationUnit
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import "b.dart" as Soo;
        class A {final S^ A();}
        class _B {}
        A Sew;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('A');
    assertNotSuggested('_B');
    assertSuggestClass('String');
    assertNotSuggested('Sew');
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('Soo');
  }

  Future<void> test_ClassDeclaration_body_final_final() async {
    // ClassDeclaration  CompilationUnit
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import "b.dart" as x;
        class A {final ^ final foo;}
        class _B {}
        A T;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertNotSuggested('_B');
    assertSuggestClass('Object');
    assertNotSuggested('T');
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('x');
  }

  Future<void> test_ClassDeclaration_body_final_var() async {
    // ClassDeclaration  CompilationUnit
    addSource('/home/test/lib/b.dart', '''
        class B { }''');
    addTestSource('''
        import "b.dart" as x;
        class A {final ^ var foo;}
        class _B {}
        A T;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('A');
    assertNotSuggested('_B');
    assertSuggestClass('Object');
    assertNotSuggested('T');
    // Suggested by LibraryPrefixContributor
    assertNotSuggested('x');
  }

  Future<void> test_Combinator_hide() async {
    // SimpleIdentifier  HideCombinator  ImportDirective
    addSource('/home/test/lib/ab.dart', '''
        library libAB;
        part 'partAB.dart';
        class A { }
        class B { }''');
    addSource('/partAB.dart', '''
        part of libAB;
        var T1;
        PB F1() => new PB();
        class PB { }''');
    addSource('/home/test/lib/cd.dart', '''
        class C { }
        class D { }''');
    addTestSource('''
        import "b.dart" hide ^;
        import "cd.dart";
        class X {}''');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_Combinator_show() async {
    // SimpleIdentifier  HideCombinator  ImportDirective
    addSource('/home/test/lib/ab.dart', '''
        library libAB;
        part 'partAB.dart';
        class A { }
        class B { }''');
    addSource('/partAB.dart', '''
        part of libAB;
        var T1;
        PB F1() => new PB();
        typedef PB2 F2(int blat);
        class Clz = Object with Object;
        class PB { }''');
    addSource('/home/test/lib/cd.dart', '''
        class C { }
        class D { }''');
    addTestSource('''
        import "b.dart" show ^;
        import "cd.dart";
        class X {}''');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_ConditionalExpression_elseExpression() async {
    // SimpleIdentifier  ConditionalExpression  ReturnStatement
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        class B {int x;}
        class C {foo(){var f; {var x;} return a ? T1 : T^}}''');

    await computeSuggestions();
    // top level results are partially filtered based on first char
    assertNotSuggested('T2');
    // TODO (danrubel) getter is being suggested instead of top level var
    //assertSuggestImportedTopLevelVar('T1', 'int');
  }

  Future<void> test_ConditionalExpression_elseExpression_empty() async {
    // SimpleIdentifier  ConditionalExpression  ReturnStatement
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        class B {int x;}
        class C {foo(){var f; {var x;} return a ? T1 : ^}}''');

    await computeSuggestions();
    assertNotSuggested('x');
    assertNotSuggested('f');
    assertNotSuggested('foo');
    assertNotSuggested('C');
    assertNotSuggested('F2');
    assertNotSuggested('T2');
    assertSuggestClass('A');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
    assertSuggestFunction('F1', 'dynamic');
    // TODO (danrubel) getter is being suggested instead of top level var
    //assertSuggestImportedTopLevelVar('T1', 'int');
  }

  Future<void> test_ConditionalExpression_partial_thenExpression() async {
    // SimpleIdentifier  ConditionalExpression  ReturnStatement
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        class B {int x;}
        class C {foo(){var f; {var x;} return a ? T^}}''');

    await computeSuggestions();
    // top level results are partially filtered based on first char
    assertNotSuggested('T2');
    // TODO (danrubel) getter is being suggested instead of top level var
    //assertSuggestImportedTopLevelVar('T1', 'int');
  }

  Future<void> test_ConditionalExpression_partial_thenExpression_empty() async {
    // SimpleIdentifier  ConditionalExpression  ReturnStatement
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        class B {int x;}
        class C {foo(){var f; {var x;} return a ? ^}}''');

    await computeSuggestions();
    assertNotSuggested('x');
    assertNotSuggested('f');
    assertNotSuggested('foo');
    assertNotSuggested('C');
    assertNotSuggested('F2');
    assertNotSuggested('T2');
    assertSuggestClass('A');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
    assertSuggestFunction('F1', 'dynamic');
    // TODO (danrubel) getter is being suggested instead of top level var
    //assertSuggestImportedTopLevelVar('T1', 'int');
  }

  Future<void> test_ConditionalExpression_thenExpression() async {
    // SimpleIdentifier  ConditionalExpression  ReturnStatement
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        class B {int x;}
        class C {foo(){var f; {var x;} return a ? T^ : c}}''');

    await computeSuggestions();
    // top level results are partially filtered based on first char
    assertNotSuggested('T2');
    // TODO (danrubel) getter is being suggested instead of top level var
    //assertSuggestImportedTopLevelVar('T1', 'int');
  }

  Future<void> test_ConstructorName_importedClass() async {
    // SimpleIdentifier  PrefixedIdentifier  TypeName  ConstructorName
    // InstanceCreationExpression
    addSource('/home/test/lib/b.dart', '''
        lib B;
        int T1;
        F1() { }
        class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        var m;
        void f() {new X.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by NamedConstructorContributor
    assertNotSuggested('c');
    assertNotSuggested('F1');
    assertNotSuggested('T1');
    assertNotSuggested('_d');
    assertNotSuggested('z');
    assertNotSuggested('m');
  }

  Future<void> test_ConstructorName_importedFactory() async {
    // SimpleIdentifier  PrefixedIdentifier  TypeName  ConstructorName
    // InstanceCreationExpression
    addSource('/home/test/lib/b.dart', '''
        lib B;
        int T1;
        F1() { }
        class X {factory X.c(); factory X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        var m;
        void f() {new X.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by NamedConstructorContributor
    assertNotSuggested('c');
    assertNotSuggested('F1');
    assertNotSuggested('T1');
    assertNotSuggested('_d');
    assertNotSuggested('z');
    assertNotSuggested('m');
  }

  Future<void> test_ConstructorName_importedFactory2() async {
    // SimpleIdentifier  PrefixedIdentifier  TypeName  ConstructorName
    // InstanceCreationExpression
    addTestSource('''
        void f() {new String.fr^omCharCodes([]);}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 2);
    expect(replacementLength, 13);
    // Suggested by NamedConstructorContributor
    assertNotSuggested('fromCharCodes');
    assertNotSuggested('isEmpty');
    assertNotSuggested('isNotEmpty');
    assertNotSuggested('length');
    assertNotSuggested('Object');
    assertNotSuggested('String');
  }

  Future<void> test_ConstructorName_localClass() async {
    // SimpleIdentifier  PrefixedIdentifier  TypeName  ConstructorName
    // InstanceCreationExpression
    addTestSource('''
        int T1;
        F1() { }
        class X {X.c(); X._d(); z() {}}
        void f() {new X.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by NamedConstructorContributor
    assertNotSuggested('c');
    assertNotSuggested('_d');
    assertNotSuggested('F1');
    assertNotSuggested('T1');
    assertNotSuggested('z');
    assertNotSuggested('m');
  }

  Future<void> test_ConstructorName_localFactory() async {
    // SimpleIdentifier  PrefixedIdentifier  TypeName  ConstructorName
    // InstanceCreationExpression
    addTestSource('''
        int T1;
        F1() { }
        class X {factory X.c(); factory X._d(); z() {}}
        void f() {new X.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by NamedConstructorContributor
    assertNotSuggested('c');
    assertNotSuggested('_d');
    assertNotSuggested('F1');
    assertNotSuggested('T1');
    assertNotSuggested('z');
    assertNotSuggested('m');
  }

  Future<void> test_DefaultFormalParameter_named_expression() async {
    // DefaultFormalParameter FormalParameterList MethodDeclaration
    addTestSource('''
        foo() { }
        void bar() { }
        class A {a(blat: ^) { }}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('foo');
    assertNotSuggested('a');
    assertNotSuggested('A');
    assertSuggestClass('String');
    assertSuggestFunction('identical', 'bool');
    assertNotSuggested('bar');
  }

  Future<void> test_doc_class() async {
    addSource('/home/test/lib/a.dart', r'''
library A;
/// My class.
/// Short description.
///
/// Longer description.
class A {}
''');
    addTestSource('import "a.dart"; void f() {^}');

    await computeSuggestions();

    var suggestion = assertSuggestClass('A');
    expect(suggestion.docSummary, 'My class.\nShort description.');
    expect(suggestion.docComplete,
        'My class.\nShort description.\n\nLonger description.');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
  }

  Future<void> test_doc_function() async {
    resolveSource('/home/test/lib/a.dart', r'''
library A;
/// My function.
/// Short description.
///
/// Longer description.
int myFunc() {}
''');
    addTestSource('import "a.dart"; void f() {^}');

    await computeSuggestions();

    var suggestion = assertSuggestFunction('myFunc', 'int');
    expect(suggestion.docSummary, 'My function.\nShort description.');
    expect(suggestion.docComplete,
        'My function.\nShort description.\n\nLonger description.');
  }

  Future<void> test_doc_function_c_style() async {
    resolveSource('/home/test/lib/a.dart', r'''
library A;
/**
 * My function.
 * Short description.
 *
 * Longer description.
 */
int myFunc() {}
''');
    addTestSource('import "a.dart"; void f() {^}');

    await computeSuggestions();

    var suggestion = assertSuggestFunction('myFunc', 'int');
    expect(suggestion.docSummary, 'My function.\nShort description.');
    expect(suggestion.docComplete,
        'My function.\nShort description.\n\nLonger description.');
  }

  Future<void> test_enum() async {
    addSource('/home/test/lib/a.dart', 'library A; enum E { one, two }');
    addTestSource('import "a.dart"; void f() {^}');
    await computeSuggestions();
    assertSuggestEnum('E');
    assertNotSuggested('one');
    assertNotSuggested('two');
  }

  Future<void> test_enum_deprecated() async {
    addSource(
        '/home/test/lib/a.dart', 'library A; @deprecated enum E { one, two }');
    addTestSource('import "a.dart"; void f() {^}');
    await computeSuggestions();
    // TODO(danrube) investigate why suggestion/element is not deprecated
    // when AST node has correct @deprecated annotation
    assertSuggestEnum('E', isDeprecated: true);
    assertNotSuggested('one');
    assertNotSuggested('two');
  }

  Future<void> test_enum_filter() async {
    addSource('/home/test/lib/a.dart', '''
enum E { one, two }
enum F { three, four }
''');
    addTestSource('''
import 'a.dart';

void foo({E e}) {}

void f() {
  foo(e: ^);
}
''');
    await computeSuggestions();

    assertSuggestEnum('E');
    assertSuggestEnumConst('E.one');
    assertSuggestEnumConst('E.two');

    assertSuggestEnum('F');
    assertSuggestEnumConst('F.three');
    assertSuggestEnumConst('F.four');
  }

  Future<void> test_ExpressionStatement_identifier() async {
    // SimpleIdentifier  ExpressionStatement  Block
    resolveSource('/home/test/lib/a.dart', '''
        _B F1() { }
        class A {int x;}
        class _B { }''');
    addTestSource('''
        import 'a.dart';
        typedef int F2(int blat);
        class Clz = Object with Object;
        class C {foo(){^} void bar() {}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('A');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
    assertSuggestFunction('F1', '_B');
    assertNotSuggested('C');
    assertNotSuggested('foo');
    assertNotSuggested('bar');
    assertNotSuggested('F2');
    assertNotSuggested('Clz');
    assertNotSuggested('C');
    assertNotSuggested('x');
    assertNotSuggested('_B');
  }

  Future<void> test_ExpressionStatement_name() async {
    // ExpressionStatement  Block  BlockFunctionBody  MethodDeclaration
    addSource('/home/test/lib/a.dart', '''
        B T1;
        class B{}''');
    addTestSource('''
        import 'a.dart';
        class C {a() {C ^}}''');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_ExtendsClause() async {
    newFile('/home/test/lib/a.dart', content: 'class A {}');
    addTestSource('''
import 'a.dart';

class B extends ^
''');
    await computeSuggestions();
    assertSuggestClass('A');
  }

  Future<void> test_ExtensionDeclaration_extendedType() async {
    newFile('/home/test/lib/a.dart', content: 'class A {}');
    addTestSource('''
import 'a.dart';

extension E on ^
''');
    await computeSuggestions();
    assertSuggestClass('A');
    assertNotSuggested('E');
  }

  Future<void> test_ExtensionDeclaration_extendedType2() async {
    newFile('/home/test/lib/a.dart', content: 'class A {}');
    addTestSource('''
import 'a.dart';

extension E on ^ {}
''');
    await computeSuggestions();
    assertSuggestClass('A');
    assertNotSuggested('E');
  }

  Future<void> test_ExtensionDeclaration_member() async {
    newFile('/home/test/lib/a.dart', content: 'class A {}');
    addTestSource('''
import 'a.dart';

extension E on A { ^ }
''');
    await computeSuggestions();
    assertSuggestClass('A');
  }

  Future<void> test_FieldDeclaration_name_typed() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // FieldDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        class C {A ^}''');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_FieldDeclaration_name_var() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // FieldDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        class C {var ^}''');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_FieldDeclaration_type() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // FieldDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        class C {^ foo;) ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_FieldDeclaration_type_after_comment1() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // FieldDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        class C {
          // comment
          ^ foo;
        } ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_FieldDeclaration_type_after_comment2() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // FieldDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        class C {
          /* comment */
          ^ foo;
        } ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_FieldDeclaration_type_after_comment3() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // FieldDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        class C {
          /// some dartdoc
          ^ foo;
        } ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_FieldDeclaration_type_without_semicolon() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // FieldDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        class C {^ foo} ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_FieldFormalParameter_in_non_constructor() async {
    // SimpleIdentifier  FieldFormalParameter  FormalParameterList
    addTestSource('class A {B(this.^foo) {}}');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 3);
    assertNoSuggestions();
  }

  Future<void> test_ForEachStatement_body_typed() async {
    // Block  ForEachStatement
    addTestSource('void f(args) {for (int foo in bar) {^}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('args');
    assertNotSuggested('foo');
    assertSuggestClass('Object');
  }

  Future<void> test_ForEachStatement_body_untyped() async {
    // Block  ForEachStatement
    addTestSource('void f(args) {for (foo in bar) {^}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('args');
    assertNotSuggested('foo');
    assertSuggestClass('Object');
  }

  Future<void> test_ForEachStatement_iterable() async {
    // SimpleIdentifier  ForEachStatement  Block
    addTestSource('void f(args) {for (int foo in ^) {}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('args');
    assertSuggestClass('Object');
  }

  Future<void> test_ForEachStatement_loopVariable() async {
    // SimpleIdentifier  ForEachStatement  Block
    addTestSource('void f(args) {for (^ in args) {}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('args');
    assertSuggestClass('String');
  }

  Future<void> test_ForEachStatement_loopVariable_type() async {
    // SimpleIdentifier  ForEachStatement  Block
    addTestSource('void f(args) {for (^ foo in args) {}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('args');
    assertNotSuggested('foo');
    assertSuggestClass('String');
  }

  Future<void> test_ForEachStatement_loopVariable_type2() async {
    // DeclaredIdentifier  ForEachStatement  Block
    addTestSource('void f(args) {for (S^ foo in args) {}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('args');
    assertNotSuggested('foo');
    assertSuggestClass('String');
  }

  Future<void> test_FormalParameterList() async {
    // FormalParameterList MethodDeclaration
    addTestSource('''
        foo() { }
        void bar() { }
        class A {a(^) { }}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('foo');
    assertNotSuggested('a');
    assertNotSuggested('A');
    assertSuggestClass('String');
    assertNotSuggested('identical');
    assertNotSuggested('bar');
  }

  Future<void> test_ForStatement_body() async {
    // Block  ForStatement
    addTestSource('void f(args) {for (int i; i < 10; ++i) {^}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('i');
    assertSuggestClass('Object');
  }

  Future<void> test_ForStatement_condition() async {
    // SimpleIdentifier  ForStatement
    addTestSource('void f() {for (int index = 0; i^)}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('index');
  }

  Future<void> test_ForStatement_initializer() async {
    addTestSource('''
import 'dart:math';
void f() {
  List localVar;
  for (^) {}
}
''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('localVar');
    assertNotSuggested('PI');
    assertSuggestClass('Object');
    assertSuggestClass('int');
  }

  Future<void> test_ForStatement_initializer_variableName_afterType() async {
    addTestSource('void f() { for (String ^) }');
    await computeSuggestions();
    assertNotSuggested('int');
  }

  Future<void> test_ForStatement_typing_inKeyword() async {
    addTestSource('void f() { for (var v i^) }');
    await computeSuggestions();
    assertNotSuggested('int');
  }

  Future<void> test_ForStatement_updaters() async {
    // SimpleIdentifier  ForStatement
    addTestSource('void f() {for (int index = 0; index < 10; i^)}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('index');
  }

  Future<void> test_ForStatement_updaters_prefix_expression() async {
    // SimpleIdentifier  PrefixExpression  ForStatement
    addTestSource('''
        void bar() { }
        void f() {for (int index = 0; index < 10; ++i^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertNotSuggested('index');
    assertNotSuggested('f');
    assertNotSuggested('bar');
  }

  Future<void> test_function_parameters_mixed_required_and_named() async {
    resolveSource('/home/test/lib/a.dart', '''
int m(x, {int y}) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'int');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 1);
    expect(suggestion.hasNamedParameters, true);
  }

  Future<void> test_function_parameters_mixed_required_and_positional() async {
    resolveSource('/home/test/lib/a.dart', '''
void m(x, [int y]) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 1);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_function_parameters_named() async {
    resolveSource('/home/test/lib/a.dart', '''
void m({x, int y}) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, true);
  }

  Future<void> test_function_parameters_nnbd_required() async {
    createAnalysisOptionsFile(experiments: [EnableString.non_nullable]);
    resolveSource('/home/test/lib/a.dart', '''
void m(int? nullable, int nonNullable) {}
''');
    addTestSource('''
import 'a.dart';

void f() {^}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'nullable');
    expect(parameterTypes[0], 'int?');
    expect(parameterNames[1], 'nonNullable');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 2);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_function_parameters_nnbd_required_into_legacy() async {
    createAnalysisOptionsFile(experiments: [EnableString.non_nullable]);
    resolveSource('/home/test/lib/a.dart', '''
void m(int? nullable, int nonNullable) {}
''');
    addTestSource('''
// @dart = 2.8
import 'a.dart';

void f() {^}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'nullable');
    expect(parameterTypes[0], 'int');
    expect(parameterNames[1], 'nonNullable');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 2);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_function_parameters_nnbd_required_legacy() async {
    createAnalysisOptionsFile(experiments: [EnableString.non_nullable]);
    resolveSource('/home/test/lib/a.dart', '''
// @dart = 2.8
void m(int param) {}
''');
    addTestSource('''
import 'a.dart';

void f() {^}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(1));
    expect(parameterNames[0], 'param');
    expect(parameterTypes[0], 'int*');
    expect(suggestion.requiredParameterCount, 1);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_function_parameters_none() async {
    resolveSource('/home/test/lib/a.dart', '''
void m() {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');

    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    expect(suggestion.parameterNames, isEmpty);
    expect(suggestion.parameterTypes, isEmpty);
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_function_parameters_positional() async {
    resolveSource('/home/test/lib/a.dart', '''
void m([x, int y]) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_function_parameters_required() async {
    resolveSource('/home/test/lib/a.dart', '''
void m(x, int y) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 2);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_FunctionDeclaration_returnType_afterComment() async {
    // ClassDeclaration  CompilationUnit
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 { }
        /* */ ^ zoo(z) { } String name;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('T1');
    assertNotSuggested('F1');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_FunctionDeclaration_returnType_afterComment2() async {
    // FunctionDeclaration  ClassDeclaration  CompilationUnit
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 { }
        /** */ ^ zoo(z) { } String name;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('T1');
    assertNotSuggested('F1');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_FunctionDeclaration_returnType_afterComment3() async {
    // FunctionDeclaration  ClassDeclaration  CompilationUnit
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        /// some dartdoc
        class C2 { }
        ^ zoo(z) { } String name;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('T1');
    assertNotSuggested('F1');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_FunctionExpression_body_function() async {
    // Block  BlockFunctionBody  FunctionExpression
    addTestSource('''
        void bar() { }
        String foo(List args) {x.then((R b) {^});}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('foo');
    assertNotSuggested('bar');
    assertNotSuggested('args');
    assertNotSuggested('b');
    assertSuggestClass('Object');
  }

  Future<void> test_functionTypeAlias_genericTypeAlias() async {
    addSource('/home/test/lib/a.dart', r'''
typedef F = void Function();
''');
    addTestSource(r'''
import 'a.dart';

void f() {
  ^
}
''');
    await computeSuggestions();
    assertSuggestTypeAlias('F',
        aliasedType: 'void Function()', returnType: 'void');
  }

  Future<void> test_functionTypeAlias_old() async {
    addSource('/home/test/lib/a.dart', r'''
typedef void F();
''');
    addTestSource(r'''
import 'a.dart';

void f() {
  ^
}
''');
    await computeSuggestions();
    assertSuggestTypeAlias('F',
        aliasedType: 'void Function()', returnType: 'void');
  }

  Future<void> test_IfStatement() async {
    // SimpleIdentifier  IfStatement
    addTestSource('''
        class A {var b; X _c; foo() {A a; if (true) ^}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertSuggestClass('Object');
    assertNotSuggested('A');
    assertNotSuggested('==');
  }

  Future<void> test_IfStatement_condition() async {
    // SimpleIdentifier  IfStatement  Block  BlockFunctionBody
    addTestSource('''
        class A {int x; int y() => 0;}
        void f(){var a; if (^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertNotSuggested('A');
    assertSuggestClass('Object');
  }

  Future<void> test_IfStatement_empty() async {
    // SimpleIdentifier  IfStatement
    addTestSource('''
        class A {var b; X _c; foo() {A a; if (^) something}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertSuggestClass('Object');
    assertNotSuggested('A');
    assertNotSuggested('==');
  }

  Future<void> test_IfStatement_invocation() async {
    // SimpleIdentifier  PrefixIdentifier  IfStatement
    addTestSource('''
        void f() {var a; if (a.^) something}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('toString');
    assertNotSuggested('Object');
    assertNotSuggested('A');
    assertNotSuggested('==');
  }

  Future<void> test_IfStatement_typing_isKeyword() async {
    addTestSource('void f() { if (v i^) }');
    await computeSuggestions();
    assertNotSuggested('int');
  }

  Future<void> test_implementsClause() async {
    newFile('/home/test/lib/a.dart', content: 'class A {}');
    addTestSource('''
import 'a.dart';

class B implements ^
''');
    await computeSuggestions();
    assertSuggestClass('A');
  }

  Future<void> test_implicitCreation() async {
    addSource('/home/test/lib/a.dart', '''
class A {
  A.a1();
  A.a2();
}
class B {
  B.b1();
  B.b2();
}
''');
    addTestSource('''
import 'a.dart';

void f() {
  ^;
}
''');
    await computeSuggestions();

    assertSuggestClass('A');
    assertSuggestConstructor('A.a1');
    assertSuggestConstructor('A.a2');

    assertSuggestClass('B');
    assertSuggestConstructor('B.b1');
    assertSuggestConstructor('B.b2');
  }

  Future<void> test_ImportDirective_dart() async {
    // SimpleStringLiteral  ImportDirective
    addTestSource('''
        import "dart^";
        void f() {}''');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_IndexExpression() async {
    // ExpressionStatement  Block
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        class B {int x;}
        class C {foo(){var f; {var x;} f[^]}}''');

    await computeSuggestions();
    assertNotSuggested('x');
    assertNotSuggested('f');
    assertNotSuggested('foo');
    assertNotSuggested('C');
    assertNotSuggested('F2');
    assertNotSuggested('T2');
    assertSuggestClass('A');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
    assertSuggestFunction('F1', 'dynamic');
    // TODO (danrubel) getter is being suggested instead of top level var
    //assertSuggestImportedTopLevelVar('T1', 'int');
  }

  Future<void> test_IndexExpression2() async {
    // SimpleIdentifier IndexExpression ExpressionStatement  Block
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        class B {int x;}
        class C {foo(){var f; {var x;} f[T^]}}''');

    await computeSuggestions();
    // top level results are partially filtered based on first char
    assertNotSuggested('T2');
    // TODO (danrubel) getter is being suggested instead of top level var
    //assertSuggestImportedTopLevelVar('T1', 'int');
  }

  Future<void> test_InstanceCreationExpression() async {
    resolveSource('/home/test/lib/a.dart', '''
class A {foo(){var f; {var x;}}}
class B {B(this.x, [String boo]) { } int x;}
class C {C.bar({boo: 'hoo', int z: 0}) { } }''');
    addTestSource('''
import 'a.dart';
import "dart:math" as math;
void f() {new ^ String x = "hello";}''');

    await computeSuggestions();
    CompletionSuggestion suggestion;

    suggestion = assertSuggestConstructor('Object');
    expect(suggestion.element!.parameters, '()');
    expect(suggestion.parameterNames, hasLength(0));
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, false);

    suggestion = assertSuggestConstructor('A');
    expect(suggestion.element!.parameters, '()');
    expect(suggestion.parameterNames, hasLength(0));
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, false);

    suggestion = assertSuggestConstructor('B');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(suggestion.element!.parameters, '(int x, [String boo])');
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'int');
    expect(parameterNames[1], 'boo');
    expect(parameterTypes[1], 'String');
    expect(suggestion.requiredParameterCount, 1);
    expect(suggestion.hasNamedParameters, false);

    suggestion = assertSuggestConstructor('C.bar');
    parameterNames = suggestion.parameterNames!;
    parameterTypes = suggestion.parameterTypes!;
    expect(
        suggestion.element!.parameters, "({dynamic boo = 'hoo', int z = 0})");
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'boo');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'z');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, true);

    // Suggested by LibraryPrefixContributor
    assertNotSuggested('math');
  }

  Future<void> test_InstanceCreationExpression_abstractClass() async {
    addSource('/home/test/lib/a.dart', '''
abstract class A {
  A();
  A.generative();
  factory A.factory() => A();
}
''');
    addTestSource('''
import 'a.dart';

void f() {
  new ^;
}
''');
    await computeSuggestions();

    assertNotSuggested('A');
    assertNotSuggested('A.generative');
    assertSuggestConstructor('A.factory');
  }

  Future<void>
      test_InstanceCreationExpression_abstractClass_implicitConstructor() async {
    addSource('/home/test/lib/a.dart', '''
abstract class A {}
''');
    addTestSource('''
import 'a.dart';

void f() {
  new ^;
}
''');
    await computeSuggestions();

    assertNotSuggested('A');
  }

  Future<void> test_InstanceCreationExpression_filter() async {
    addSource('/home/test/lib/a.dart', '''
class A {}
class B extends A {}
class C implements A {}
class D {}
''');
    addTestSource('''
import 'a.dart';

void f() {
  A a = new ^
}
''');
    await computeSuggestions();

    assertSuggestConstructor('A', elemOffset: -1);
    assertSuggestConstructor('B', elemOffset: -1);
    assertSuggestConstructor('C', elemOffset: -1);
    assertSuggestConstructor('D', elemOffset: -1);
  }

  Future<void> test_InstanceCreationExpression_imported() async {
    // SimpleIdentifier  TypeName  ConstructorName  InstanceCreationExpression
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        class A {A(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        import "dart:async";
        int T2;
        F2() { }
        class B {B(this.x, [String boo]) { } int x;}
        class C {foo(){var f; {var x;} new ^}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestConstructor('Object');
    // Exported by dart:core and dart:async
    assertSuggestConstructor('Future');
    assertSuggestConstructor('Future.delayed');
    assertSuggestConstructor('Future.microtask');
    assertSuggestConstructor('Future.value');
    assertSuggestConstructor('Stream.fromIterable');
    // ...
    assertSuggestConstructor('A');
    // Suggested by ConstructorContributor
    assertNotSuggested('B');
    assertNotSuggested('C');
    assertNotSuggested('f');
    assertNotSuggested('x');
    assertNotSuggested('foo');
    assertNotSuggested('F1');
    assertNotSuggested('F2');
    // An unresolved imported library will produce suggestions
    // with a null returnType
    // The current DartCompletionRequest#resolveExpression resolves
    // the world (which it should not) and causes the imported library
    // to be resolved.
    assertNotSuggested('T1');
    assertNotSuggested('T2');
  }

  Future<void> test_InstanceCreationExpression_unimported() async {
    // SimpleIdentifier  TypeName  ConstructorName  InstanceCreationExpression
    addSource('/home/test/lib/ab.dart', 'class Clip { }');
    addTestSource('class A {foo(){new C^}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    // Not imported, so not suggested
    assertNotSuggested('Completer');
    assertNotSuggested('Clip');
  }

  Future<void> test_internal_sdk_libs() async {
    addTestSource('void f() {p^}');

    await computeSuggestions();
    assertSuggest('print');
    // Not imported, so not suggested
    assertNotSuggested('pow');
    // Do not suggest completions from internal SDK library
    assertNotSuggested('printToConsole');
  }

  Future<void> test_InterpolationExpression() async {
    // SimpleIdentifier  InterpolationExpression  StringInterpolation
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 { }
        void f() {String name; print("hello \$^");}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('Object');
      assertSuggestConstructor('C1');
    } else {
      assertNotSuggested('Object');
      assertNotSuggested('C1');
    }
    assertSuggestTopLevelVar('T1', null);
    assertSuggestFunction('F1', null);
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_InterpolationExpression_block() async {
    // SimpleIdentifier  InterpolationExpression  StringInterpolation
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 { }
        void f() {String name; print("hello \${^}");}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    // Simulate unresolved imported library
    // in which case suggestions will have null (unresolved) returnType
    assertSuggestTopLevelVar('T1', null);
    assertSuggestFunction('F1', null);
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_InterpolationExpression_block2() async {
    // SimpleIdentifier  InterpolationExpression  StringInterpolation
    addTestSource('void f() {String name; print("hello \${n^}");}');

    await computeSuggestions();
    assertNotSuggested('name');
    // top level results are partially filtered
    //assertSuggestClass('Object');
  }

  Future<void> test_InterpolationExpression_prefix_selector() async {
    // SimpleIdentifier  PrefixedIdentifier  InterpolationExpression
    addTestSource('void f() {String name; print("hello \${name.^}");}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('length');
    assertNotSuggested('name');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_InterpolationExpression_prefix_selector2() async {
    // SimpleIdentifier  PrefixedIdentifier  InterpolationExpression
    addTestSource('void f() {String name; print("hello \$name.^");}');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_InterpolationExpression_prefix_target() async {
    // SimpleIdentifier  PrefixedIdentifier  InterpolationExpression
    addTestSource('void f() {String name; print("hello \${nam^e.length}");}');

    await computeSuggestions();
    assertNotSuggested('name');
    // top level results are partially filtered
    //assertSuggestClass('Object');
    assertNotSuggested('length');
  }

  Future<void> test_IsExpression() async {
    // SimpleIdentifier  TypeName  IsExpression  IfStatement
    addSource('/home/test/lib/b.dart', '''
        lib B;
        foo() { }
        class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        class Y {Y.c(); Y._d(); z() {}}
        void f() {var x; if (x is ^) { }}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('X');
    assertNotSuggested('Y');
    assertNotSuggested('x');
    assertNotSuggested('f');
    assertNotSuggested('foo');
  }

  Future<void> test_IsExpression_target() async {
    // IfStatement  Block  BlockFunctionBody
    addTestSource('''
        foo() { }
        void bar() { }
        class A {int x; int y() => 0;}
        void f(){var a; if (^ is A)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertNotSuggested('foo');
    assertNotSuggested('bar');
    assertNotSuggested('A');
    assertSuggestClass('Object');
  }

  Future<void> test_IsExpression_type() async {
    // SimpleIdentifier  TypeName  IsExpression  IfStatement
    addTestSource('''
        class A {int x; int y() => 0;}
        void f(){var a; if (a is ^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertNotSuggested('A');
    assertSuggestClass('Object');
  }

  Future<void> test_IsExpression_type_partial() async {
    // SimpleIdentifier  TypeName  IsExpression  IfStatement
    addTestSource('''
        class A {int x; int y() => 0;}
        void f(){var a; if (a is Obj^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 3);
    expect(replacementLength, 3);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertNotSuggested('A');
    assertSuggestClass('Object');
  }

  @failingTest
  Future<void> test_IsExpression_type_subtype_extends_filter() async {
    // This test fails because we are not filtering out the class `A` when
    // suggesting types. We ought to do so because there's no reason to cast a
    // value to the type it already has.

    // SimpleIdentifier  TypeName  IsExpression  IfStatement
    addSource('/home/test/lib/b.dart', '''
        foo() { }
        class A {} class B extends A {} class C extends B {}
        class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        void f(){A a; if (a is ^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('B');
    assertSuggestClass('C');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('a');
    assertNotSuggested('f');
  }

  @failingTest
  Future<void> test_IsExpression_type_subtype_implements_filter() async {
    // This test fails because we are not filtering out the class `A` when
    // suggesting types. We ought to do so because there's no reason to cast a
    // value to the type it already has.

    // SimpleIdentifier  TypeName  IsExpression  IfStatement
    addSource('/home/test/lib/b.dart', '''
        foo() { }
        class A {} class B implements A {} class C implements B {}
        class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        void f(){A a; if (a is ^)}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('B');
    assertSuggestClass('C');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('a');
    assertNotSuggested('f');
  }

  Future<void> test_keyword() async {
    resolveSource('/home/test/lib/b.dart', '''
        lib B;
        int newT1;
        int T1;
        nowIsIt() { }
        class X {factory X.c(); factory X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        String newer() {}
        var m;
        void f() {new^ X.c();}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 3);
    expect(replacementLength, 3);
    assertNotSuggested('c');
    assertNotSuggested('_d');
    // Imported suggestion are filtered by 1st character
    assertSuggestFunction('nowIsIt', 'dynamic');
    assertSuggestTopLevelVar('T1', 'int');
    assertSuggestTopLevelVar('newT1', 'int');
    assertNotSuggested('z');
    assertNotSuggested('m');
    assertNotSuggested('newer');
  }

  Future<void> test_Literal_list() async {
    // ']'  ListLiteral  ArgumentList  MethodInvocation
    addTestSource('void f() {var Some; print([^]);}');

    await computeSuggestions();
    assertNotSuggested('Some');
    assertSuggestClass('String');
  }

  Future<void> test_Literal_list2() async {
    // SimpleIdentifier ListLiteral  ArgumentList  MethodInvocation
    addTestSource('void f() {var Some; print([S^]);}');

    await computeSuggestions();
    assertNotSuggested('Some');
    assertSuggestClass('String');
  }

  Future<void> test_Literal_string() async {
    // SimpleStringLiteral  ExpressionStatement  Block
    addTestSource('class A {a() {"hel^lo"}}');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_localVariableDeclarationName() async {
    addTestSource('void f() {String m^}');
    await computeSuggestions();
    assertNotSuggested('f');
    assertNotSuggested('min');
  }

  Future<void> test_MapLiteralEntry() async {
    // MapLiteralEntry  MapLiteral  VariableDeclaration
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 { }
        foo = {^''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('Object');
    }
    // Simulate unresolved imported library,
    // in which case suggestions will have null return types (unresolved)
    // The current DartCompletionRequest#resolveExpression resolves
    // the world (which it should not) and causes the imported library
    // to be resolved.
    assertSuggestTopLevelVar('T1', /* null */ 'int');
    assertSuggestFunction('F1', /* null */ 'dynamic');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
  }

  Future<void> test_MapLiteralEntry1() async {
    // MapLiteralEntry  MapLiteral  VariableDeclaration
    addSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 { }
        foo = {T^''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    // Simulate unresolved imported library,
    // in which case suggestions will have null return types (unresolved)
    // The current DartCompletionRequest#resolveExpression resolves
    // the world (which it should not) and causes the imported library
    // to be resolved.
    assertSuggestTopLevelVar('T1', /* null */ 'int');
    assertNotSuggested('T2');
  }

  Future<void> test_MapLiteralEntry2() async {
    // SimpleIdentifier  MapLiteralEntry  MapLiteral  VariableDeclaration
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 { }
        foo = {7:T^};''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestTopLevelVar('T1', 'int');
    assertNotSuggested('T2');
  }

  Future<void> test_method_parameters_mixed_required_and_named() async {
    resolveSource('/home/test/lib/a.dart', '''
void m(x, {int y}) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 1);
    expect(suggestion.hasNamedParameters, true);
  }

  Future<void> test_method_parameters_mixed_required_and_positional() async {
    resolveSource('/home/test/lib/a.dart', '''
void m(x, [int y]) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 1);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_method_parameters_named() async {
    resolveSource('/home/test/lib/a.dart', '''
void m({x, int y}) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, true);
  }

  Future<void> test_method_parameters_none() async {
    resolveSource('/home/test/lib/a.dart', '''
void m() {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');

    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    expect(suggestion.parameterNames, isEmpty);
    expect(suggestion.parameterTypes, isEmpty);
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_method_parameters_positional() async {
    resolveSource('/home/test/lib/a.dart', '''
void m([x, int y]) {}
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 0);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_method_parameters_required() async {
    resolveSource('/home/test/lib/a.dart', '''
void m(x, int y) {}
''');
    addTestSource('''
import 'a.dart';
class B {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestFunction('m', 'void');
    var parameterNames = suggestion.parameterNames!;
    var parameterTypes = suggestion.parameterTypes!;
    expect(parameterNames, hasLength(2));
    expect(parameterNames[0], 'x');
    expect(parameterTypes[0], 'dynamic');
    expect(parameterNames[1], 'y');
    expect(parameterTypes[1], 'int');
    expect(suggestion.requiredParameterCount, 2);
    expect(suggestion.hasNamedParameters, false);
  }

  Future<void> test_MethodDeclaration_body_getters() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addTestSource('class A {@deprecated X get f => 0; Z a() {^} get _g => 1;}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('f');
    assertNotSuggested('_g');
  }

  Future<void> test_MethodDeclaration_body_static() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addSource('/home/test/lib/c.dart', '''
        class C {
          c1() {}
          var c2;
          static c3() {}
          static var c4;}''');
    addTestSource('''
        import "c.dart";
        class B extends C {
          b1() {}
          var b2;
          static b3() {}
          static var b4;}
        class A extends B {
          a1() {}
          var a2;
          static a3() {}
          static var a4;
          static a() {^}}''');

    await computeSuggestions();
    assertNotSuggested('a1');
    assertNotSuggested('a2');
    assertNotSuggested('a3');
    assertNotSuggested('a4');
    assertNotSuggested('b1');
    assertNotSuggested('b2');
    assertNotSuggested('b3');
    assertNotSuggested('b4');
    assertNotSuggested('c1');
    assertNotSuggested('c2');
    assertNotSuggested('c3');
    assertNotSuggested('c4');
  }

  Future<void> test_MethodDeclaration_members() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addTestSource('class A {@deprecated X f; Z _a() {^} var _g;}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('_a');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertSuggestClass('bool');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('List.filled');
    }
  }

  Future<void> test_MethodDeclaration_parameters_named() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addTestSource('class A {@deprecated Z a(X x, _, b, {y: boo}) {^}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('a');
    assertNotSuggested('x');
    assertNotSuggested('y');
    assertNotSuggested('b');
    assertSuggestClass('int');
    assertNotSuggested('_');
  }

  Future<void> test_MethodDeclaration_parameters_positional() async {
    // Block  BlockFunctionBody  MethodDeclaration
    addTestSource('''
        foo() { }
        void bar() { }
        class A {Z a(X x, [int y=1]) {^}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('foo');
    assertNotSuggested('bar');
    assertNotSuggested('a');
    assertNotSuggested('x');
    assertNotSuggested('y');
    assertSuggestClass('String');
  }

  Future<void> test_MethodDeclaration_returnType() async {
    // ClassDeclaration  CompilationUnit
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 {^ zoo(z) { } String name; }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('T1');
    assertNotSuggested('F1');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_MethodDeclaration_returnType_afterComment() async {
    // ClassDeclaration  CompilationUnit
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 {/* */ ^ zoo(z) { } String name; }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('T1');
    assertNotSuggested('F1');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_MethodDeclaration_returnType_afterComment2() async {
    // MethodDeclaration  ClassDeclaration  CompilationUnit
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 {/** */ ^ zoo(z) { } String name; }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('T1');
    assertNotSuggested('F1');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_MethodDeclaration_returnType_afterComment3() async {
    // MethodDeclaration  ClassDeclaration  CompilationUnit
    resolveSource('/home/test/lib/a.dart', '''
        int T1;
        F1() { }
        typedef D1();
        class C1 {C1(this.x) { } int x;}''');
    addTestSource('''
        import 'a.dart';
        int T2;
        F2() { }
        typedef D2();
        class C2 {
          /// some dartdoc
          ^ zoo(z) { } String name; }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('T1');
    assertNotSuggested('F1');
    assertSuggestTypeAlias('D1',
        aliasedType: 'dynamic Function()', returnType: 'dynamic');
    assertSuggestClass('C1');
    assertNotSuggested('T2');
    assertNotSuggested('F2');
    assertNotSuggested('D2');
    assertNotSuggested('C2');
    assertNotSuggested('name');
  }

  Future<void> test_MethodInvocation_no_semicolon() async {
    // MethodInvocation  ExpressionStatement  Block
    addTestSource('''
        void f() { }
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          var b; X _c;
          X get d => new A();get _e => new A();
          // no semicolon between completion point and next statement
          set s1(I x) {} set _s2(I x) {x.^ m(null);}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('a');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_MethodTypeArgumentList() async {
    addSource('/home/test/lib/a.dart', '''
class A {}
class B {}
''');
    addTestSource('''
import 'a.dart';
void f<S>() { }

void g() {
    f<^>();
}
''');

    await computeSuggestions();

    assertSuggestClass('A');
    assertSuggestClass('B');
    assertSuggestClass('Object');
    assertSuggestClass('bool');
    // etc.
    assertNotSuggested('f');
  }

  Future<void> test_MethodTypeArgumentList_2() async {
    addTestSource('''
void f<S,T>() { }

void g() {
    f<String, ^>();
}
''');

    await computeSuggestions();

    assertSuggestClass('Object');
    assertSuggestClass('bool');
    // etc.
    assertNotSuggested('f');
  }

  Future<void> test_mixin_ordering() async {
    addSource('/home/test/lib/a.dart', '''
class B {}
class M1 {
  void m() {}
}
class M2 {
  void m() {}
}
''');
    addTestSource('''
import 'a.dart';
class C extends B with M1, M2 {
  void f() {
    ^
  }
}
''');
    await computeSuggestions();
    assertNotSuggested('m');
  }

  Future<void> test_new_instance() async {
    addTestSource('import "dart:math"; class A {x() {new Random().^}}');

    await computeSuggestions();
    assertNotSuggested('nextBool');
    assertNotSuggested('nextDouble');
    assertNotSuggested('nextInt');
    assertNotSuggested('Random');
    assertNotSuggested('Object');
    assertNotSuggested('A');
  }

  Future<void> test_no_parameters_field() async {
    addSource('/home/test/lib/a.dart', '''
int x;
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestTopLevelVar('x', null);
    assertHasNoParameterInfo(suggestion);
  }

  Future<void> test_no_parameters_getter() async {
    resolveSource('/home/test/lib/a.dart', '''
int get x => null;
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestGetter('x', 'int');
    assertHasNoParameterInfo(suggestion);
  }

  Future<void> test_no_parameters_setter() async {
    addSource('/home/test/lib/a.dart', '''
set x(int value) {};
''');
    addTestSource('''
import 'a.dart';
class B extends A {
  void f() {^}
}
''');
    await computeSuggestions();
    var suggestion = assertSuggestSetter('x');
    assertHasNoParameterInfo(suggestion);
  }

  Future<void> test_parameterName_excludeTypes() async {
    addTestSource('m(int ^) {}');
    await computeSuggestions();
    assertNotSuggested('int');
    assertNotSuggested('bool');
  }

  Future<void> test_partFile_TypeName() async {
    // SimpleIdentifier  TypeName  ConstructorName
    addSource('$testPackageLibPath/b.dart', '''
        lib B;
        int T1;
        F1() { }
        class X {X.c(); X._d(); z() {}}''');
    addSource('$testPackageLibPath/a.dart', '''
        library libA;
        import 'b.dart';
        part "test.dart";
        class A { }
        var m;''');
    addTestSource('''
        part of libA;
        class B { B.bar(int x); }
        void f() {new ^}''');

    await resolveFile('$testPackageLibPath/a.dart');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by ConstructorContributor
    assertNotSuggested('B.bar');
    assertSuggestConstructor('Object');
    assertSuggestConstructor('X.c');
    assertNotSuggested('X._d');
    // Suggested by LocalLibraryContributor
    assertNotSuggested('A');
    assertNotSuggested('F1');
    assertNotSuggested('T1');
    assertNotSuggested('_d');
    assertNotSuggested('z');
    assertNotSuggested('m');
  }

  Future<void> test_partFile_TypeName2() async {
    // SimpleIdentifier  TypeName  ConstructorName
    addSource('/home/test/lib/b.dart', '''
        lib libB;
        int T1;
        F1() { }
        class X {X.c(); X._d(); z() {}}''');
    addSource('/home/test/lib/a.dart', '''
        part of libA;
        class B { }''');
    addTestSource('''
        library libA;
        import 'b.dart';
        part "a.dart";
        class A { A({String boo: 'hoo'}) { } }
        void f() {new ^}
        var m;''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by ConstructorContributor
    assertNotSuggested('A');
    assertSuggestConstructor('Object');
    assertSuggestConstructor('X.c');
    assertNotSuggested('X._d');
    // Suggested by LocalLibraryContributor
    assertNotSuggested('B');
    assertNotSuggested('F1');
    assertNotSuggested('T1');
    assertNotSuggested('_d');
    assertNotSuggested('z');
    assertNotSuggested('m');
  }

  Future<void> test_PrefixedIdentifier_class_const() async {
    // SimpleIdentifier PrefixedIdentifier ExpressionStatement Block
    addSource('/home/test/lib/b.dart', '''
        lib B;
        class I {
          static const scI = 'boo';
          X get f => new A();
          get _g => new A();}
        class B implements I {
          static const int scB = 12;
          var b; X _c;
          X get d => new A();get _e => new A();
          set s1(I x) {} set _s2(I x) {}
          m(X x) {} I _n(X x) {}}
        class X{}''');
    addTestSource('''
        import 'b.dart';
        class A extends B {
          static const String scA = 'foo';
          w() { }}
        void f() {A.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by StaticMemberContributor
    assertNotSuggested('scA');
    assertNotSuggested('scB');
    assertNotSuggested('scI');
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('a');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('w');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_PrefixedIdentifier_class_imported() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addSource('/home/test/lib/b.dart', '''
        lib B;
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          static const int sc = 12;
          @deprecated var b; X _c;
          X get d => new A();get _e => new A();
          set s1(I x) {} set _s2(I x) {}
          m(X x) {} I _n(X x) {}}
        class X{}''');
    addTestSource('''
        import 'b.dart';
        void f() {A a; a.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('sc');
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('a');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_PrefixedIdentifier_class_local() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('''
        void f() {A a; a.^}
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          static const int sc = 12;
          var b; X _c;
          X get d => new A();get _e => new A();
          set s1(I x) {} set _s2(I x) {}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('sc');
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('a');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_PrefixedIdentifier_getter() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('String get g => "one"; f() {g.^}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_library() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addSource('/home/test/lib/b.dart', '''
        lib B;
        var T1;
        class X { }
        class Y { }''');
    addTestSource('''
        import "b.dart" as b;
        var T2;
        class A { }
        void f() {b.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by LibraryMemberContributor
    assertNotSuggested('X');
    assertNotSuggested('Y');
    assertNotSuggested('T1');
    assertNotSuggested('T2');
    assertNotSuggested('Object');
    assertNotSuggested('b');
    assertNotSuggested('A');
    assertNotSuggested('==');
  }

  Future<void> test_PrefixedIdentifier_library_typesOnly() async {
    // SimpleIdentifier  PrefixedIdentifier  TypeName
    addSource('/home/test/lib/b.dart', '''
        lib B;
        var T1;
        class X { }
        class Y { }''');
    addTestSource('''
        import "b.dart" as b;
        var T2;
        class A { }
        foo(b.^ f) {}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by LibraryMemberContributor
    assertNotSuggested('X');
    assertNotSuggested('Y');
    assertNotSuggested('T1');
    assertNotSuggested('T2');
    assertNotSuggested('Object');
    assertNotSuggested('b');
    assertNotSuggested('A');
    assertNotSuggested('==');
  }

  Future<void> test_PrefixedIdentifier_library_typesOnly2() async {
    // SimpleIdentifier  PrefixedIdentifier  TypeName
    addSource('/home/test/lib/b.dart', '''
        lib B;
        var T1;
        class X { }
        class Y { }''');
    addTestSource('''
        import "b.dart" as b;
        var T2;
        class A { }
        foo(b.^) {}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Suggested by LibraryMemberContributor
    assertNotSuggested('X');
    assertNotSuggested('Y');
    assertNotSuggested('T1');
    assertNotSuggested('T2');
    assertNotSuggested('Object');
    assertNotSuggested('b');
    assertNotSuggested('A');
    assertNotSuggested('==');
  }

  Future<void> test_PrefixedIdentifier_parameter() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addSource('/home/test/lib/b.dart', '''
        lib B;
        class _W {M y; var _z;}
        class X extends _W {}
        class M{}''');
    addTestSource('''
        import 'b.dart';
        foo(X x) {x.^}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('y');
    assertNotSuggested('_z');
    assertNotSuggested('==');
  }

  Future<void> test_PrefixedIdentifier_prefix() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addSource('/home/test/lib/a.dart', '''
        class A {static int bar = 10;}
        _B() {}''');
    addTestSource('''
        import 'a.dart';
        class X {foo(){A^.bar}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClass('A');
    if (suggestConstructorsWithoutNew) {
      assertSuggestConstructor('A');
    }
    assertNotSuggested('X');
    assertNotSuggested('foo');
    assertNotSuggested('bar');
    assertNotSuggested('_B');
  }

  Future<void> test_PrefixedIdentifier_propertyAccess() async {
    // PrefixedIdentifier  ExpressionStatement  Block  BlockFunctionBody
    addTestSource('class A {String x; int get foo {x.^}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('isEmpty');
    assertNotSuggested('compareTo');
  }

  Future<void> test_PrefixedIdentifier_propertyAccess_newStmt() async {
    // PrefixedIdentifier  ExpressionStatement  Block  BlockFunctionBody
    addTestSource('class A {String x; int get foo {x.^ int y = 0;}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('isEmpty');
    assertNotSuggested('compareTo');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_const() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('const String g = "hello"; f() {g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_field() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('class A {String g; f() {g.^ int y = 0;}}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_function() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('String g() => "one"; f() {g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_functionTypeAlias() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('typedef String g(); f() {g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_getter() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('String get g => "one"; f() {g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_local_typed() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('f() {String g; g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_local_untyped() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('f() {var g = "hello"; g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_method() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('class A {String g() {}; f() {g.^ int y = 0;}}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_param() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('class A {f(String g) {g.^ int y = 0;}}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_param2() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('f(String g) {g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PrefixedIdentifier_trailingStmt_topLevelVar() async {
    // SimpleIdentifier  PrefixedIdentifier  ExpressionStatement
    addTestSource('String g; f() {g.^ int y = 0;}');

    await computeSuggestions();
    assertNotSuggested('length');
  }

  Future<void> test_PropertyAccess_expression() async {
    // SimpleIdentifier  MethodInvocation  PropertyAccess  ExpressionStatement
    addTestSource('class A {a() {"hello".to^String().length}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 2);
    expect(replacementLength, 8);
    assertNotSuggested('length');
    assertNotSuggested('A');
    assertNotSuggested('a');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_PropertyAccess_noTarget() async {
    // SimpleIdentifier  PropertyAccess  ExpressionStatement
    addSource('/home/test/lib/ab.dart', 'class Foo { }');
    addTestSource('class C {foo(){.^}}');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_PropertyAccess_noTarget2() async {
    // SimpleIdentifier  PropertyAccess  ExpressionStatement
    addSource('/home/test/lib/ab.dart', 'class Foo { }');
    addTestSource('void f() {.^}');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_PropertyAccess_selector() async {
    // SimpleIdentifier  PropertyAccess  ExpressionStatement  Block
    addTestSource('class A {a() {"hello".length.^}}');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('isEven');
    assertNotSuggested('A');
    assertNotSuggested('a');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_SwitchStatement_c() async {
    // SwitchStatement  Block  BlockFunctionBody  MethodDeclaration
    addTestSource('class A {String g(int x) {switch(x) {c^}}}');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_SwitchStatement_case() async {
    // SwitchStatement  Block  BlockFunctionBody  MethodDeclaration
    addTestSource('class A {String g(int x) {var t; switch(x) {case 0: ^}}}');

    await computeSuggestions();
    assertNotSuggested('A');
    assertNotSuggested('g');
    assertNotSuggested('t');
    assertSuggestClass('String');
  }

  Future<void> test_SwitchStatement_empty() async {
    // SwitchStatement  Block  BlockFunctionBody  MethodDeclaration
    addTestSource('class A {String g(int x) {switch(x) {^}}}');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_ThisExpression_block() async {
    // MethodInvocation  ExpressionStatement  Block
    addTestSource('''
        void f() { }
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          A() {}
          A.z() {}
          var b; X _c;
          X get d => new A();get _e => new A();
          // no semicolon between completion point and next statement
          set s1(I x) {} set _s2(I x) {this.^ m(null);}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('z');
    assertNotSuggested('I');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_ThisExpression_constructor() async {
    // MethodInvocation  ExpressionStatement  Block
    addTestSource('''
        void f() { }
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          A() {this.^}
          A.z() {}
          var b; X _c;
          X get d => new A();get _e => new A();
          // no semicolon between completion point and next statement
          set s1(I x) {} set _s2(I x) {m(null);}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('z');
    assertNotSuggested('I');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_ThisExpression_constructor_param() async {
    // SimpleIdentifier  FieldFormalParameter  FormalParameterList
    addTestSource('''
        void f() { }
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          A(this.^) {}
          A.z() {}
          var b; X _c; static sb;
          X get d => new A();get _e => new A();
          // no semicolon between completion point and next statement
          set s1(I x) {} set _s2(I x) {m(null);}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    // Contributed by FieldFormalConstructorContributor
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('sb');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('z');
    assertNotSuggested('I');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_ThisExpression_constructor_param2() async {
    // SimpleIdentifier  FieldFormalParameter  FormalParameterList
    addTestSource('''
        void f() { }
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          A(this.b^) {}
          A.z() {}
          var b; X _c;
          X get d => new A();get _e => new A();
          // no semicolon between completion point and next statement
          set s1(I x) {} set _s2(I x) {m(null);}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    // Contributed by FieldFormalConstructorContributor
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('z');
    assertNotSuggested('I');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_ThisExpression_constructor_param3() async {
    // SimpleIdentifier  FieldFormalParameter  FormalParameterList
    addTestSource('''
        void f() { }
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          A(this.^b) {}
          A.z() {}
          var b; X _c;
          X get d => new A();get _e => new A();
          // no semicolon between completion point and next statement
          set s1(I x) {} set _s2(I x) {m(null);}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 1);
    // Contributed by FieldFormalConstructorContributor
    assertNotSuggested('b');
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('z');
    assertNotSuggested('I');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_ThisExpression_constructor_param4() async {
    // SimpleIdentifier  FieldFormalParameter  FormalParameterList
    addTestSource('''
        void f() { }
        class I {X get f => new A();get _g => new A();}
        class A implements I {
          A(this.b, this.^) {}
          A.z() {}
          var b; X _c;
          X get d => new A();get _e => new A();
          // no semicolon between completion point and next statement
          set s1(I x) {} set _s2(I x) {m(null);}
          m(X x) {} I _n(X x) {}}
        class X{}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertNotSuggested('b');
    // Contributed by FieldFormalConstructorContributor
    assertNotSuggested('_c');
    assertNotSuggested('d');
    assertNotSuggested('_e');
    assertNotSuggested('f');
    assertNotSuggested('_g');
    assertNotSuggested('m');
    assertNotSuggested('_n');
    assertNotSuggested('s1');
    assertNotSuggested('_s2');
    assertNotSuggested('z');
    assertNotSuggested('I');
    assertNotSuggested('A');
    assertNotSuggested('X');
    assertNotSuggested('Object');
    assertNotSuggested('==');
  }

  Future<void> test_TopLevelVariableDeclaration_type() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // TopLevelVariableDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        ^ foo; ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_TopLevelVariableDeclaration_type_after_comment1() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // TopLevelVariableDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        // comment
        ^ foo; ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_TopLevelVariableDeclaration_type_after_comment2() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // TopLevelVariableDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        /* comment */
        ^ foo; ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_TopLevelVariableDeclaration_type_after_comment3() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // TopLevelVariableDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        /// some dartdoc
        ^ foo; ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_TopLevelVariableDeclaration_type_without_semicolon() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // TopLevelVariableDeclaration
    addSource('/home/test/lib/a.dart', 'class A { }');
    addTestSource('''
        import 'a.dart';
        ^ foo ''');

    await computeSuggestions();
    assertSuggestClass('A');
    assertCoreTypeSuggestions();
  }

  Future<void> test_TopLevelVariableDeclaration_typed_name() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // TopLevelVariableDeclaration
    addTestSource('class A {} B ^');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_TopLevelVariableDeclaration_untyped_name() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // TopLevelVariableDeclaration
    addTestSource('class A {} var ^');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_typeAlias_aliasedType() async {
    addTestSource(r'''
var a = 0;
typedef F = ^;
''');

    await computeSuggestions();
    assertCoreTypeSuggestions();
    assertNotSuggested('a');
  }

  Future<void> test_typeAlias_functionType_parameterType() async {
    addTestSource(r'''
typedef F = void Function(^);
''');

    await computeSuggestions();
    assertCoreTypeSuggestions();
  }

  Future<void> test_typeAlias_functionType_returnType() async {
    addTestSource(r'''
typedef F = ^ Function();
''');

    await computeSuggestions();
    assertCoreTypeSuggestions();
  }

  Future<void> test_typeAlias_interfaceType_argumentType() async {
    addTestSource(r'''
typedef F = List<^>;
''');

    await computeSuggestions();
    assertCoreTypeSuggestions();
  }

  Future<void> test_typeAlias_legacy_parameterType() async {
    addTestSource(r'''
typedef void F(^);
''');

    await computeSuggestions();
    assertCoreTypeSuggestions();
  }

  Future<void> test_TypeArgumentList() async {
    // SimpleIdentifier  BinaryExpression  ExpressionStatement
    resolveSource('/home/test/lib/a.dart', '''
        class C1 {int x;}
        F1() => 0;
        typedef String T1(int blat);''');
    addTestSource('''
        import 'a.dart';
        class C2 {int x;}
        F2() => 0;
        typedef int T2(int blat);
        class C<E> {}
        void f() { C<^> c; }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertSuggestClass('C1');
    assertSuggestTypeAlias('T1',
        aliasedType: 'String Function(int)', returnType: 'String');
    assertNotSuggested('C2');
    assertNotSuggested('T2');
    assertNotSuggested('F1');
    assertNotSuggested('F2');
  }

  Future<void> test_TypeArgumentList2() async {
    // TypeName  TypeArgumentList  TypeName
    addSource('/home/test/lib/a.dart', '''
        class C1 {int x;}
        F1() => 0;
        typedef String T1(int blat);''');
    addTestSource('''
        import 'a.dart';
        class C2 {int x;}
        F2() => 0;
        typedef int T2(int blat);
        class C<E> {}
        void f() { C<C^> c; }''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset - 1);
    expect(replacementLength, 1);
    assertSuggestClass('C1');
    assertNotSuggested('C2');
  }

  Future<void> test_TypeArgumentList_functionReference() async {
    addTestSource('''
class A {}

void foo<T>() {}

void f() {
  foo<^>;
}
''');
    await computeSuggestions();

    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('Object');
    assertNotSuggested('A');
  }

  Future<void> test_TypeArgumentList_recursive() async {
    resolveSource('/home/test/lib/a.dart', '''
class A {}
''');
    resolveSource('/home/test/lib/b.dart', '''
export 'a.dart';
export 'b.dart';
class B {}
''');
    addTestSource('''
import 'b.dart';
List<^> x;
''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('A');
    assertSuggestClass('B');
  }

  Future<void> test_VariableDeclaration_name() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // VariableDeclarationStatement  Block
    addSource('/home/test/lib/b.dart', '''
        lib B;
        foo() { }
        class _B { }
        class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        class Y {Y.c(); Y._d(); z() {}}
        void f() {var ^}''');

    await computeSuggestions();
    assertNoSuggestions();
  }

  Future<void> test_VariableDeclarationList_final() async {
    // VariableDeclarationList  VariableDeclarationStatement  Block
    addTestSource('void f() {final ^} class C { }');

    await computeSuggestions();
    assertSuggestClass('Object');
    assertNotSuggested('C');
    assertNotSuggested('==');
  }

  Future<void> test_VariableDeclarationStatement_RHS() async {
    // SimpleIdentifier  VariableDeclaration  VariableDeclarationList
    // VariableDeclarationStatement
    addSource('/home/test/lib/b.dart', '''
        lib B;
        foo() { }
        class _B { }
        class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        class Y {Y.c(); Y._d(); z() {}}
        class C {bar(){var f; {var x;} var e = ^}}''');

    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('X');
    assertNotSuggested('_B');
    assertNotSuggested('Y');
    assertNotSuggested('C');
    assertNotSuggested('f');
    assertNotSuggested('x');
    assertNotSuggested('e');
  }

  Future<void> test_VariableDeclarationStatement_RHS_missing_semicolon() async {
    // VariableDeclaration  VariableDeclarationList
    // VariableDeclarationStatement
    resolveSource('/home/test/lib/b.dart', '''
        lib B;
        foo1() { }
        void bar1() { }
        class _B { }
        class X {X.c(); X._d(); z() {}}''');
    addTestSource('''
        import 'b.dart';
        foo2() { }
        void bar2() { }
        class Y {Y.c(); Y._d(); z() {}}
        class C {bar(){var f; {var x;} var e = ^ var g}}''');
    await computeSuggestions();
    expect(replacementOffset, completionOffset);
    expect(replacementLength, 0);
    assertSuggestClass('X');
    assertSuggestFunction('foo1', 'dynamic');
    assertNotSuggested('bar1');
    assertNotSuggested('foo2');
    assertNotSuggested('bar2');
    assertNotSuggested('_B');
    assertNotSuggested('Y');
    assertNotSuggested('C');
    assertNotSuggested('f');
    assertNotSuggested('x');
    assertNotSuggested('e');
  }

  Future<void> test_withClause_mixin() async {
    newFile('/home/test/lib/a.dart', content: 'mixin M {}');
    addTestSource('''
import 'a.dart';

class B extends A with ^
''');
    await computeSuggestions();
    assertSuggestMixin('M');
  }

  Future<void> test_YieldStatement() async {
    addTestSource('''
void f() async* {
  yield ^
}
''');
    await computeSuggestions();

    // Sanity check any completions.
    assertSuggestClass('Object');
  }
}
