# Welcome to AnalyzerBuffer!

**AnalyzerBuffer** is a package designed for code-generator authors. It helps solving common complex tasks,
such as:

- Gracefully supporting import prefixes (`import ... as prefix`)
- Copy-pasting default values to the generated code, whatever they are
- Writing types while preserving typedefs
- Automatically adding imports (if writing to a file where imports can be added)

All while offering a simple template-based syntax.

TL;DR:

```dart
// A typical "Generator" from source_gen
class MyBuilder extends GeneratorForAnnotation<AnnotationT> {
  @override
  Future<String> generate(
    LibraryReader library,
    BuildStep buildStep,
  ) async {
    // We create a 'AnalyzerBuffer'
    final buffer = AnalyzerBuffer.part(library.element);

    // We write some code in the buffer
    // We use #{{package:packageName/file.dart|Class}} inside the source
    // to reference objects defined in other files
    buffer.write('''
    class Example {
      // Dart package imports
      final #{{dart:async|StreamController}} controller;
      // Third-party package imports:
      final #{{package:riverpod/riverpod.dart|Provider}} provider;
      // Simplified syntax for packages:
      final #{{riverpod|Provider}} provider;
    }
    ''');

    // We convert the buffer into a String
    return buffer.toString();
  }
}
```

Using this syntax, generated code will automatically use import prefixes as
defined by the user.

See [AnalyzerBuffer](https://pub.dev/documentation/analyzer_buffer/latest/analyzer_buffer/AnalyzerBuffer-class.html) for the full list of methods available.

### Dynamic content and loops

`AnalyzerBuffer.write` supports a custom String interpolation, for the sake of
passing non-static content.

The syntax is `#{{name}}` (without a package name), followed by passing
an `args` map:

```dart
buffer.write(args: {
  'DOCS': () {
    for (var i = 0; i < 10; i++)
      buffer.write('// Hello $i\n');
  }
}, '''
class Example {
  #{{DOCS}}
}
''');
```

### Writing DartTypes

`AnalyzerBuffer` offers a [writeType](https://pub.dev/documentation/analyzer_buffer/latest/analyzer_buffer/AnalyzerBuffer/writeType.html) method.
This method enables writing a `DartType` from `analyzer` directly into the generated code:

```dart
ClassElement element;

buffer.writeType(element.thisType);
```

Alternatively, you can convert any `DartType` into its `#{{uri|name}}` representation
using `DartType.toCode`:

```dart
ClassElement element;

buffer.write('''
${element.thisType.toCode()}
''');
```

### Writing default values

A common pattern with code-generators is to have to "copy-paste" default values
from user code into generated code.

For example, a user may define:

```dart
@riverpod
List<Item> fetch(Ref ref, {
  int pageSize = 10,
}) {}
```

And generated code may want to generate copy-paste that `= 10` somewhere
in the generated code, while preserving import prefixes but also
supporting enums and such.

To solve this, AnalyzerBuffer offers `DartObject.toCode()`, to convert
any constant value into its `#{{uri|name}}` representation.

A typical usage is:

```dart
ParameterElement parameter;
// Obtain the constant for the default value of a parameter
final obj = parameter.computeConstantValue();

// We generate code with the same default value
buffer.write('''
void example({
  int pageSize = ${obj.toCode()}
}) {}
''')
```
