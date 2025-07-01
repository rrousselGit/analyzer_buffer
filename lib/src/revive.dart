import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:source_gen/source_gen.dart';

import 'code_buffer.dart';

/// Converts a [DartObject] to a code representation.
extension RevivableToSource on DartObject {
  /// Converts a [DartObject] into something that a string representation
  /// that can be passed to [CodeBuffer.write].
  ///
  /// This is particularly useful to insert constant values into generated code.
  /// For example, to insert default values. For example given the user-defined
  /// code:
  /// ```dart
  /// void fn({int value = 42}) {}
  /// ```
  /// `value` would be a [FormalParameterElement], and the default
  /// value could be obtained with:
  /// ```dart
  /// DartObject? defaultValue = element.computeConstantValue();
  /// ```
  /// Then, to insert the default value into generated code, you could use:
  /// ```dart
  /// codeBuffer.write('''
  /// void myFunction({
  ///   int value = ${defaultValue.toCode()},
  /// })
  /// ''');
  /// ```
  ///
  /// **Note**:
  /// Symbols and functions are currently not supported.
  String toCode() {
    if (isNull) return 'null';

    if (variable2 case final variable?) {
      if (variable.isStatic && variable is! TopLevelVariableElement2) {
        final enclosingClass =
            variable.thisOrAncestorOfType2<InterfaceElement2>();
        if (enclosingClass == null) {
          throw StateError(
            'Could not find the enclosing class for ${variable.name3}.',
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
    if (toFunctionValue2() case final function?) {
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

    if (accessor.isNotEmpty) buffer.write('.$accessor');

    buffer.write('(');
    for (final arg in positionalArguments) {
      buffer.write(arg.toCode());
    }
    for (final entry in namedArguments.entries) {
      buffer.write('${entry.key}: ${entry.value.toCode()}');
    }
    buffer.write(')');

    return buffer.toString();
  }

  String _typeCode() {
    assert(source.hasFragment, 'URIs must use URIs of format url#name');
    final typeName = source.fragment;
    final uri = source.toPackageUri();

    return '#{{$uri|$typeName}}';
  }
}

extension on Uri {
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
