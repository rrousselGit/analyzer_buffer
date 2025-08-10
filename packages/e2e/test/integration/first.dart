// ignore_for_file: avoid_relative_lib_imports

import 'package:e2e/annotation.dart';
import 'package:other/nested/file.dart' as other_file;

import '../../lib/e2e/../e2e/b.dart' as not_normalized_path_prefix;
import './a.dart' as prefix;
import 'c.dart' as direct_path_prefix;
import 'f2.dart' as relative_reexport;

part 'first.g.dart';

class Foo {
  const Foo();
}

@E2E()
void simpleFromTest([Object value = const Foo()]) {}

@E2E()
void prefixToRelativePath([
  Object value = const prefix.A(),
  Object value2 = const not_normalized_path_prefix.B(),
  Object value3 = const direct_path_prefix.C(),
  Object value6 = const relative_reexport.F(),
]) {}

@E2E()
void assetUri({
  Object value = const other_file.File(),
}) {}
