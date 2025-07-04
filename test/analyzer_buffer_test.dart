// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer_buffer/analyzer_buffer.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('AnalyzerBuffer', () {
    test('handles empty', () async {
      final result = await resolveFiles('''
int value() => 42;
''');
      final type = result.libraryElement2.typeProvider.intType;

      var buffer = AnalyzerBuffer.newLibrary(header: 'Foo');

      expect(buffer.isEmpty, isTrue);
      expect(buffer.toString(), '');
      buffer.write('Hello World');
      expect(buffer.isEmpty, isFalse);
      expect(buffer.toString(), isNotEmpty);

      buffer = AnalyzerBuffer.fromLibrary2(result.libraryElement2);

      expect(buffer.isEmpty, isTrue);
      expect(buffer.toString(), '');
      buffer.writeType(type);
      expect(buffer.isEmpty, isFalse);
      expect(buffer.toString(), isNotEmpty);
    });

    group('writeType', () {
      test('preserves typedefs, if any', () async {
        final result = await resolveFiles('''
typedef MyMap<T> = Map<T, T;

MyMap<int> value() => 42;
''');
        final buffer = AnalyzerBuffer.fromLibrary2(result.libraryElement2);

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
      test('recursive: controls whether type arguments are written', () async {
        final result = await resolveFiles("import 'dart:async' as async;'");
        final buffer = AnalyzerBuffer.fromLibrary2(result.libraryElement2);

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
          "import 'dart:async' as async;'\n"
          "import 'dart:io' as io;'\n"
          "import 'package:path/path.dart';",
        );
        final buffer = AnalyzerBuffer.fromLibrary(result.libraryElement);
        final buffer2 = AnalyzerBuffer.fromLibrary2(result.libraryElement2);

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
        final buffer = AnalyzerBuffer.newLibrary();

        final result = await resolveFiles(
          "import 'dart:async' as async;'\n"
          "import 'dart:io' as io;'\n"
          "import 'package:path/path.dart;",
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

        buffer.writeType(controllerType);

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(contains("import 'dart:async' as _0;")),
        );
        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(contains("import 'dart:io' as _0;")),
        );
        expect(
          buffer.toString(),
          isNot(
            matchesIgnoringPrefixes(
              contains("import 'package:path/path.dart' as _0;"),
            ),
          ),
        );
      });
    });
    group('toString', () {
      test('includes a top comment, headers, imports and writes', () {
        final buffer = AnalyzerBuffer.newLibrary(header: '<Header>');

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
      test('interpolates #{{uri|name}}', () {
        final buffer = AnalyzerBuffer.newLibrary();

        buffer.write(
          'Hello '
          '#{{dart:core|int}} '
          '#{{dart:async|StreamController}} '
          '#{{package:example|Name}} '
          'World',
        );

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(
            contains('Hello int _0.StreamController _0.Name World'),
          ),
        );
      });
      test('interpolates #{{name}} with args', () {
        final buffer = AnalyzerBuffer.newLibrary();

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
        final buffer = AnalyzerBuffer.newLibrary();

        expect(
          () => buffer.write('Hello #{{name}} World'),
          throwsA(isA<ArgumentError>()),
        );
      });
      test(
          'args that call `write` inherit the current arguments, on top of the new ones',
          () {
        final buffer = AnalyzerBuffer.newLibrary();

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
      test('if created with .fromLibrary2, does not add auto-import', () async {
        final result = await resolveFiles("import 'dart:async' as async;");
        final buffer = AnalyzerBuffer.fromLibrary2(result.libraryElement2);

        buffer.write('Hello #{{dart:async|StreamController}} World');

        expect(buffer.toString(), isNot(contains('dart:async')));
      });
      test('if created with .newLibrary, adds auto-imports for types', () {
        final buffer = AnalyzerBuffer.newLibrary();
        buffer.write('Hello #{{dart:async|StreamController}} World');

        expect(
          buffer.toString(),
          matchesIgnoringPrefixes(contains("import 'dart:async' as _0;")),
        );
      });
    });
  });

  group('CodeFor', () {
    test('converts Elements2 to code', () async {
      final result = await resolveFiles(
        "import 'dart:async' as async;\n"
        "import 'dart:io' as io;\n",
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

      expect(
        controllerType.toCode(),
        '#{{dart:async|StreamController}}<#{{dart:io|File}}>',
      );
      expect(
        controllerType.toCode(recursive: false),
        '#{{dart:async|StreamController}}',
      );
    });
  });
}
