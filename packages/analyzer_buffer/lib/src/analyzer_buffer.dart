// ignore_for_file: deprecated_member_use

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path;

import 'analyzer_buffer.dart';
import 'revive.dart';

/// Converts a [DartType] into a `#{{uri|type}}` representation.
extension CodeFor2 on DartType {
  (Uri, String) get _metaFor {
    switch (this) {
      case VoidType():
        return (Uri.parse('dart:core'), 'void');
      case DynamicType():
        return (Uri.parse('dart:core'), 'dynamic');
      case NeverType():
        return (Uri.parse('dart:core'), 'Never');
      case InvalidType():
        return (Uri.parse('dart:core'), 'InvalidType');
      default:
        final element = element3;
        if (element == null) {
          throw ArgumentError('Type $this does not have an element');
        }

        final library = element.library2;
        if (library == null) {
          throw ArgumentError('Type $this does not have a library');
        }
        final name3 = element.name3;
        if (name3 == null) {
          throw ArgumentError('Type $this does not have a name');
        }

        return (library.uri, name3);
    }
  }

  /// Converts a [DartType] into a `#{{uri|type}}` representation.
  ///
  /// This string can then be used with [AnalyzerBuffer.write] to interpolate the
  /// element's code into a generated file.
  ///
  /// If [recursive] is true (default), it will also write the type arguments
  /// of the type, if any. Otherwise, it will only write the type name.
  /// This only impacts parameterized types, such as `List<int>`. It has no
  /// effect on other types, such as `(int, )` and function types.
  String toCode({bool recursive = true}) {
    final that = this;

    String result;
    if (that.alias case final alias?) {
      final uri = alias.element2.library2.uri;
      final name = alias.element2.name3;
      result = '#{{$uri|$name}}';

      if (recursive && alias.typeArguments.isNotEmpty) {
        final args = alias.typeArguments
            .map((e) => e.toCode(recursive: recursive))
            .join(', ');
        result += '<$args>';
      }
    } else if (element3 == null) {
      switch (that) {
        case InvalidType():
          throw InvalidTypeException();
        case VoidType():
          result = '#{{dart:core|void}}';
        case DynamicType():
          result = '#{{dart:core|dynamic}}';
        case NeverType():
          result = '#{{dart:core|Never}}';
        case RecordType():
          final buffer = StringBuffer('(');

          for (final (index, field) in that.positionalFields.indexed) {
            if (index > 0) buffer.write(' ');
            buffer.write('${field.type.toCode()},');
          }

          if (that.namedFields.isNotEmpty) {
            if (that.positionalFields.isNotEmpty) buffer.write(' ');
            buffer.write('{');

            for (final (index, field) in that.namedFields.indexed) {
              if (index > 0) buffer.write(' ');
              buffer.write('${field.type.toCode()} ${field.name},');
            }
            buffer.write('}');
          }

          buffer.write(')');
          result = buffer.toString();
        case FunctionType():
          final buffer = StringBuffer();
          buffer.write(that.returnType.toCode());
          buffer.write(' Function(');

          final requiredPositionals =
              that.formalParameters.where((e) => e.isRequiredPositional);
          final optionalPositionals =
              that.formalParameters.where((e) => e.isOptionalPositional);
          final named = that.formalParameters.where((e) => e.isNamed);

          for (final (index, param) in requiredPositionals.indexed) {
            if (index > 0) buffer.write(', ');
            buffer.write(param.type.toCode());
            final name = param.name3;
            if (name != null && name.isNotEmpty) buffer.write(' $name');
          }

          if (optionalPositionals.isNotEmpty) {
            if (requiredPositionals.isNotEmpty) buffer.write(', ');
            buffer.write('[');
            for (final (index, param) in optionalPositionals.indexed) {
              if (index > 0) buffer.write(', ');
              buffer.write(param.type.toCode());
              final name = param.name3;
              if (name != null && name.isNotEmpty) buffer.write(' $name');
            }
            buffer.write(']');
          }

          if (named.isNotEmpty) {
            if (requiredPositionals.isNotEmpty ||
                optionalPositionals.isNotEmpty) {
              buffer.write(', ');
            }
            buffer.write('{');
            for (final (index, param) in named.indexed) {
              if (index > 0) buffer.write(', ');
              if (param.isRequired) buffer.write('required ');
              buffer.write(param.type.toCode());
              final name = param.name3;
              if (name != null && name.isNotEmpty) buffer.write(' $name');
            }
            buffer.write('}');
          }

          buffer.write(')');

          result = buffer.toString();

        case _:
          throw UnsupportedError('Unknown type $this');
      }
    } else {
      final (uri, name3) = that._metaFor;
      final nameCode = '#{{$uri|$name3}}';
      switch (that) {
        case ParameterizedType()
            when recursive && that.typeArguments.isNotEmpty:
          final argsCode = that.typeArguments
              .map((e) => e.toCode(recursive: recursive))
              .join(', ');
          result = '$nameCode<$argsCode>';
        case _:
          result = nameCode;
      }
    }

    if (nullabilitySuffix == NullabilitySuffix.question) {
      return '$result?';
    }

    return result;
  }
}

/// An exception that is thrown when a type is invalid and cannot be converted to code.
final class InvalidTypeException implements Exception {
  @override
  String toString() {
    return 'InvalidTypeException: The type is invalid and cannot be converted to code.';
  }
}

class _SyntheticImport {
  _SyntheticImport({required this.uri, required this.prefix});

  final _CanonicalizedUri uri;
  final String prefix;
}

class _TargetNamespace {
  _TargetNamespace(
    LibraryElement2 library, {
    required this.generatedFile,
  }) : _fragment = library.firstFragment;

  _TargetNamespace.empty({
    required this.generatedFile,
  }) : _fragment = null;

  final LibraryFragment? _fragment;
  final List<_SyntheticImport> syntheticImports = [];
  final _GeneratedFileLocation generatedFile;

  ({String? prefix})? findSymbol(_CanonicalizedUri uri, String symbol) {
    if (uri == _dartCoreUri || _currentFileUri == uri) return (prefix: null);

    final syntheticImport =
        syntheticImports.where((e) => e.uri == uri).firstOrNull;
    if (syntheticImport != null) return (prefix: syntheticImport.prefix,);

    if (_fragment case final fragment?) {
      for (final import in fragment.libraryImports2) {
        if (import.namespace.definedNames2.containsKey(symbol)) {
          return (prefix: import.prefix2?.name2,);
        }
      }
    }

    return null;
  }

  _CanonicalizedUri get _dartCoreUri =>
      _CanonicalizedUri._(Uri.parse('dart:core'));
  _CanonicalizedUri get _currentFileUri => _CanonicalizedUri.fromImportUri(
        generatedFile: generatedFile,
        Uri(
          scheme: 'asset',
          path: path.joinAll([
            generatedFile._packageName,
            path.normalize(generatedFile._path),
          ]),
        ),
      );

  ({String? prefix}) import(_CanonicalizedUri uri, String symbol) {
    final import = findSymbol(uri, symbol);
    if (import != null) return import;

    final prefix = '_i${syntheticImports.length + 1}';
    syntheticImports.add(
      _SyntheticImport(uri: uri, prefix: prefix),
    );
    return (prefix: prefix,);
  }
}

/// Information about the generated file.
final class _GeneratedFileLocation {
  /// A manually defined location of the generated file.
  ///
  /// [path] should be relative to the package root, such as `lib/generated/file.dart`.
  /// [packageName] should be the name of the package where the file is located.
  _GeneratedFileLocation({
    required String packageName,
    required String path,
  })  : _path = path,
        _packageName = packageName;

  factory _GeneratedFileLocation._relativeTo(Uri uri) {
    switch (uri) {
      case Uri(scheme: != 'package' && != 'asset'):
        throw ArgumentError(
          'GeneratedFileLocation required a package/asset URI but got: $uri',
        );
      case Uri(
          scheme: 'package',
          pathSegments: [final packageName, ...final other]
        ):
        return _GeneratedFileLocation(
          packageName: packageName,
          path: path.joinAll(['lib', ...other]),
        );
      case Uri(
          scheme: 'asset',
          pathSegments: [final packageName, ...final other]
        ):
        return _GeneratedFileLocation(
          packageName: packageName,
          path: path.joinAll(other),
        );
      case _:
        throw ArgumentError(
          'Badly formatted URI: $uri',
        );
    }
  }

  final String _packageName;
  final String _path;

  late final uri = Uri(
    scheme: 'asset',
    path: '$_packageName/${path.normalize(_path)}',
  );
}

@immutable
class _CanonicalizedUri {
  const _CanonicalizedUri._(this.uri);

  factory _CanonicalizedUri.fromCode(
    Uri input, {
    required _GeneratedFileLocation generatedFile,
  }) {
    var uri = input;
    if (!uri.hasScheme) uri = uri.replace(scheme: 'package');

    switch (uri) {
      case Uri(scheme: 'file' || 'dart'):
        break;
      case Uri(
          scheme: 'asset',
          pathSegments: [final packageName, final firstSegment, ...final rest]
        ):
        if (packageName != generatedFile._packageName) {
          if (firstSegment != 'lib') {
            throw ArgumentError(
              'Asset URI $uri does not match the package name ${generatedFile._packageName}',
            );
          }

          uri = uri.replace(
            scheme: 'package',
            pathSegments: [packageName, ...rest],
          );
        }

      case Uri(scheme: 'package', pathSegments: [final segment]):
        uri = uri.replace(pathSegments: [segment, '$segment.dart']);
      case Uri(scheme: 'package', pathSegments: [...final rest, final last])
          when !last.endsWith('.dart'):
        uri = uri.replace(pathSegments: [...rest, '$last.dart']);
      case Uri(scheme: 'package'):
        break;
      case _:
        throw UnsupportedError('Unsupported URI: $uri');
    }

    return _CanonicalizedUri.fromImportUri(
      uri,
      generatedFile: generatedFile,
    );
  }

  factory _CanonicalizedUri.fromLibrary2(
    LibraryElement2 element, {
    required _GeneratedFileLocation generatedFile,
  }) {
    final uri = element.uri;
    if (uri.scheme != 'package' &&
        uri.scheme != 'asset' &&
        uri.scheme != 'dart') {
      throw ArgumentError(
        'Expected a package/asset/dart URI, but got: $uri',
      );
    }

    return _CanonicalizedUri.fromImportUri(
      uri,
      generatedFile: generatedFile,
    );
  }

  factory _CanonicalizedUri.fromImportUri(
    Uri uri, {
    required _GeneratedFileLocation generatedFile,
  }) {
    switch (uri) {
      // import 'dir/file.dart' -> 'asset:package_name/path_to_generated/../dir/file.dart'
      case Uri(hasScheme: false):
        uri = uri.replace(
          scheme: 'asset',
          path: path.join(path.dirname(generatedFile._path), uri.path),
        );
      // import 'package:package_name/dir/file.dart' -> 'asset:package_name/lib/dir/file.dart'
      case Uri(
            scheme: 'package',
            pathSegments: [final packageName, ...final rest]
          )
          when packageName == generatedFile._packageName:
        uri = uri.replace(
          scheme: 'asset',
          path: path.joinAll([packageName, 'lib', ...rest]),
        );
    }

    return _CanonicalizedUri._(uri.replace(path: path.normalize(uri.path)));
  }

  Uri toImportUri({
    required _GeneratedFileLocation generatedFile,
  }) {
    switch (uri) {
      // asset:package_name/lib/dir/file.dart -> ./dir/file.dart
      case Uri(
          scheme: 'asset',
          pathSegments: [final packageName, ...final rest]
        ):
        if (packageName != generatedFile._packageName) {
          throw ArgumentError(
            'Asset URI $uri does not match the package name ${generatedFile._packageName}',
          );
        }
        return Uri.parse(
          path.normalize(
            path.relative(
              path.joinAll(rest),
              from: path.dirname(generatedFile._path),
            ),
          ),
        );
      case _:
        return uri;
    }
  }

  final Uri uri;

  @override
  bool operator ==(Object other) {
    if (other is! _CanonicalizedUri) return false;
    return uri == other.uri;
  }

  @override
  int get hashCode => uri.hashCode;

  @override
  String toString() {
    return '$_CanonicalizedUri($uri)';
  }
}

/// A String buffer that is used to generate Dart code.
///
/// It helps deal with common problems such as:
/// - Writing types while respecting import prefixes and typedefs
/// - Automatically adding imports, if writing to a standalone library
///
/// It is primarily used with [write], as it enables writing code in plain
/// strings, and interpolating types to still support prefixes and co.
///
/// Alternatively, you can write code "as usual" by using the [writeType] method,
/// combined with passing non-interpolated strings to [write].
class AnalyzerBuffer {
  AnalyzerBuffer._({
    required _GeneratedFileLocation generatedFile,
    required _TargetNamespace namespace,
    required this.header,
    required bool autoImport,
  })  : _generatedFile = generatedFile,
        _namespace = namespace,
        _autoImport = autoImport;

  /// Creates a [AnalyzerBuffer] that generates a brand new library.
  ///
  /// When writing types, [AnalyzerBuffer] will automatically add the necessary imports
  /// to the generated code.
  ///
  /// [packageName] is the name of the package where the generated file will be located.
  /// [path] is the path of the generated file, relative to the package root (e.g. `lib/src/file.dart`).
  AnalyzerBuffer.newLibrary({
    required String packageName,
    required String path,
    this.header,
  })  : _generatedFile = _GeneratedFileLocation(
          packageName: packageName,
          path: path,
        ),
        _namespace = _TargetNamespace.empty(
          generatedFile: _GeneratedFileLocation(
            packageName: packageName,
            path: path,
          ),
        ),
        _autoImport = true;

  /// Creates a [AnalyzerBuffer] that generates code for a specific [library].
  ///
  /// This will not automatically import missing libraries.
  /// Instead, it will rely on the existing imports to decide which prefix to use
  /// when writing types.
  factory AnalyzerBuffer.part(
    LibraryElement library, {
    String? header,
  }) {
    return AnalyzerBuffer.part2(
      library,
      header: header,
    );
  }

  /// Creates a [AnalyzerBuffer] that generates code for a specific [library].
  ///
  /// This will not automatically import missing libraries.
  /// Instead, it will rely on the existing imports to decide which prefix to use
  /// when writing types.
  factory AnalyzerBuffer.part2(
    LibraryElement2 library, {
    String? header,
  }) {
    final generatedFiles = _GeneratedFileLocation._relativeTo(library.uri);
    final namespace = _TargetNamespace(library, generatedFile: generatedFiles);

    return AnalyzerBuffer._(
      generatedFile: generatedFiles,
      namespace: namespace,
      header: header,
      autoImport: false,
    );
  }

  final _TargetNamespace _namespace;
  final StringBuffer _buffer = StringBuffer();

  /// Whether any write was performed on the buffer.
  ///
  /// [header] is not considered a write.
  bool get isEmpty => _buffer.isEmpty;

  /// Whether to automatically import missing libraries when writing types.
  final bool _autoImport;

  /// The path of the file that is being generated.
  final _GeneratedFileLocation _generatedFile;

  /// A header that will be added at the top of the generated code.
  final String? header;

  void Function()? Function(String name)? _lookupArg;

  ({String? prefix}) _upsertImport(_CanonicalizedUri uri, String symbol) {
    final find = _namespace.findSymbol(uri, symbol);
    if (find != null) return find;

    if (_autoImport) return _namespace.import(uri, symbol);

    throw ArgumentError(
      'Cannot find import for $symbol in $uri, and could not automatically import it.',
    );
  }

  /// Writes the given [type] to the buffer.
  ///
  /// If the buffer was created with [AnalyzerBuffer.newLibrary], it will automatically
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
      generatedFile: _generatedFile,
      onType: (library, name, suffix, args) {
        String? prefix;
        if (library != null) {
          prefix = _upsertImport(
            _CanonicalizedUri.fromLibrary2(
              library,
              generatedFile: _generatedFile,
            ),
            name,
          ).prefix;
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
  /// **Note**:
  /// Some syntax sugar for package URIs are supported.
  /// You can write:
  /// - `#{{example|Name}}`(same as `#{{package:example/example.dart|Name}}`)
  /// - `#{{example/foo|Name}}` (same as `#{{package:example/foo.dart|Name}}`)
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
  /// - [CodeFor2.toCode], to convert obtain the `#{{uri|type}}` representation
  ///   for a given [Element2].
  /// - [RevivableToSource.toCode], to convert a [DartObject] into a code representation
  void write(String code, {Map<String, void Function()> args = const {}}) {
    final prevLookup = _lookupArg;
    final lookup = _lookupArg = (name) {
      return args[name] ?? prevLookup?.call(name);
    };

    try {
      final reg = RegExp('#{{(.+?)}}');

      var previousIndex = 0;
      for (final match in reg.allMatches(code)) {
        _buffer.write(code.substring(previousIndex, match.start));
        previousIndex = match.end;

        final matchedString = match.group(1)!;
        _parseCode(
          matchedString,
          generatedFile: _generatedFile,
          onArg: (argName) {
            final arg = lookup(argName);
            if (arg == null) {
              throw ArgumentError('No argument found for $argName');
            }
            arg();
          },
          onUri: (uri, symbol) {
            final prefix = _upsertImport(uri, symbol).prefix;
            if (prefix != null) {
              _buffer.write(prefix);
              _buffer.write('.');
            }
            _buffer.write(symbol);
          },
        );
      }

      _buffer.write(code.substring(previousIndex));
    } finally {
      _lookupArg = prevLookup;
    }
  }

  @override
  String toString() {
    if (isEmpty) return '';

    return [
      '// GENERATED CODE - DO NOT MODIFY BY HAND',
      if (header != null) header,
      ..._namespace.syntheticImports.map((e) {
        final prefix = e.prefix;
        final targetUri = e.uri.toImportUri(generatedFile: _generatedFile);

        return "import '$targetUri' as $prefix;";
      }),
      _buffer,
    ].join('\n');
  }
}

void _parseCode(
  String code, {
  required void Function(String arg) onArg,
  required void Function(_CanonicalizedUri uri, String type) onUri,
  required _GeneratedFileLocation generatedFile,
}) {
  switch (code.split('|')) {
    case [final argName]:
      onArg(argName);
    case [final uriStr, final type]:
      final uri = _CanonicalizedUri.fromCode(
        Uri.parse(uriStr),
        generatedFile: generatedFile,
      );

      onUri(uri, type);
    case _:
      throw ArgumentError('Invalid argument: $code');
  }
}

extension on DartType {
  void _visit({
    required void Function(
      LibraryElement2? element,
      String name,
      NullabilitySuffix suffix,
      List<DartType> args,
    ) onType,
    required void Function(RecordType type) onRecord,
    required _GeneratedFileLocation generatedFile,
  }) {
    final alias = this.alias;
    if (alias != null) {
      onType(
        alias.element2.library2,
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

    final (_, name) = that._metaFor;
    if (that is ParameterizedType) {
      onType(
        that.element3?.library2,
        name,
        nullabilitySuffix,
        that.typeArguments,
      );
      return;
    }

    onType(
      that.element3?.library2,
      name,
      nullabilitySuffix,
      [],
    );
  }
}
