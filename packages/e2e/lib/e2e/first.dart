// ignore_for_file: avoid_relative_lib_imports, prefer_relative_imports

import 'package:e2e/annotation.dart';
import 'package:e2e/e2e/d.dart' as package_prefix;
import 'package:e2e/e2e/e2.dart' as package_reexport;

import '../e2e/b.dart' as not_normalized_path_prefix;
import 'a.dart' as prefix;
import 'c.dart' as direct_path_prefix;
import 'f2.dart' as relative_reexport;

part 'first.g.dart';

class Foo {
  const Foo();
}

@E2E()
void fn([Object value = const Foo()]) {}

@E2E()
void prefixToRelativePath([
  Object value = const prefix.A(),
  Object value2 = const not_normalized_path_prefix.B(),
  Object value3 = const direct_path_prefix.C(),
  Object value4 = const package_prefix.D(),
  Object value5 = const package_reexport.E(),
  Object value6 = const relative_reexport.F(),
]) {}
