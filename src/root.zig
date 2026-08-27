//! Convert strings to camelCase or PascalCase.
//!
//! A behavior-faithful Zig port of the npm package
//! [`camelcase`](https://github.com/sindresorhus/camelcase) (v9.0.0).
//! The upstream test suite is ported in `tests.zig`; see README.md for
//! API notes and the intentional divergences from upstream.

const std = @import("std");
const uni = @import("unicode_data.zig");

/// Case-mapping rules. Upstream accepts arbitrary ICU locale identifiers;
/// only the special-cased Turkic rules (Turkish/Azerbaijani dotted i)
/// actually change behavior, so those are enumerated here and everything
/// else uses the default Unicode mappings.
pub const Locale = enum {
    /// Default Unicode case mappings.
    default,
    /// Turkic rules: `i` uppercases to `İ` and `I` lowercases to `ı`.
    turkic,
};

/// Options mirroring the upstream package.
pub const Options = struct {
    /// Convert to PascalCase instead of camelCase.
    pascal_case: bool = false,
    /// Keep runs of uppercase letters (`foo-BAR` → `fooBAR`).
    preserve_consecutive_uppercase: bool = false,
    /// Capitalize the letter after a digit run (`foo2bar` → `foo2Bar`).
    /// When false, numbers do not create word boundaries, following the
    /// Google Java Style Guide.
    capitalize_after_number: bool = true,
    /// Case-mapping rules to apply.
    locale: Locale = .default,
};

/// Errors from [`camelCase`] and [`camelCaseMany`].
pub const Error = std.mem.Allocator.Error;

/// Convert a string to camelCase (or PascalCase, with
/// `options.pascal_case`). Caller owns the returned memory.
///
/// Separators (`_`, `.`, `-`, space) mark word boundaries; case
/// transitions do too (`FooIDs` → `fooIds`, `XMLHttpRequest` →
/// `xmlHttpRequest`). Leading `_`/`$` are preserved, whitespace is
/// trimmed, and input that is entirely separators yields an empty
/// string.
pub fn camelCase(allocator: std.mem.Allocator, input: []const u8, options: Options) Error![]u8 {
    const cps = try decodeTrimmed(allocator, input);
    defer allocator.free(cps);
    return run(allocator, &[_][]const u21{cps}, options);
}

/// Convert several strings to a single camelCase identifier, as if they
/// were joined with `-`. Empty and whitespace-only elements are dropped;
/// each element is trimmed first. Caller owns the returned memory.
pub fn camelCaseMany(allocator: std.mem.Allocator, inputs: []const []const u8, options: Options) Error![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    var parts = std.ArrayList([]const u21).empty;
    defer parts.deinit(a);
    for (inputs) |input| {
        const cps = try decodeTrimmed(a, input);
        if (cps.len > 0) try parts.append(a, cps);
    }

    // Join with '-' (a separator, so it forms a word boundary).
    var joined = std.ArrayList(u21).empty;
    defer joined.deinit(a);
    for (parts.items, 0..) |part, i| {
        if (i > 0) try joined.append(a, '-');
        try joined.appendSlice(a, part);
    }

    return run(allocator, &[_][]const u21{joined.items}, options);
}

/// Full pipeline over already-decoded, already-trimmed input parts.
fn run(allocator: std.mem.Allocator, parts: []const []const u21, options: Options) Error![]u8 {
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();
    const a = arena.allocator();

    const joined = if (parts.len == 1) parts[0] else blk: {
        var buf = std.ArrayList(u21).empty;
        for (parts, 0..) |part, i| {
            if (i > 0) try buf.append(a, '-');
            try buf.appendSlice(a, part);
        }
        break :blk buf.items;
    };

    // Leading `_` and `$` carry meaning (private/internal fields) and are
    // moved out of the conversion entirely.
    var prefix_len: usize = 0;
    while (prefix_len < joined.len and (joined[prefix_len] == '_' or joined[prefix_len] == '$')) prefix_len += 1;
    const prefix = joined[0..prefix_len];
    const body = joined[prefix_len..];

    if (body.len == 0) return encode(allocator, prefix);
    if (body.len == 1) {
        const c = body[0];
        if (isSeparator(c)) return encode(allocator, prefix);
        const mapped = if (options.pascal_case) upperCp(options.locale, c) else lowerCp(options.locale, c);
        const single = [1]u21{mapped};
        return encode2(allocator, prefix, &single);
    }

    var work = std.ArrayList(u21).empty;
    try work.appendSlice(a, body);

    const has_upper = hasUppercase(options.locale, work.items);
    if (has_upper) preserveCamelCase(a, &work, options);

    // Strip leading separators so they do not create a phantom word.
    var start: usize = 0;
    while (start < work.items.len and isSeparator(work.items[start])) start += 1;

    var stage = std.ArrayList(u21).empty;
    if (options.capitalize_after_number) {
        try stage.appendSlice(a, work.items[start..]);
        if (options.preserve_consecutive_uppercase) {
            // Lowercase only a leading capital that is not part of an
            // uppercase run.
            if (stage.items.len >= 1 and uni.isUppercaseLetter(stage.items[0])) {
                const second_is_upper = stage.items.len >= 2 and uni.isUppercaseLetter(stage.items[1]);
                if (!second_is_upper) stage.items[0] = lowerCp(options.locale, stage.items[0]);
            }
        } else {
            for (stage.items) |*c| c.* = lowerCp(options.locale, c.*);
        }
    } else {
        try processWithCasePreservation(a, work.items[start..], &stage, options);
    }

    if (options.pascal_case and stage.items.len > 0) {
        stage.items[0] = upperCp(options.locale, stage.items[0]);
    }

    var processed = std.ArrayList(u21).empty;
    try processed.appendSlice(a, stage.items);
    if (options.capitalize_after_number) capitalizeAfterNumbers(a, &processed, options);
    collapseSeparators(a, &processed, options);

    return encode2(allocator, prefix, processed.items);
}

/// Insert `-` separators at case transitions inside an existing mixed-case
/// string, so later passes can find word boundaries: `FooBar` →
/// `Foo-Bar`, `FOOBar` → `FOO-Bar`, `fooBAR` stays.
fn preserveCamelCase(a: std.mem.Allocator, work: *std.ArrayList(u21), options: Options) void {
    var is_last_lower = false;
    var is_last_upper = false;
    var is_last_last_upper = false;

    var i: usize = 0;
    while (i < work.items.len) : (i += 1) {
        const c = work.items[i];

        // True when the character 3 positions back is an inserted `-`,
        // meaning a separator was recently added here; used to avoid
        // stacking separators.
        const recently_preserved = if (i > 2) work.items[i - 3] == '-' else true;

        if (is_last_lower and uni.isUppercaseLetter(c)) {
            // fooBar → foo-Bar: new word starts at this uppercase.
            work.insert(a, i, '-') catch return;
            is_last_lower = false;
            is_last_last_upper = is_last_upper;
            is_last_upper = true;
            i += 1; // skip past the character that shifted right
        } else if (is_last_upper and is_last_last_upper and uni.isLowercaseLetter(c) and
            (!recently_preserved or options.preserve_consecutive_uppercase))
        {
            // FOOBar → FOO-Bar: an uppercase run ends at this lowercase.
            work.insert(a, i - 1, '-') catch return;
            is_last_last_upper = is_last_upper;
            is_last_upper = false;
            is_last_lower = true;
        } else {
            const l = lowerCp(options.locale, c);
            const u = upperCp(options.locale, c);
            is_last_lower = l == c and u != c;
            is_last_last_upper = is_last_upper;
            is_last_upper = u == c and l != c;
        }
    }
}

/// Lowercase letters except where case carries meaning: runs of uppercase
/// (when preserving them) and letters directly after digits.
fn processWithCasePreservation(a: std.mem.Allocator, input: []const u21, out: *std.ArrayList(u21), options: Options) !void {
    var previous_was_number = false;
    var previous_was_uppercase = false;

    for (input, 0..) |c, i| {
        const is_upper = uni.isUppercaseLetter(c);
        const next_is_upper = i + 1 < input.len and uni.isUppercaseLetter(input[i + 1]);

        if (previous_was_number and uni.isAlphabetic(c)) {
            try out.append(a, c); // letter directly after a digit: keep case
            previous_was_number = false;
            previous_was_uppercase = is_upper;
        } else if (options.preserve_consecutive_uppercase and is_upper and
            (previous_was_uppercase or next_is_upper))
        {
            try out.append(a, c); // inside an uppercase run: keep it
            previous_was_uppercase = true;
        } else if (isAsciiDigit(c)) {
            try out.append(a, c);
            previous_was_number = true;
            previous_was_uppercase = false;
        } else if (isSeparator(c)) {
            try out.append(a, c); // separators keep number state intact
            previous_was_uppercase = false;
        } else {
            try out.append(a, lowerCp(options.locale, c));
            previous_was_number = false;
            previous_was_uppercase = false;
        }
    }
}

/// Uppercase the letter following a digit run (`hello1world` →
/// `hello1World`), unless the run's letter is itself followed by a
/// separator (a continued token like `b2b_`).
fn capitalizeAfterNumbers(a: std.mem.Allocator, work: *std.ArrayList(u21), options: Options) void {
    var out = std.ArrayList(u21).empty;
    const items = work.items;
    var i: usize = 0;
    while (i < items.len) {
        if (!isAsciiDigit(items[i])) {
            out.append(a, items[i]) catch return;
            i += 1;
            continue;
        }
        var j = i;
        while (j < items.len and isAsciiDigit(items[j])) j += 1;
        if (j < items.len and isIdentifierChar(items[j])) {
            const after = if (j + 1 < items.len) items[j + 1] else null;
            if (after != null and isSeparator(after.?)) {
                // Continued token (b2b_registration): leave as-is.
                out.appendSlice(a, items[i .. j + 1]) catch return;
            } else {
                out.appendSlice(a, items[i..j]) catch return;
                out.append(a, upperCp(options.locale, items[j])) catch return;
            }
            i = j + 1;
        } else {
            out.appendSlice(a, items[i..j]) catch return;
            i = j;
        }
    }
    work.* = out;
}

/// Collapse separator runs and uppercase the character that follows
/// (`foo-bar` → `fooBar`); trailing separators are dropped.
fn collapseSeparators(a: std.mem.Allocator, work: *std.ArrayList(u21), options: Options) void {
    var out = std.ArrayList(u21).empty;
    const items = work.items;
    var i: usize = 0;
    while (i < items.len) {
        if (!isSeparator(items[i])) {
            out.append(a, items[i]) catch return;
            i += 1;
            continue;
        }
        var j = i;
        while (j < items.len and isSeparator(items[j])) j += 1;
        if (j == items.len) {
            // Trailing separator run: drop.
        } else if (isIdentifierChar(items[j])) {
            out.append(a, upperCp(options.locale, items[j])) catch return;
            i = j + 1;
            continue;
        } else {
            // Followed by a non-identifier (e.g. `@`): keep verbatim.
            out.appendSlice(a, items[i..j]) catch return;
        }
        i = j;
    }
    work.* = out;
}

fn hasUppercase(locale: Locale, cps: []const u21) bool {
    for (cps) |c| {
        if (lowerCp(locale, c) != c) return true;
    }
    return false;
}

fn isSeparator(c: u21) bool {
    return c == '_' or c == '.' or c == '-' or c == ' ';
}

fn isAsciiDigit(c: u21) bool {
    return c >= '0' and c <= '9';
}

fn isIdentifierChar(c: u21) bool {
    return uni.isAlphabetic(c) or uni.isNumber(c) or c == '_';
}

fn lowerCp(locale: Locale, c: u21) u21 {
    if (locale == .turkic and c == 'I') return 0x0131; // ı
    return uni.toLower(c);
}

fn upperCp(locale: Locale, c: u21) u21 {
    if (locale == .turkic and c == 'i') return 0x0130; // İ
    return uni.toUpper(c);
}

/// JavaScript `String.prototype.trim` whitespace, which goes beyond ASCII.
fn isJsWhitespace(c: u21) bool {
    return switch (c) {
        0x09...0x0D, 0x20, 0xA0, 0x1680, 0x2000...0x200A, 0x2028, 0x2029, 0x202F, 0x205F, 0x3000, 0xFEFF => true,
        else => false,
    };
}

/// Decode UTF-8 and trim JavaScript whitespace from both ends.
fn decodeTrimmed(allocator: std.mem.Allocator, input: []const u8) Error![]u21 {
    var out = std.ArrayList(u21).empty;
    errdefer out.deinit(allocator);
    var view = std.unicode.Utf8View.initUnchecked(input);
    var it = view.iterator();
    while (it.nextCodepoint()) |c| {
        try out.append(allocator, c);
    }
    const items = out.items;
    var start: usize = 0;
    var end: usize = items.len;
    while (start < end and isJsWhitespace(items[start])) start += 1;
    while (end > start and isJsWhitespace(items[end - 1])) end -= 1;

    const trimmed = try allocator.dupe(u21, items[start..end]);
    out.deinit(allocator);
    return trimmed;
}

fn encode(allocator: std.mem.Allocator, cps: []const u21) Error![]u8 {
    return encode2(allocator, &.{}, cps);
}

fn encode2(allocator: std.mem.Allocator, prefix: []const u21, body: []const u21) Error![]u8 {
    var buf = std.ArrayList(u8).empty;
    errdefer buf.deinit(allocator);
    var scratch: [4]u8 = undefined;
    for (prefix) |c| try buf.appendSlice(allocator, scratch[0 .. std.unicode.utf8Encode(c, &scratch) catch unreachable]);
    for (body) |c| try buf.appendSlice(allocator, scratch[0 .. std.unicode.utf8Encode(c, &scratch) catch unreachable]);
    return buf.toOwnedSlice(allocator);
}

test {
    _ = @import("unicode_data.zig");
    _ = @import("tests.zig");
}
