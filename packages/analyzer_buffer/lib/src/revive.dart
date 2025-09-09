import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

import 'analyzer_buffer.dart';

String _code(Uri uri, String name) {
  return '#{{$uri|$name}}';
}

/// Converts a [DartObject] to a code representation.
extension RevivableToSource on DartObject {
  /// Converts a [DartObject] into something that a string representation
  /// that can be passed to [AnalyzerBuffer.write].
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
  /// If [addLeadingConst] is `true` (default), the generated string
  /// will start with `const`. This is no-op if the `const` is not applicable
  /// to the constant value (such as for string literals, numbers, etc.).
  ///
  /// **Note**:
  /// Symbols and functions are currently not supported.
  String toCode({
    bool addLeadingConst = true,
  }) {
    final maybeConst = addLeadingConst ? 'const ' : '';

    final type = _DartObjectTypes.fromDartObject(this);
    switch (type) {
      case _Null():
        return 'null';
      case _Variable(value: final TopLevelVariableElement variable):
        return _code(variable.library.uri, variable.name!);
      case _Variable(value: VariableElement(isStatic: true) && final variable):
        final enclosingClass =
            variable.thisOrAncestorOfType<InterfaceElement>();
        if (enclosingClass == null) {
          throw StateError(
            'Could not find the enclosing class for ${variable.name}.',
          );
        }

        return '${enclosingClass.thisType.toCode(recursive: false)}.${variable.name}';
      case _Variable(value: VariableElement(isStatic: false)):
        // This is a local variable, which cannot be represented in code.
        throw UnsupportedError(
          'Local variables cannot be represented in code: ${type.value.name}',
        );
      case _String():
        return "'${_escapeString(type.value)}'";
      case _Int():
      case _Bool():
      case _Double():
        return type.value.toString();
      case _Type():
        return type.value.toCode();
      case _Record():
        final buffer = StringBuffer('$maybeConst(');

        for (final param in type.value.positional) {
          buffer.write(param.toCode(addLeadingConst: false));
          buffer.write(', ');
        }
        for (final entry in type.value.named.entries) {
          buffer.write(
            '${entry.key}: ${entry.value.toCode(addLeadingConst: false)}, ',
          );
        }

        buffer.write(')');
        return buffer.toString();
      case _List():
        return '$maybeConst[${type.value.map((e) => e.toCode(addLeadingConst: false)).join(', ')}]';
      case _Set():
        return '$maybeConst{${type.value.map((e) => e.toCode(addLeadingConst: false)).join(', ')}}';
      case _Map():
        return '$maybeConst{${type.value.entries.map(
              (e) => '${e.key.toCode(addLeadingConst: false)}: '
                  '${e.value.toCode(addLeadingConst: false)}',
            ).join(', ')}}';
      case _Unknown():
        try {
          final revivable = ConstantReader(this).revive();
          return revivable.toCode(addLeadingConst: addLeadingConst);
        } catch (e, stackTrace) {
          Error.throwWithStackTrace(
            FormatException(
              'Failed to revive constant $this. This is likely due to an unsupported constant syntax.\n$e',
            ),
            stackTrace,
          );
        }
    }
  }

  String _escapeString(String input) =>
      input.replaceAll("'", r"\'").replaceAll('\n', r'\n');
}

sealed class _DartObjectTypes {
  static _DartObjectTypes fromDartObject(DartObject dartObject) {
    // Handles vars first, to preserve any variable usage.
    if (dartObject.variable case final variable?) return _Variable(variable);
    if (dartObject.isNull) return const _Null();
    if (dartObject.toStringValue() case final value?) return _String(value);
    if (dartObject.toIntValue() case final value?) return _Int(value);
    if (dartObject.toDoubleValue() case final value?) return _Double(value);
    if (dartObject.toBoolValue() case final value?) return _Bool(value: value);
    if (dartObject.toRecordValue() case final record?) return _Record(record);
    if (dartObject.toListValue() case final list?) return _List(list);
    if (dartObject.toTypeValue() case final type?) return _Type(type);
    if (dartObject.toSetValue() case final set?) return _Set(set);
    if (dartObject.toMapValue() case final map?) {
      return _Map(
        Map.fromEntries(
          map.entries
              .map((e) => MapEntry(e.key!, e.value!))
              .toList(growable: false),
        ),
      );
    }

    if (dartObject.toSymbolValue() != null) {
      throw UnsupportedError('Symbol literals are not supported.');
    }

    return _Unknown(dartObject);
  }

  Object? get value;
}

class _Null implements _DartObjectTypes {
  const _Null();
  @override
  Null get value => null;
}

class _Variable implements _DartObjectTypes {
  _Variable(this.value);
  @override
  final VariableElement value;
}

class _String implements _DartObjectTypes {
  _String(this.value);
  @override
  final String value;
}

class _Int implements _DartObjectTypes {
  _Int(this.value);
  @override
  final int value;
}

class _Bool implements _DartObjectTypes {
  _Bool({required this.value});
  @override
  final bool value;
}

class _Double implements _DartObjectTypes {
  _Double(this.value);
  @override
  final double value;
}

class _Record implements _DartObjectTypes {
  _Record(this.value);
  @override
  final ({List<DartObject> positional, Map<String, DartObject> named}) value;
}

class _List implements _DartObjectTypes {
  _List(this.value);
  @override
  final List<DartObject> value;
}

class _Set implements _DartObjectTypes {
  _Set(this.value);
  @override
  final Set<DartObject> value;
}

class _Map implements _DartObjectTypes {
  _Map(this.value);
  @override
  final Map<DartObject, DartObject> value;
}

class _Type implements _DartObjectTypes {
  _Type(this.value);
  @override
  final DartType value;
}

class _Unknown implements _DartObjectTypes {
  _Unknown(this.value);
  @override
  final DartObject value;
}

extension on Revivable {
  String toCode({
    required bool addLeadingConst,
  }) {
    final identifierCode = _typeCode();

    if (!source.hasFragment) {
      // function variables have an URI with no fragment but an accessor.
      return identifierCode;
    } else {
      final maybeConst = addLeadingConst ? 'const ' : '';

      // Object variables have an URI with a fragment and and optionally accessor.

      final buffer = StringBuffer();

      buffer.write(maybeConst);
      buffer.write(identifierCode);

      // If no fragment, we used the accessor as the name of the symbol.
      // If present, we use the accessor as named constructor or getter.
      if (accessor.isNotEmpty) buffer.write('.$accessor');

      buffer.write('(');
      var index = 0;
      for (final arg in positionalArguments) {
        if (index > 0) buffer.write(', ');
        index++;
        buffer.write(arg.toCode(addLeadingConst: false));
      }
      for (final entry in namedArguments.entries) {
        if (index > 0) buffer.write(', ');
        index++;
        buffer.write(
          '${entry.key}: ${entry.value.toCode(addLeadingConst: false)}',
        );
      }
      buffer.write(')');

      return buffer.toString();
    }
  }

  String _typeCode() {
    final typeName = source.hasFragment ? source.fragment : accessor;
    final uri = source.removeFragment();

    return '#{{$uri|$typeName}}';
  }
}
