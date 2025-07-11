// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer_buffer/analyzer_buffer.dart';
import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import './annotation.dart';

/// Builds generators for `build_runner` to run
Builder e2e(BuilderOptions options) {
  return SharedPartBuilder(
    [const E2EPart()],
    'e2e',
  );
}

Builder e2e2(BuilderOptions options) {
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
      sourcePath: buildStep.inputId.path,
      header: '// ignore_for_file: type=lint, type=warning',
    );

    final elements = library.annotatedWith(
      const TypeChecker.fromRuntime(E2E),
    );

    for (final annotation in elements) {
      final element = annotation.element;
      _handle(element, buffer);
    }

    return buffer.toString();
  }
}

class E2EPart extends GeneratorForAnnotation<E2E> {
  const E2EPart();

  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    final buffer = AnalyzerBuffer.fromLibrary(
      element.library!,
      sourcePath: buildStep.inputId.path,
      header: '// ignore_for_file: type=lint, type=warning',
    );

    _handle(element, buffer);

    return buffer.toString();
  }
}

void _handle(Element element, AnalyzerBuffer buffer) {
  switch (element) {
    case FunctionElement():
      buffer.writeType(element.returnType);
      buffer.write(' ${element.name}E2e([');
      for (final parameter in element.parameters) {
        buffer.write(
          '${parameter.type.toCode()} ${element.name}',
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
