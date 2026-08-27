# camelcase

[![CI](https://github.com/thelastbackspace/zig-camelcase/actions/workflows/ci.yml/badge.svg)](https://github.com/thelastbackspace/zig-camelcase/actions/workflows/ci.yml)

Convert strings to camelCase or PascalCase — with Unicode-aware case
mapping, digit handling, and acronym preservation.

```zig
const camelcase = @import("camelcase");

const a = try camelcase.camelCase(allocator, "foo-bar", .{}); // "fooBar"
const b = try camelcase.camelCase(allocator, "XMLHttpRequest", .{}); // "xmlHttpRequest"
const c = try camelcase.camelCase(allocator, "розовый_пушистый", .{}); // "розовыйПушистый"
// Caller owns the returned memory.
```

Word boundaries are `_`, `.`, `-`, and space — and case transitions:
`fooIDs` → `fooIds`, `FOOBar` → `fooBar`. Leading `_` and `$` are kept
(`_foo_bar` → `_fooBar`), whitespace is trimmed, and input that is
entirely separators yields an empty string.

## Installation

Requires Zig 0.16.0.

```sh
zig fetch --save git+https://github.com/thelastbackspace/zig-camelcase#v1.0.0
```

Then in `build.zig`:

```zig
const camelcase = b.dependency("camelcase", .{ .target = target, .optimize = optimize });
exe.root_module.addImport("camelcase", camelcase.module("camelcase"));
```

## API

### `camelCase(allocator, input: []const u8, options: Options) ![]u8`

Convert one string. Caller owns the returned memory.

### `camelCaseMany(allocator, inputs: []const []const u8, options: Options) ![]u8`

Convert several strings into one identifier, as if joined with `-`.
Empty and whitespace-only elements are dropped, and each element is
trimmed first: `["foo", "-bar"]` → `fooBar`.

### `Options`

- `pascal_case: bool = false` — `FooBar` instead of `fooBar`.
- `preserve_consecutive_uppercase: bool = false` — keep runs of
  uppercase: `foo-BAR` → `fooBAR`.
- `capitalize_after_number: bool = true` — `foo2bar` → `foo2Bar`. When
  `false`, numbers do not start a new word (Google Java Style Guide):
  `foo2bar` stays `foo2bar`, and the letter's original case is kept
  (`Textures_3D` → `textures3D`).
- `locale: Locale = .default` — `.turkic` applies the Turkish/
  Azerbaijani dotted-i rules (`lorem-ipsum` → `loremİpsum`).

## Notes

- Case mapping uses simple Unicode mappings (Unicode 16.0.0) generated
  into `src/unicode_data.zig`. Multi-character mappings such as
  `ß` → `SS` are not applied; the simple mapping (`ß` → `ẞ`) is.
- Text is processed by Unicode code point, not UTF-16 unit, which can
  differ for astral-plane input in rare edge cases.
- Input is expected to be valid UTF-8; invalid bytes are passed through
  unchanged.

## Testing

```sh
zig build test
```

The suite is a port of the upstream project's own test file — about 250
assertions covering separators, acronyms, digits, Unicode (Latin,
Cyrillic, CJK, Arabic, Hebrew, emoji), locales, and option
combinations. Two upstream tests have no Zig equivalent (a TypeError
for non-string input, and mocking of JavaScript Intl internals).

## Contributing

PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md). The CI gate
(`zig fmt --check`, tests, build) must pass.

## Credits

Behavior and the test suite follow the npm package
[`camelcase`](https://github.com/sindresorhus/camelcase) v9.0.0 (MIT,
© Sindre Sorhus); the implementation is original, and the Unicode
tables are generated from the Unicode Character Database 16.0.0. Zig
implementation © 2026 thelastbackspace, MIT — see [LICENSE](LICENSE).
