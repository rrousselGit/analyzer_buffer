import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_buffer/analyzer_buffer.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('RevivableToSource', () {
    test('Avoids `const Object(const Object())', () async {
      final result = await resolveFiles('''
class Holder {
  const Holder(Object? pos, {Object? named});
}

void fn({
  Object record = const ([1, 2], named: [3, 4]),
  Object objectWithoutTypeArgs = const Holder([1, 2], named: [3, 4]),
  Object listLiteral = const [[1, 2]],
  Object setLiteral = const {[1, 2]},
  Object mapLiteral = const {[1, 2]: [3, 4]},
}) {}
''');

      final fn = result.libraryElement.getTopLevelFunction('fn')!;
      final [
        record,
        objectWithoutTypeArgs,
        listLiteral,
        setLiteral,
        mapLiteral,
      ] = fn.formalParameters;

      expect(
        record.computeConstantValue()!.toCode(),
        'const ([1, 2], named: [3, 4], )',
      );
      expect(
        objectWithoutTypeArgs.computeConstantValue()!.toCode(),
        'const #{{asset:temp_test/lib/main.dart|Holder}}([1, 2], named: [3, 4])',
      );
      expect(
        objectWithoutTypeArgs
            .computeConstantValue()!
            .toCode(addLeadingConst: false),
        '#{{asset:temp_test/lib/main.dart|Holder}}([1, 2], named: [3, 4])',
      );
      expect(
        listLiteral.computeConstantValue()!.toCode(),
        'const [[1, 2]]',
      );
      expect(
        listLiteral.computeConstantValue()!.toCode(addLeadingConst: false),
        '[[1, 2]]',
      );
      expect(
        setLiteral.computeConstantValue()!.toCode(),
        'const {[1, 2]}',
      );
      expect(
        setLiteral.computeConstantValue()!.toCode(addLeadingConst: false),
        '{[1, 2]}',
      );
      expect(
        mapLiteral.computeConstantValue()!.toCode(),
        'const {[1, 2]: [3, 4]}',
      );
      expect(
        mapLiteral.computeConstantValue()!.toCode(addLeadingConst: false),
        '{[1, 2]: [3, 4]}',
      );
    });

    test('.toCode', () async {
      final result = await resolveFiles(r'''
import 'dart:async' as async;
import 'dart:io' as io;

void function() {}

const topLevel = 21;

class Foo {}

typedef Typedef = Holder<async.StreamController<io.File>>;

class Holder<T> {
  const Holder.named(Object obj, Object obj2, {Object? named, Object? named2});
  static const staticConst = 42;

  void fn({
    Object str = 'foo',
    Object str2 = "'f\\oo\n",
    Object integer = 42,
    Object doubleValue = 3.14,
    Object boolean = true,
    Object? nullable = null,
    Object record = (1, 2, named: 'named'),
    Object object = const Holder<async.StreamController<io.File>>.named(1, 2, named: 'named', named2: 'named2'),
    Object objectWithoutTypeArgs = const Holder.named(1, 2, named: 'named', named2: 'named2'),
    Object typedef = const Typedef.named(1, 2, named: 'named', named2: 'named2'),
    Object symbolLiteral = #_foo,
    Object function = function,
    Object topLevelVar = topLevel,
    Object staticVar = Holder.staticConst,
    Object inferredStaticVar = staticConst,
    Object type = Foo,
    Object listLiteral = const [1, 2, 3],
    Object setLiteral = const {1, 2, 3},
    Object mapLiteral = const {'a': 1, 'b': 2},
  }) {}
}
''');
      final controllerElement =
          result.importedElementWithName('StreamController')!;
      controllerElement as ClassElement;
      final fileElement = result.importedElementWithName('File')!;
      fileElement as ClassElement;

      final fn = result.libraryElement.getClass('Holder')!.getMethod('fn')!;
      final [
        str,
        str2,
        integer,
        doubleValue,
        boolean,
        nullable,
        record,
        _, // TODO BLOCKED BY https://github.com/dart-lang/source_gen/issues/478
        objectWithoutTypeArgs,
        _, // TODO BLOCKED BY https://github.com/dart-lang/source_gen/issues/478#issuecomment-3033193417
        symbolLiteral,
        function,
        topLevelVar,
        staticVar,
        inferredStaticVar,
        type,
        listLiteral,
        setLiteral,
        mapLiteral,
      ] = fn.formalParameters;

      expect(
        str.computeConstantValue()!.toCode(),
        "'foo'",
      );
      expect(
        str2.computeConstantValue()!.toCode(),
        r"'\'f\oo\n'",
      );
      expect(
        integer.computeConstantValue()!.toCode(),
        '42',
      );
      expect(
        doubleValue.computeConstantValue()!.toCode(),
        '3.14',
      );
      expect(
        boolean.computeConstantValue()!.toCode(),
        'true',
      );
      expect(
        nullable.computeConstantValue()!.toCode(),
        'null',
      );
      expect(
        record.computeConstantValue()!.toCode(),
        "const (1, 2, named: 'named', )",
      );
      expect(
        record.computeConstantValue()!.toCode(addLeadingConst: false),
        "(1, 2, named: 'named', )",
      );
      expect(
        objectWithoutTypeArgs.computeConstantValue()!.toCode(),
        "const #{{asset:temp_test/lib/main.dart|Holder}}.named(1, 2, named: 'named', named2: 'named2')",
      );
      expect(
        objectWithoutTypeArgs
            .computeConstantValue()!
            .toCode(addLeadingConst: false),
        "#{{asset:temp_test/lib/main.dart|Holder}}.named(1, 2, named: 'named', named2: 'named2')",
      );
      expect(
        () => symbolLiteral.computeConstantValue()!.toCode(),
        throwsUnsupportedError,
      );
      expect(
        function.computeConstantValue()!.toCode(),
        '#{{asset:temp_test/lib/main.dart|function}}',
      );
      expect(
        topLevelVar.computeConstantValue()!.toCode(),
        '#{{package:temp_test/main.dart|topLevel}}',
      );
      expect(
        staticVar.computeConstantValue()!.toCode(),
        '#{{package:temp_test/main.dart|Holder}}.staticConst',
      );
      expect(
        inferredStaticVar.computeConstantValue()!.toCode(),
        '#{{package:temp_test/main.dart|Holder}}.staticConst',
      );
      expect(
        type.computeConstantValue()!.toCode(),
        '#{{package:temp_test/main.dart|Foo}}',
      );
      expect(
        listLiteral.computeConstantValue()!.toCode(),
        'const [1, 2, 3]',
      );
      expect(
        listLiteral.computeConstantValue()!.toCode(addLeadingConst: false),
        '[1, 2, 3]',
      );
      expect(
        setLiteral.computeConstantValue()!.toCode(),
        'const {1, 2, 3}',
      );
      expect(
        setLiteral.computeConstantValue()!.toCode(addLeadingConst: false),
        '{1, 2, 3}',
      );
      expect(
        mapLiteral.computeConstantValue()!.toCode(),
        "const {'a': 1, 'b': 2}",
      );
      expect(
        mapLiteral.computeConstantValue()!.toCode(addLeadingConst: false),
        "{'a': 1, 'b': 2}",
      );
    });
  });
}
