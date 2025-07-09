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
