## 0.0.4

fix: correctly use prefix when an import is re-exporting an element used by generated code.

## 0.0.3

fix: `buffer.write` now correctly respects import prefixes if created using `AnalyzerBuffer.fromLibrary`

## 0.0.2

fix: `buffer.toString` now returns `''` if the buffer is empty.
feat: added `buffer.isEmpty`

## 0.0.1

Initial release
