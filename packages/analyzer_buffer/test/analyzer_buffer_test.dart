// ignore_for_file: deprecated_member_use, missing_whitespace_between_adjacent_strings

import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer_buffer/analyzer_buffer.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('AnalyzerBuffer', () {
    test('handles empty', () async {
      final result = await resolveFiles('''
part 'foo.g.dart';

int value() => 42;
''');
      final type = result.libraryElement2.typeProvider.intType;

      var buffer = AnalyzerBuffer.newLibrary(
        header: 'Foo',
        packageName: 'temp_test',
        path: 'lib/foo.g.dart',
      );

      expect(buffer.isEmpty, isTrue);
      expect(buffer.toString(), '');
      buffer.write('Hello World');
      expect(buffer.isEmpty, isFalse);
      expect(buffer.toString(), isNotEmpty);

      buffer = AnalyzerBuffer.part2(result.libraryElement2);

      expect(buffer.isEmpty, isTrue);
      expect(buffer.toString(), '');
      buffer.writeType(type);
      expect(buffer.isEmpty, isFalse);
      expect(buffer.toString(), isNotEmpty);
    });

    group('writeType', () {
      test('preserves typedefs, if any', () async {
        final result = await resolveFiles('''
part 'foo.g.dart';

typedef MyMap<T> = Map<T, T>;

MyMap<int> value() => 42;
''');

        final buffer = AnalyzerBuffer.part2(result.libraryElement2);

        final valueElement =
            result.libraryElement2.getTopLevelFunction('value')!;

        buffer.write('Hello(');
        buffer.writeType(valueElement.returnType);
        buffer.write(') World');

        expect(
          buffer.toString(),
          contains('Hello(MyMap<int>) World'),
        );
      });
      test('supports dynamic/invalid types', () async {
        final result = await resolveFiles('''
part 'foo.g.dart';

dynamic fn() {}
Invalid fn2() {}
''');

        final buffer = AnalyzerBuffer.part2(result.libraryElement2);

        final fnElement = result.libraryElement2.getTopLevelFunction('fn')!;
        final fn2Element = result.libraryElement2.getTopLevelFunction('fn2')!;

        buffer.write('Hello(');
        buffer.writeType(fnElement.returnType);
        buffer.write(') World');

        buffer.write('Hello(');
        buffer.writeType(fn2Element.returnType);
        buffer.write(') World');

        expect(
          buffer.toString(),
          contains('Hello(dynamic) World'),
        );
        expect(
          buffer.toString(),
          contains('Hello(InvalidType) World'),
        );
      });
      test('recursive: controls whether type arguments are written', () async {
        final result = await resolveFiles("""
import 'dart:async' as async;

part 'foo.g.dart';
""");
        final buffer = AnalyzerBuffer.part2(result.libraryElement2);

        final controllerElement =
            result.importedElementWithName('StreamController')!;
        controllerElement as ClassElement2;

        final controllerType = controllerElement.instantiate(
          typeArguments: [result.libraryElement2.typeProvider.doubleType],
          nullabilitySuffix: NullabilitySuffix.none,
        );

        buffer.write('Hello(');
        buffer.writeType(controllerType, recursive: false);
        buffer.write(') World');

        expect(
          buffer.toString(),
          contains('Hello(async.StreamController) World'),
        );
      });
      test('respects import prefixes', () async {
        final result = await resolveFiles(
          "import 'dart:async' as async;\n"
          "import 'dart:io' as io;\n"
          "import 'package:path/path.dart';\n"
          "part 'foo.g.dart';\n",
        );
        final buffer = AnalyzerBuffer.part(result.libraryElement);
        final buffer2 = AnalyzerBuffer.part2(result.libraryElement2);

        final controllerElement =
            result.importedElementWithName('StreamController')!;
        controllerElement as ClassElement2;
        final fileElement = result.importedElementWithName('File')!;
        fileElement as ClassElement2;
        final contextElement = result.importedElementWithName('Context')!;
        contextElement as ClassElement2;

        final controllerType = controllerElement.instantiate(
          typeArguments: [fileElement.thisType],
          nullabilitySuffix: NullabilitySuffix.none,
        );

        buffer.write('Hello(');
        buffer.writeType(controllerType);
        buffer.write(') World');

        buffer.write('Hello(');
        buffer.writeType(contextElement.thisType);
        buffer.write(') World');

        buffer2.write('Hello(');
        buffer2.writeType(controllerType);
        buffer2.write(') World');

        buffer2.write('Hello(');
        buffer2.writeType(contextElement.thisType);
        buffer2.write(') World');

        expect(
          buffer.toString(),
          contains('Hello(async.StreamController<io.File>) World'),
        );
        expect(
          buffer.toString(),
          contains('Hello(Context) World'),
        );

        expect(
          buffer2.toString(),
          contains('Hello(async.StreamController<io.File>) World'),
        );
        expect(
          buffer2.toString(),
          contains('Hello(Context) World'),
        );
      });
      test('if created with .newLibrary, adds auto-imports for types',
          () async {
        final buffer = AnalyzerBuffer.newLibrary(
          packageName: 'temp_test',
          path: 'lib/foo.g.dart',
        );

        final result = await resolveFiles(
          "import 'dart:async' as async;\n"
          "import 'dart:io' as io;\n"
          "import 'package:path/path.dart';\n"
          "part 'foo.g.dart';\n",
        );

        final controllerElement =
            result.importedElementWithName('StreamController')!;
        controllerElement as ClassElement2;
        final fileElement = result.importedElementWithName('File')!;
        fileElement as ClassElement2;

        final controllerType = controllerElement.instantiate(
          typeArguments: [fileElement.thisType],
          nullabilitySuffix: NullabilitySuffix.none,
        );
        final controllerType2 = controllerElement.instantiate(
          typeArguments: [result.typeProvider.voidType],
          nullabilitySuffix: NullabilitySuffix.none,
        );

        buffer.writeType(controllerType);
        buffer.writeType(controllerType2);

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            strContainsOnce("import 'dart:async' as _0;"),
          ),
        );
        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(strContainsOnce("import 'dart:io' as _1;")),
        );
        expect(
          buffer.toString(),
          isNot(
            matchesIgnoringPrefixes(
              strContainsOnce("import 'package:path/path.dart' as _2;"),
            ),
          ),
        );
      });
    });
    group('toString', () {
      test('includes a top comment, headers, imports and writes', () {
        final buffer = AnalyzerBuffer.newLibrary(
          header: '<Header>',
          packageName: 'temp_test',
          path: 'lib/foo.g.dart',
        );

        buffer.write('Hello #{{dart:async|StreamController}} World');

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes('''
// GENERATED CODE - DO NOT MODIFY BY HAND
<Header>
import 'dart:async' as _0;
Hello _0.StreamController World'''),
        );
      });
    });
    group('write', () {
      test('handles re-export as prefix', () async {
        final result = await resolveFiles(
          "import 'foo.dart' as foo;\n"
          "part 'foo.g.dart';\n",
          files: {'foo.dart': "export 'dart:async';"},
        );
        final buffer = AnalyzerBuffer.part(result.libraryElement);
        final buffer2 = AnalyzerBuffer.part2(result.libraryElement2);

        buffer.write('Hello #{{dart:async|StreamController}} World');
        buffer2.write('Hello #{{dart:async|StreamController}} World');

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            contains('Hello foo.StreamController World'),
          ),
        );
        expect(
          buffer2.toString(),
          matchesIgnoringPrefixes(
            contains('Hello foo.StreamController World'),
          ),
        );
      });

      test('interpolates #{{uri|name}}', () {
        final file = tempDir().file('test', 'main.dart');
        final buffer = AnalyzerBuffer.newLibrary(
          packageName: 'temp_test',
          path: 'test/main.g.dart',
        );

        buffer.write(
          'Hello '
          '#{{dart:core|int}} '
          '#{{dart:async|StreamController}} '
          '#{{dart:async|FutureOr}} '
          '#{{package:example|Name}} '
          '#{{package:example/foo.dart|Name2}} '
          '#{{riverpod|Provider}} '
          '#{{other/bar.dart|Bar}} '
          '#{{other/baz|Baz}} '
          '#{{file://${file.path}|File}} '
          'World',
        );

        expect(buffer.toString(), isNot(contains('dart:core')));
        expect(buffer.toString(), strContainsOnce('dart:async'));
        expect(
          buffer.toString(),
          strContainsOnce('package:example/example.dart'),
        );
        expect(buffer.toString(), strContainsOnce('package:example/foo.dart'));
        expect(
          buffer.toString(),
          strContainsOnce('package:riverpod/riverpod.dart'),
        );
        expect(buffer.toString(), strContainsOnce('package:other/bar.dart'));
        expect(buffer.toString(), strContainsOnce('package:other/baz.dart'));
        expect(
          buffer.toString(),
          strContainsOnce("import 'file://${file.path}'"),
        );

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            allOf([
              contains(' int '),
              contains(' _0.StreamController '),
              contains(' _0.FutureOr '),
              contains(' _1.Name '),
              contains(' _2.Name2 '),
              contains(' _3.Provider '),
              contains(' _4.Bar '),
              contains(' _5.Baz '),
              contains(' _6.File '),
            ]),
          ),
        );
      });
      test('interpolates #{{name}} with args', () {
        final buffer = AnalyzerBuffer.newLibrary(
          packageName: 'temp_test',
          path: 'lib/foo.g.dart',
        );

        buffer.write(
          'Hello #{{name}} World',
          args: {'name': () => buffer.write('Dart')},
        );

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(contains('Hello Dart World')),
        );
      });
      test('#{{name}} without a matching arg throws', () {
        final buffer = AnalyzerBuffer.newLibrary(
          packageName: 'temp_test',
          path: 'lib/foo.g.dart',
        );

        expect(
          () => buffer.write('Hello #{{name}} World'),
          throwsA(isA<ArgumentError>()),
        );
      });
      test(
          'args that call `write` inherit the current arguments, on top of the new ones',
          () {
        final buffer = AnalyzerBuffer.newLibrary(
          packageName: 'temp_test',
          path: 'lib/foo.g.dart',
        );

        buffer.write(
          args: {
            'arg1': () => buffer.write(
                  args: {'arg3': () => buffer.write('World')},
                  'Hello #{{arg2}} from #{{arg3}}',
                ),
            'arg2': () => buffer.write('John'),
          },
          '#{{arg1}}',
        );

        expect(
          buffer.toString(),
          contains('Hello John from World'),
        );
      });
      test(
          'if created with .fromLibrary2, does not add auto-import but respect prefixes',
          () async {
        final result = await resolveFiles(
          "import 'dart:async' as async;\n"
          "part 'foo.g.dart';\n",
        );
        final buffer = AnalyzerBuffer.part2(result.libraryElement2);

        buffer.write('Hello #{{dart:async|StreamController}} World');

        expect(buffer.toString(), isNot(contains('dart:async')));

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            contains('Hello async.StreamController World'),
          ),
        );
      });
    });
  });

  group('CodeFor', () {
    test('converts Elements2 to code', () async {
      final result = await resolveFiles(
        """
import 'dart:async' as async;
import 'dart:io' as io;

typedef TypeAlias<A, B> = (List<A> a, List<B> b);

dynamic fn() {}
Invalid fn2() {}

int Function(
  List<int> a,
  List<int>, {
  required List<int> b,
  List<int> d,
}) namedFn() => throw UnimplementedError();
int Function(
  List<int> a,
  List<int>, [
  List<int> d,
]) posFn() => throw UnimplementedError();

Never fn5() => throw UnimplementedError();
void fn6() {}

(List<int> a, List<int>, {List<int> b}) record() => throw UnimplementedError();
async.StreamController<io.File> controller() => throw UnimplementedError();
TypeAlias<List<int>, List<String>> typeAlias() => throw UnimplementedError();

int? nullable() => null;
(int?,)? nullableRecord() => (null,);
int? Function(int?)? nullableFn() => null;
TypeAlias<int?, String?>? nullableTypeAlias() => null;
""",
      );

      final [
        fn,
        fn2,
        namedFn,
        posFn,
        fn5,
        fn6,
        record,
        controller,
        typeAlias,
        nullable,
        nullableRecord,
        nullableFn,
        nullableTypeAlias,
      ] = result.libraryElement2.topLevelFunctions
          .map((e) => e.returnType)
          .toList();

      expect(
        controller.toCode(),
        '#{{dart:async|StreamController}}<#{{dart:io|File}}>',
      );
      expect(
        controller.toCode(recursive: false),
        '#{{dart:async|StreamController}}',
      );
      expect(fn.toCode(), '#{{dart:core|dynamic}}');
      expect(fn2.toCode, throwsA(isA<InvalidTypeException>()));
      expect(
        namedFn.toCode(),
        '#{{dart:core|int}} Function('
        '#{{dart:core|List}}<#{{dart:core|int}}> a, '
        '#{{dart:core|List}}<#{{dart:core|int}}>, {'
        'required #{{dart:core|List}}<#{{dart:core|int}}> b, '
        '#{{dart:core|List}}<#{{dart:core|int}}> d})',
      );
      expect(
        namedFn.toCode(recursive: false),
        '#{{dart:core|int}} Function('
        '#{{dart:core|List}}<#{{dart:core|int}}> a, '
        '#{{dart:core|List}}<#{{dart:core|int}}>, {'
        'required #{{dart:core|List}}<#{{dart:core|int}}> b, '
        '#{{dart:core|List}}<#{{dart:core|int}}> d})',
      );
      expect(
        posFn.toCode(),
        '#{{dart:core|int}} Function('
        '#{{dart:core|List}}<#{{dart:core|int}}> a, '
        '#{{dart:core|List}}<#{{dart:core|int}}>, ['
        '#{{dart:core|List}}<#{{dart:core|int}}> d])',
      );
      expect(
        posFn.toCode(recursive: false),
        '#{{dart:core|int}} Function('
        '#{{dart:core|List}}<#{{dart:core|int}}> a, '
        '#{{dart:core|List}}<#{{dart:core|int}}>, ['
        '#{{dart:core|List}}<#{{dart:core|int}}> d'
        '])',
      );
      expect(fn5.toCode(), '#{{dart:core|Never}}');
      expect(fn6.toCode(), '#{{dart:core|void}}');
      expect(
        record.toCode(),
        '(#{{dart:core|List}}<#{{dart:core|int}}>, '
        '#{{dart:core|List}}<#{{dart:core|int}}>, {'
        '#{{dart:core|List}}<#{{dart:core|int}}> b,})',
      );
      expect(
        record.toCode(recursive: false),
        '(#{{dart:core|List}}<#{{dart:core|int}}>, '
        '#{{dart:core|List}}<#{{dart:core|int}}>, {'
        '#{{dart:core|List}}<#{{dart:core|int}}> b,})',
      );
      expect(
        typeAlias.toCode(),
        '#{{package:temp_test/main.dart|TypeAlias}}<#{{dart:core|List}}<#{{dart:core|int}}>, '
        '#{{dart:core|List}}<#{{dart:core|String}}>>',
      );
      expect(
        typeAlias.toCode(recursive: false),
        '#{{package:temp_test/main.dart|TypeAlias}}',
      );

      expect(nullable.toCode(), '#{{dart:core|int}}?');
      expect(nullableRecord.toCode(), '(#{{dart:core|int}}?,)?');
      expect(
        nullableFn.toCode(),
        '#{{dart:core|int}}? Function(#{{dart:core|int}}?)?',
      );
      expect(
        nullableTypeAlias.toCode(),
        '#{{package:temp_test/main.dart|TypeAlias}}<#{{dart:core|int}}?, '
        '#{{dart:core|String}}?>?',
      );
      expect(
        nullableTypeAlias.toCode(recursive: false),
        '#{{package:temp_test/main.dart|TypeAlias}}?',
      );
    });
  });
}

Matcher strContainsOnce(String substring) {
  return predicate<String>(
    (value) {
      final firstMatchIndex = value.indexOf(substring);
      if (firstMatchIndex == -1) return false;

      final lastMatchIndex = value.lastIndexOf(substring);
      return firstMatchIndex == lastMatchIndex;
    },
    'contains "$substring" exactly once',
  );
}
