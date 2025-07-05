import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/element/element2.dart';
import 'package:path/path.dart' as path;
import 'package:test/test.dart';

extension FileX on FileSystemEntity {
  File file(String a, [String? b, String? c, String? d]) {
    return File(path.normalize(path.join(this.path, a, b, c, d)));
  }

  File get pubspec => file('pubspec.yaml');
}

Directory tempDir() {
  final dir = Directory(path.join(Directory.current.path, '.dart_tool'))
      .createTempSync('code_buffer_test_');
  addTearDown(() {
    dir.deleteSync(recursive: true);
  });

  return dir;
}

extension ImportedElementWithName on ResolvedUnitResult {
  Element2? importedElementWithName(String name) {
    return libraryFragment.importedLibraries2
        .map((e) => e.exportNamespace.get2(name))
        .nonNulls
        .singleOrNull;
  }
}

Future<ResolvedUnitResult> resolveFiles(
  String source, {
  String path = '.',
  Map<String, String> files = const {},
}) async {
  final project = tempDir();
  project.pubspec
    ..createSync(recursive: true)
    ..writeAsStringSync('''
name: temp_test
publish_to: none
environment:
  sdk: ^3.5.0

dependencies:
  path: ^1.8.0
''');

  for (final entry in files.entries) {
    project.file('lib', path, entry.key)
      ..createSync(recursive: true)
      ..writeAsStringSync(entry.value);
  }

  final main = project.file('lib', path, 'main.dart')
    ..createSync(recursive: true)
    ..writeAsStringSync(source);

  await pubGet(project);

  final result = await resolveFile2(path: main.absolute.path);
  result as ResolvedUnitResult;

  return result;
}

Future<void> pubGet(Directory project) async {
  await runProcess(
    'dart',
    ['pub', 'get'],
    workingDirectory: project,
  );
}

Future<void> runProcess(
  String executable,
  List<String> arguments, {
  required Directory workingDirectory,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory.path,
    stderrEncoding: utf8,
    stdoutEncoding: utf8,
    runInShell: true,
  );

  if (result.exitCode != 0) {
    throw Exception(
      'Process failed with exit code ${result.exitCode}:\n'
      '${result.stdout}\n${result.stderr}',
    );
  }
}

Matcher matchesIgnoringPrefixes(Object expected) {
  final matcher = expected is Matcher ? expected : equals(expected);

  return predicate<String>(
    (actual) {
      return matcher.matches(
        actual.replaceAll(RegExp('_.[0-9]+'), '_0'),
        {},
      );
    },
    'Matches matcher',
  );
}
