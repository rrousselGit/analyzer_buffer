import '../annotation.dart';

part 'first.g.dart';

class Foo {
  const Foo();
}

@E2E()
void fn([Object value = const Foo()]) {}
