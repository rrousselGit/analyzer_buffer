import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:source_gen/source_gen.dart';

import 'code_buffer.dart';

extension AnnotationToCode on Annotation {}

extension RevivableToSource on DartObject {
  /// Handles basic types and nested Revivables
  String toCode() {
    if (isNull) return 'null';

    if (variable case final variable?) {
      if (variable.isStatic && variable is! TopLevelVariableElement) {
        final enclosingClass =
            variable.thisOrAncestorOfType<InterfaceElement>();
        if (enclosingClass == null) {
          throw StateError(
            'Could not find the enclosing class for ${variable.name}.',
          );
        }

        return '${enclosingClass.code}.${variable.code}';
      }
    }

    if (toStringValue() case final value?) return "'${_escapeString(value)}'";
    if (toIntValue() case final value?) return value.toString();
    if (toDoubleValue() case final value?) return value.toString();
    if (toDoubleValue() case final value?) return value.toString();

    if (toListValue() case final list?) {
      return '[${list.map((e) => e.toCode()).join(', ')}]';
    }
    if (toSetValue() case final set?) {
      return '{${set.map((e) => e.toCode()).join(', ')}}';
    }
    if (toMapValue() case final map?) {
      return '{${map.entries.map((e) => '${e.key!.toCode()}: ${e.value!.toCode()}').join(', ')}}';
    }

    if (toRecordValue() case final record?) {
      final buffer = StringBuffer('(');

      for (final param in record.positional) {
        buffer.write(param.toCode());
        buffer.write(', ');
      }
      for (final entry in record.named.entries) {
        buffer.write('${entry.key}: ${entry.value.toCode()}, ');
      }

      buffer.write(')');
      return buffer.toString();
    }

    if (toSymbolValue() case final symbol?) {
      throw UnsupportedError(
        'Symbol values are not supported in this context: $symbol',
      );
    }
    if (toFunctionValue() case final function?) {
      throw UnsupportedError(
        'Function values are not supported in this context: $function',
      );
    }

    final revivable = ConstantReader(this).revive();
    return revivable.toCode();
  }

  String _escapeString(String input) =>
      input.replaceAll("'", r"\'").replaceAll('\n', r'\n');
}

extension on Revivable {
  String toCode() {
    final identifierCode = _typeCode();
    final buffer = StringBuffer(identifierCode);

    if (accessor.isNotEmpty) buffer.write('.${accessor}');

    buffer.write('(');
    for (final arg in positionalArguments) buffer.write(arg.toCode());
    for (final entry in namedArguments.entries) {
      buffer.write('${entry.key}: ${entry.value.toCode()}');
    }
    buffer.write(')');

    return buffer.toString();
  }

  String _typeCode() {
    assert(source.hasFragment);
    final typeName = this.source.fragment;
    final uri = this.source.toPackageUri();

    return '#{{$uri|$typeName}}';
  }
}

extension UriX on Uri {
  Uri toPackageUri() {
    if (scheme == 'package') return this;

    if (scheme == 'asset') {
      if (pathSegments case [final packageName, 'lib', ...final res]) {
        return Uri(scheme: 'package', pathSegments: [packageName, ...res]);
      }
    }

    throw ArgumentError.value(this, 'uri', 'Cannot convert to package URI');
  }
}
