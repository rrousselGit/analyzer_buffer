// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer_buffer/analyzer_buffer.dart';
import 'package:build/build.dart';
import 'package:path/path.dart' as path;
import 'package:source_gen/source_gen.dart';
import './annotation.dart';

Builder partBuilder(BuilderOptions options) {
  return SharedPartBuilder(
    [const E2EPart()],
    'e2e',
  );
}

class E2EPart extends GeneratorForAnnotation<E2E> {
  const E2EPart();

  @override
  Future<String> generateForAnnotatedElement(
    Element2 element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final buffer = AnalyzerBuffer.part2(
      element.library2!,
      header: '// ignore_for_file: type=lint, type=warning',
    );

    _handle(element, buffer);

    return buffer.toString();
  }
}

Builder libBuilder(BuilderOptions options) {
  return LibraryBuilder(
    E2ELibrary(),
    generatedExtension: '.e2e.dart',
  );
}

class E2ELibrary extends Generator {
  E2ELibrary();

  @override
  FutureOr<String?> generate(LibraryReader library, BuildStep buildStep) {
    final buffer = AnalyzerBuffer.newLibrary(
      packageName: buildStep.inputId.package,
      path: path.join(
        path.dirname(buildStep.inputId.path),
        '${path.basenameWithoutExtension(buildStep.inputId.path)}.e2e.dart',
      ),
      header: '// ignore_for_file: type=lint, type=warning',
    );

    // final elements = library.annotatedWith(
    //   const TypeChecker.fromRuntime(E2E),
    // );

    // for (final annotation in elements) {
    //   final element = annotation.element;
    //   _handle(element, buffer);
    // }

    return buffer.toString();
  }
}

void _handle(Element2 element, AnalyzerBuffer buffer) {
  switch (element) {
    case TopLevelFunctionElement():
      buffer.writeType(element.returnType);
      buffer.write(' ${element.name3}E2e([');
      for (final parameter in element.formalParameters) {
        buffer.write(
          '${parameter.type.toCode()} ${parameter.name3}',
        );
        if (parameter.hasDefaultValue) {
          buffer.write(' = ${parameter.computeConstantValue()!.toCode()}');
        }
        buffer.write(',');
      }

      buffer.write(']) => throw UnimplementedError();');

    case _:
      throw InvalidGenerationSourceError(
        'The @E2E annotation can only be used on functions.',
        element: element,
      );
  }
}
