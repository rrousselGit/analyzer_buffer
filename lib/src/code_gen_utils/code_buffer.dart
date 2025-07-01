import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/dart/element/type_provider.dart';
import 'package:analyzer/dart/element/type_system.dart';
import 'package:collection/collection.dart';

bool _isShadowed(String name, List<ParameterElement> params) {
  return params.any((e) => e.name == name);
}

String classPropertyIdentifier(
  String name, {
  required List<ParameterElement> scope,
}) {
  if (_isShadowed(name, scope)) return 'this.$name';
  return name;
}

extension CodeFor on Element {
  String get code => '#{{${library!.source.uri}|$name}}';
}

class ContrailTypeProvider {
  ContrailTypeProvider({
    required this.typeSystem,
    required this.typeProvider,
  });

  final TypeSystem typeSystem;
  final TypeProvider typeProvider;

  late final futureVoid = typeProvider.futureType(typeProvider.voidType);
  late final listString = typeProvider.listType(typeProvider.stringType);
}

class CodeBuffer {
  CodeBuffer({
    this.header,
    required this.autoImport,
    this.library,
  });

  final LibraryElement? library;
  final StringBuffer _buffer = StringBuffer();
  final bool autoImport;
  final String? header;

  Iterable<LibraryElement> get _currentlyImportedLibraries {
    Iterable<LibraryElement> result = _importedLibraries;
    if (library case final library?) {
      result = result.followedBy(library.importedLibraries);
    }
    return result;
  }

  void writeClassDeclaration(
    String name, {
    void Function()? membersWriter,
  }) {
    write('class $name {');
    if (membersWriter != null) membersWriter();
    write('}');
  }

  void writeConstructorDeclaration({
    required String className,
    String? name,
    void Function()? parametersWriter,
    void Function()? bodyWriter,
  }) {
    write(className);
    if (name != null) {
      write('.$name');
    }
    write('(');
    parametersWriter?.call();
    write(')');

    if (bodyWriter != null) {
      bodyWriter();
    } else {
      write(';');
    }
  }

  void writeArgumentList(Iterable<Parameter> parameters) {
    write('(');
    writeParameterDeclarations(parameters);
    write(')');
  }

  void writeParameterDeclarations(Iterable<Parameter> parameters) {
    final namedParameters = parameters.where((e) => e.isNamed);
    final optionalPositionalParameters =
        parameters.where((e) => !e.isNamed && !e.isRequired);
    final requiredPositionalParameters =
        parameters.where((e) => !e.isNamed && e.isRequired);

    var didWrite = false;

    void writes(
      Iterable<Parameter> params, {
      (String, String)? brackets,
      void Function(Parameter param)? leading,
    }) {
      for (final param in params) {
        if (didWrite) write(', ');
        didWrite = true;

        final isFirst = param == params.first;
        final isLast = param == params.last;

        if (isFirst && brackets != null) write(brackets.$1);
        if (leading != null) leading(param);

        if (param.type case final type?) {
          writeType(type);
          write(' ');
        }
        if (param.typeWriter case final typeWriter?) {
          typeWriter();
          write(' ');
        }

        switch (param.modifier) {
          case ParameterModifier.super$:
            write('super.');
          case ParameterModifier.this$:
            write('this.');
          default:
        }

        write(param.name);

        if (param.defaultValueCode case final defaultValue?) {
          write(' = ');
          write(defaultValue);
        }

        if (isLast && brackets != null) write(brackets.$2);
      }
    }

    writes(requiredPositionalParameters);
    writes(
      optionalPositionalParameters,
      brackets: ('[', ']'),
    );
    writes(
      namedParameters,
      brackets: ('{', '}'),
      leading: (param) {
        if (param.isRequired) write('required ');
      },
    );
  }

  void writeVariableDeclaration(
    String name, {
    DartType? type,
    VariableModifier? modifier,
    void Function()? initializerWriter,
    void Function()? typeWriter,
  }) {
    switch (modifier) {
      case VariableModifier.final$:
        write('final ');
      case VariableModifier.var$:
        write('var ');
      case VariableModifier.const$:
        write('const ');
      case null:
        break;
    }

    if (type != null) {
      writeType(type);
      write(' ');
    }
    if (typeWriter != null) {
      typeWriter();
      write(' ');
    }

    write(name);

    if (initializerWriter != null) {
      write(' = ');
      initializerWriter();
    }

    writeln(';');
  }

  void writeType(
    DartType type, {
    bool recursive = true,
  }) {
    type._visit(
      onType: (element, name, suffix, args) {
        String? prefix;
        if (element != null) {
          if (autoImport)
            prefix = importElement(element);
          else
            prefix = _prefixFor(element.library!);
        }

        if (prefix != null) {
          write(prefix);
          write('.');
        }
        write(name);

        if (recursive && args.isNotEmpty) {
          write('<');
          for (final (index, arg) in args.indexed) {
            if (index != 0) write(', ');
            writeType(arg);
          }
          write('>');
        }

        switch (suffix) {
          case NullabilitySuffix.question:
            write('?');
          case NullabilitySuffix.none:
          case NullabilitySuffix.star:
        }
      },
      onRecord: (type) {
        write('(');
        for (final field in type.positionalFields) {
          writeType(field.type);
          write(',');
        }

        if (type.namedFields.isNotEmpty) {
          write(' {');
          for (final field in type.namedFields) {
            writeType(field.type);
            write(',');
          }
          write('}');
        }

        write(')');
      },
    );
  }

  /// Interpolates the given code, gracefully printing types and adding type prefixes if necessary.
  ///
  /// This works by interpolating `#{{uri|type}}` into the code.
  void writeCode(String code, {Map<String, void Function()> args = const {}}) {
    final reg = RegExp('#{{(.+?)}}');

    var previousIndex = 0;
    for (final match in reg.allMatches(code)) {
      write(code.substring(previousIndex, match.start));
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
            uri = uri.replace(pathSegments: [
              uri.pathSegments.single,
              '${uri.pathSegments.first}.dart',
            ]);
          }
          if (uri.pathSegments.length > 1 &&
              !uri.pathSegments.last.endsWith('.dart')) {
            uri = uri.replace(pathSegments: [
              ...uri.pathSegments.take(uri.pathSegments.length - 1),
              '${uri.pathSegments.last}.dart',
            ]);
          }

          if (autoImport) {
            final prefix = importLibraryUri(uri);

            if (prefix != null) {
              write(prefix);
              write('.');
            }
          }
          write(type);
        case _:
          throw ArgumentError('Invalid argument: $matchedString');
      }
    }

    write(code.substring(previousIndex));
  }

  void writeFunctionDeclaration({
    required String name,
    DartType? returnType,
    void Function()? returnTypeWriter,
    Iterable<Parameter> parameters = const [],
    required void Function() bodyWriter,
    bool isStatic = false,
  }) {
    if (isStatic) write('static ');

    if (returnType != null) {
      writeType(returnType);
      write(' ');
    }
    if (returnTypeWriter != null) {
      returnTypeWriter();
      write(' ');
    }

    write(name);
    writeArgumentList(parameters);

    bodyWriter();
  }

  void writeGetterDeclaration(
    String name, {
    DartType? returnType,
    void Function()? bodyWriter,
  }) {
    if (returnType != null) {
      writeType(returnType);
      write(' ');
    }

    write('get $name');

    if (bodyWriter != null) {
      bodyWriter();
    } else {
      write(';');
    }
  }

  List<Uri> _importedLibraryUris = [];
  String? importLibraryUri(Uri uri) {
    if (uri.scheme == 'dart' && uri.path == 'core') return null;

    final alreadyImportedLibrary = _currentlyImportedLibraries
        .where((e) => e.source.uri == uri)
        .firstOrNull;
    if (alreadyImportedLibrary != null)
      return _prefixFor(alreadyImportedLibrary);

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

  String codeIdentifierFor(Element element) {
    return '#{{${element.library!.source.uri}|${element.name}}}';
  }

  List<LibraryElement> _importedLibraries = [];
  String? importElement(Element element) {
    final library = element.library;
    // dart:core have a null library, so we don't import it.
    if (library == null) return null;

    if (library.source.uri case Uri(scheme: 'dart', path: 'core')) return null;

    if (!_importedLibraries.contains(library)) _importedLibraries.add(library);

    return _prefixFor(library);
  }

  String? _prefixFor(LibraryElement element) {
    final index = _importedLibraries.indexOf(element);
    if (index >= 0) return '_i${index + 1}';

    if (library case final library?) {
      final prefix = library.definingCompilationUnit.libraryImportPrefixes
          .expand((e) => e.imports)
          .where((e) {
            return e.importedLibrary == element;
          })
          .firstOrNull
          ?.prefix;

      return prefix?.element.name;
    }

    return null;
  }

  ///
  ///
  ///
  /// StringBuffer-like API
  ///
  ///
  ///

  var _isEmpty = true;
  bool get isEmpty => _isEmpty;

  void write(Object? object) {
    _isEmpty = false;
    _buffer.write(object);
  }

  void writeAll(Iterable objects, [String separator = ""]) {
    _isEmpty = false;
    _buffer.writeAll(objects, separator);
  }

  void writeCharCode(int charCode) {
    _isEmpty = false;
    _buffer.writeCharCode(charCode);
  }

  void writeln([Object? obj = ""]) {
    _isEmpty = false;
    _buffer.writeln(obj);
  }

  @override
  String toString() {
    return [
      '/// Generated code, do not modify',
      if (header != null) header,
      ..._importedLibraries.mapIndexed(
        (index, e) {
          final prefix = _prefixFor(e);
          if (prefix == null) return "import '${e.source.uri}';";
          return "import '${e.source.uri}' as $prefix;";
        },
      ),
      ..._importedLibraryUris.mapIndexed(
        (index, e) {
          final prefix = _prefixForUri(e);
          if (prefix == null) return "import '${e}';";
          return "import '${e}' as $prefix;";
        },
      ),
      _buffer,
    ].join('\n');
  }

  void writeExtension(
    String name, {
    required DartType on,
    void Function()? bodyWriter,
  }) {
    write('extension $name on ');
    writeType(on);
    write(' {');
    bodyWriter?.call();
    writeln('}');
  }
}

extension DartTypeX on DartType {
  bool get isJsonPrimitiveType {
    if (isDartCoreInt ||
        isDartCoreDouble ||
        isDartCoreBool ||
        isDartCoreString ||
        isDartCoreNum) return true;

    if (isDartCoreList) {
      final type = this as ParameterizedType;
      final typeArg = type.typeArguments.single;
      return typeArg.isJsonPrimitiveType;
    }

    if (isDartCoreMap) {
      final type = this as ParameterizedType;
      final keyType = type.typeArguments[0];
      final valueType = type.typeArguments[1];
      return keyType.isJsonPrimitiveType && valueType.isJsonPrimitiveType;
    }

    if (isDartCoreSet) {
      final type = this as ParameterizedType;
      final typeArg = type.typeArguments.single;
      return typeArg.isJsonPrimitiveType;
    }

    return false;
  }

  void _visit({
    required void Function(
      Element? element,
      String name,
      NullabilitySuffix suffix,
      List<DartType> args,
    ) onType,
    required void Function(RecordType type) onRecord,
  }) {
    final alias = this.alias;
    if (alias != null) {
      onType(
        alias.element,
        alias.element.name,
        this.nullabilitySuffix,
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
      _ => that.element!.name!,
    };

    if (that is ParameterizedType) {
      onType(
        that.element,
        name,
        this.nullabilitySuffix,
        that.typeArguments,
      );
      return;
    }

    onType(
      that.element,
      name,
      this.nullabilitySuffix,
      [],
    );
  }
}

enum VariableModifier {
  final$,
  var$,
  const$,
}

enum ParameterModifier {
  super$,
  this$,
}

class Parameter {
  Parameter({
    required this.name,
    this.type,
    this.typeWriter,
    required this.isNamed,
    required this.isRequired,
    this.modifier,
    this.defaultValueCode,
  });

  factory Parameter.fromElement(ParameterElement element) {
    return Parameter(
      name: element.name,
      type: element.type,
      isNamed: element.isNamed,
      isRequired: element.isRequired,
      modifier: switch (element) {
        ParameterElement(isSuperFormal: true) => ParameterModifier.super$,
        ParameterElement(isInitializingFormal: true) => ParameterModifier.this$,
        _ => null,
      },
      defaultValueCode: element.defaultValueCode,
    );
  }

  final String name;
  final DartType? type;
  final void Function()? typeWriter;
  final bool isNamed;
  final bool isRequired;
  final ParameterModifier? modifier;
  final String? defaultValueCode;
}
