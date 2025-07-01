import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'revive.dart';

/// Adds [code] to [Element2].
extension CodeFor2 on Element2 {
  /// Obtains the "code" for an [Element2].
  ///
  /// This code can then be used with [CodeBuffer.write] to interpolate the
  /// element's code into a generated file.
  String get code => '#{{${library2!.uri}|$name3}}';
}

/// Adds [code] to [Element].
@Deprecated('Use Element2.code instead')
extension CodeFor on Element {
  /// Obtains the "code" for an [Element].
  ///
  /// This code can then be used with [CodeBuffer.write] to interpolate the
  /// element's code into a generated file.
  @Deprecated('Use Element2.code instead')
  String get code => '#{{${library!.source.uri}|$name}}';
}

/// A String buffer that is used to generate Dart code.
///
/// It provides methods to write Dart code.
class CodeBuffer {
  /// Creates a [CodeBuffer] that generates a brand new library.
  ///
  /// When writing types, [CodeBuffer] will automatically add the necessary imports
  /// to the generated code.
  CodeBuffer.newLibrary({
    this.header,
  })  : library = null,
        _autoImport = true;

  /// Creates a [CodeBuffer] that generates code for a specific [library].
  ///
  /// This will not automatically import missing libraries.
  /// Instead, it will rely on the existing imports to decide which prefix to use
  /// when writing types.
  CodeBuffer.fromLibrary(
    LibraryElement2 this.library, {
    this.header,
  }) : _autoImport = false;

  /// The associated library, if any.
  final LibraryElement2? library;
  final StringBuffer _buffer = StringBuffer();

  /// Whether to automatically import missing libraries when writing types.
  final bool _autoImport;

  /// A header that will be added at the top of the generated code.
  final String? header;

  Iterable<LibraryElement2> get _currentlyImportedLibraries {
    Iterable<LibraryElement2> result = _importedLibraries;
    if (library case final library?) {
      result = result.followedBy(
        library.fragments.expand((e) => e.importedLibraries2),
      );
    }
    return result;
  }

  /// Writes the given [type] to the buffer.
  ///
  /// If the buffer was created with [CodeBuffer.newLibrary], it will automatically
  /// import the necessary libraries to write the type.
  ///
  /// [recursive] (true by default) controls whether the type arguments of the type should also
  /// be written. If true, will write the type name and its type arguments.
  /// Otherwise, it will only write the type name.
  void writeType(
    DartType type, {
    bool recursive = true,
  }) {
    type._visit(
      onType: (element, name, suffix, args) {
        String? prefix;
        if (element != null) {
          if (_autoImport) {
            prefix = _importElement(element);
          } else {
            prefix = _prefixFor(element.library2!);
          }
        }

        if (prefix != null) {
          _buffer.write(prefix);
          _buffer.write('.');
        }
        _buffer.write(name);

        if (recursive && args.isNotEmpty) {
          _buffer.write('<');
          for (final (index, arg) in args.indexed) {
            if (index != 0) _buffer.write(', ');
            writeType(arg);
          }
          _buffer.write('>');
        }

        switch (suffix) {
          case NullabilitySuffix.question:
            _buffer.write('?');
          case NullabilitySuffix.none:
          case NullabilitySuffix.star:
        }
      },
      onRecord: (type) {
        _buffer.write('(');
        for (final field in type.positionalFields) {
          writeType(field.type);
          _buffer.write(',');
        }

        if (type.namedFields.isNotEmpty) {
          _buffer.write(' {');
          for (final field in type.namedFields) {
            writeType(field.type);
            _buffer.write(',');
          }
          _buffer.write('}');
        }

        _buffer.write(')');
      },
    );
  }

  /// Interpolates the given code, gracefully printing types and adding type prefixes if necessary.
  ///
  /// This works by interpolating `#{{uri|type}}` into the code.
  /// A typical usage would be:
  ///
  /// ```dart
  /// codeBuffer.write('''
  ///   void main() {
  ///     final controller = #{{dart:async|StreamController}}<int>();
  ///   }
  /// ''');
  /// ```
  ///
  /// The buffer will then interpolate the `#{{uri|type}}` and use relevant imports to write
  /// the code.
  ///
  /// As such, the generated code may look like:
  ///
  /// ```dart
  /// import 'dart:async' as _i1;
  ///
  /// void main() {
  ///   final controller = _i1.StreamController<int>();
  /// }
  /// ```
  ///
  /// [args] can optionally be provided to insert custom 'write' operations
  /// at specific places in the code. It relies by inserting `#{{name}}` in the
  /// code, and then looking up corresponding keys within [args].
  /// It is commonly used in conjunction with [writeType] or other [write] calls,
  /// such as to write code conditionally or on a loop:
  ///
  /// ```dart
  /// codeBuffer.write(args: {
  ///   'properties': () {
  ///      for (final property in [...]) {
  ///        codeBuffer.write('final ${property.name} = ${property.code};');
  ///      }
  ///   },
  /// }, '''
  /// class Generated extends #{{package:flutter/widgets|StatelessWidget}} {
  ///   #{{properties}}
  /// }
  /// ''');
  /// ```
  ///
  /// See also:
  /// - [CodeFor2.code], to convert obtain the `#{{uri|type}}` representation
  ///   for a given [Element2].
  /// - [RevivableToSource.toCode], to convert a [DartObject] into a code representation
  void write(String code, {Map<String, void Function()> args = const {}}) {
    final reg = RegExp('#{{(.+?)}}');

    var previousIndex = 0;
    for (final match in reg.allMatches(code)) {
      _buffer.write(code.substring(previousIndex, match.start));
      previousIndex = match.end;

      final matchedString = match.group(1)!;
      switch (matchedString.split('|')) {
        case [final argName]:
          final arg = args[argName];
          if (arg == null) {
            throw ArgumentError('No argument found for $argName');
          }
          arg();

        case [final uriStr, final type]:
          var uri = Uri.parse(uriStr);
          if (!uri.hasScheme) {
            uri = uri.replace(scheme: 'package');
          }
          if (uri.scheme != 'dart' && uri.pathSegments.length == 1) {
            uri = uri.replace(
              pathSegments: [
                uri.pathSegments.single,
                '${uri.pathSegments.first}.dart',
              ],
            );
          }
          if (uri.pathSegments.length > 1 &&
              !uri.pathSegments.last.endsWith('.dart')) {
            uri = uri.replace(
              pathSegments: [
                ...uri.pathSegments.take(uri.pathSegments.length - 1),
                '${uri.pathSegments.last}.dart',
              ],
            );
          }

          if (_autoImport) {
            final prefix = _importLibraryUri(uri);

            if (prefix != null) {
              _buffer.write(prefix);
              _buffer.write('.');
            }
          }
          _buffer.write(type);
        case _:
          throw ArgumentError('Invalid argument: $matchedString');
      }
    }

    _buffer.write(code.substring(previousIndex));
  }

  final List<Uri> _importedLibraryUris = [];
  String? _importLibraryUri(Uri uri) {
    if (uri.scheme == 'dart' && uri.path == 'core') return null;

    final alreadyImportedLibrary =
        _currentlyImportedLibraries.where((e) => e.uri == uri).firstOrNull;
    if (alreadyImportedLibrary != null) {
      return _prefixFor(alreadyImportedLibrary);
    }

    final index = _importedLibraryUris.indexOf(uri);
    if (index >= 0) return _prefixForUri(uri);

    _importedLibraryUris.add(uri);
    return _prefixForUri(uri);
  }

  String? _prefixForUri(Uri uri) {
    final index = _importedLibraryUris.indexOf(uri);
    if (index >= 0) return '_u${index + 1}';

    return null;
  }

  final List<LibraryElement2> _importedLibraries = [];
  String? _importElement(Element2 element) {
    final library = element.library2;
    // dart:core have a null library, so we don't import it.
    if (library == null) return null;

    if (library.uri case Uri(scheme: 'dart', path: 'core')) return null;

    if (!_importedLibraries.contains(library)) _importedLibraries.add(library);

    return _prefixFor(library);
  }

  String? _prefixFor(LibraryElement2 element) {
    final index = _importedLibraries.indexOf(element);
    if (index >= 0) return '_i${index + 1}';

    if (library case final library?) {
      final prefix = library.fragments
          .expand((e) => e.prefixes)
          .expand((e) => e.imports)
          .where((e) {
            return e.importedLibrary2 == element;
          })
          .firstOrNull
          ?.prefix2;

      return prefix?.element.name3;
    }

    return null;
  }

  @override
  String toString() {
    return [
      '/// Generated code, do not modify',
      if (header != null) header,
      ..._importedLibraries.mapIndexed(
        (index, e) {
          final prefix = _prefixFor(e);
          if (prefix == null) return "import '${e.uri}';";
          return "import '${e.uri}' as $prefix;";
        },
      ),
      ..._importedLibraryUris.mapIndexed(
        (index, e) {
          final prefix = _prefixForUri(e);
          if (prefix == null) return "import '$e';";
          return "import '$e' as $prefix;";
        },
      ),
      _buffer,
    ].join('\n');
  }
}

extension on DartType {
  void _visit({
    required void Function(
      Element2? element,
      String name,
      NullabilitySuffix suffix,
      List<DartType> args,
    ) onType,
    required void Function(RecordType type) onRecord,
  }) {
    final alias = this.alias;
    if (alias != null) {
      onType(
        alias.element2,
        alias.element2.name3!,
        nullabilitySuffix,
        alias.typeArguments,
      );
      return;
    }

    final that = this;
    if (that is RecordType) {
      onRecord(that);
      return;
    }

    final name = switch (that) {
      VoidType() => 'void',
      DynamicType() => 'dynamic',
      NeverType() => 'Never',
      _ => that.element3!.name3!,
    };

    if (that is ParameterizedType) {
      onType(
        that.element3,
        name,
        nullabilitySuffix,
        that.typeArguments,
      );
      return;
    }

    onType(
      that.element3,
      name,
      nullabilitySuffix,
      [],
    );
  }
}
