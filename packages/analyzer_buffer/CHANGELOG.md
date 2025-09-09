## 0.1.11 - 2025-09-09

Updated dependencies to support analyzer v8
This allows for compatibility with upgraded generators using analyzer v8 and source_gen v4
  (thanks to @TekExplorer)

- `analyzer: '>=7.3.0 <9.0.0'`
- `source_gen: '>=3.0.0 <5.0.0'`

## 0.1.10 - 2025-08-26

- Fix some issue with `functionType.toCode` not including `required`
  (thanks to @TekExplorer)

## 0.1.9 - 2025-08-11

- Fix some bug with indirectly imported objects.

## 0.1.8 - 2025-08-11

- Fix `DartType.toCode` with nullable types

## 0.1.7 - 2025-08-11

- Fixed `DartType.toCode` with typedefs, records, and many other types.

## 0.1.6 - 2025-08-10

- Fixed a bug when importing nested files from other packages

## 0.1.5 - 2025-07-22

- Fix `DartType.toCode` with dynamic/invalid types.

## 0.1.4 - 2025-07-22

- Fix `writeType` with dynamic/invalid types.

## 0.1.3 - 2025-07-21

- Fix a stackoverflow when using cyclic import/export

## 0.1.2 - 2025-07-21

- Fixed auto-import incorrectly using the same prefix for all added imports.

## 0.1.1 - 2025-07-21

Upgrade dependencies

## 0.1.0 - 2025-07-21

- Removed `fromLibrary` in favour of `part`/`part2`.
- Fixed various issues with prefixes

## 0.0.7 - 2025-07-09

chore: Downgraded `meta`

## 0.0.6 - 2025-07-09

fix: `buffer.writeType` no-longer imports the same package multiple times.

## 0.0.5 - 2025-07-07

breaking: `AnalyzerBuffer` constructors now take a mandatory `sourcePath` parameter.
It is necessary for certain edge-cases around types/defaults.  
fix: Fixes an issue where `AnalyzerBuffer` could not be applied to `test` folders.

## 0.0.4

fix: correctly use prefix when an import is re-exporting an element used by generated code.

## 0.0.3

fix: `buffer.write` now correctly respects import prefixes if created using `AnalyzerBuffer.fromLibrary`

## 0.0.2

fix: `buffer.toString` now returns `''` if the buffer is empty.
feat: added `buffer.isEmpty`

## 0.0.1

Initial release
