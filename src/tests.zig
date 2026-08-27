//! Port of the upstream test suite (test.js, ava) for camelcase v9.0.0.
//! Every value assertion is ported; the two tests that exercise
//! JavaScript runtime specifics (a TypeError on non-string input, and
//! mocking of Intl locale functions) have no Zig equivalent.

const std = @import("std");
const cc = @import("root.zig");

const Case = struct {
    input: []const u8,
    want: []const u8,
    opts: cc.Options = .{},
};

fn run(cases: []const Case) !void {
    const t = std.testing;
    for (cases) |c| {
        const got = try cc.camelCase(t.allocator, c.input, c.opts);
        defer t.allocator.free(got);
        std.testing.expectEqualStrings(c.want, got) catch |e| {
            std.debug.print("input: \"{s}\"\n", .{c.input});
            return e;
        };
    }
}

const MultiCase = struct {
    input: []const []const u8,
    want: []const u8,
    opts: cc.Options = .{},
};

fn runMulti(cases: []const MultiCase) !void {
    const t = std.testing;
    for (cases) |c| {
        const got = try cc.camelCaseMany(t.allocator, c.input, c.opts);
        defer t.allocator.free(got);
        std.testing.expectEqualStrings(c.want, got) catch |e| {
            std.debug.print("input: [", .{});
            for (c.input) |s| std.debug.print("\"{s}\",", .{s});
            std.debug.print("]\n", .{});
            return e;
        };
    }
}

test "camelCase" {
    try run(&.{
        .{ .input = "b2b_registration_request", .want = "b2bRegistrationRequest" },
        .{ .input = "b2b-registration-request", .want = "b2bRegistrationRequest" },
        .{ .input = "b2b_registration_b2b_request", .want = "b2bRegistrationB2bRequest" },
        .{ .input = "foo", .want = "foo" },
        .{ .input = "IDs", .want = "ids" },
        .{ .input = "FooIDs", .want = "fooIds" },
        .{ .input = "foo-bar", .want = "fooBar" },
        .{ .input = "foo-bar-baz", .want = "fooBarBaz" },
        .{ .input = "foo--bar", .want = "fooBar" },
        .{ .input = "--foo-bar", .want = "fooBar" },
        .{ .input = "--foo--bar", .want = "fooBar" },
        .{ .input = "FOO-BAR", .want = "fooBar" },
        .{ .input = "FOÈ-BAR", .want = "foèBar" },
        .{ .input = "-foo-bar-", .want = "fooBar" },
        .{ .input = "--foo--bar--", .want = "fooBar" },
        .{ .input = "foo-1", .want = "foo1" },
        .{ .input = "foo.bar", .want = "fooBar" },
        .{ .input = "foo..bar", .want = "fooBar" },
        .{ .input = "..foo..bar..", .want = "fooBar" },
        .{ .input = "foo_bar", .want = "fooBar" },
        .{ .input = "__foo__bar__", .want = "__fooBar" },
        .{ .input = "foo bar", .want = "fooBar" },
        .{ .input = "  foo  bar  ", .want = "fooBar" },
        .{ .input = "-", .want = "" },
        .{ .input = " - ", .want = "" },
        .{ .input = "fooBar", .want = "fooBar" },
        .{ .input = "fooBar-baz", .want = "fooBarBaz" },
        .{ .input = "foìBar-baz", .want = "foìBarBaz" },
        .{ .input = "fooBarBaz-bazzy", .want = "fooBarBazBazzy" },
        .{ .input = "FBBazzy", .want = "fbBazzy" },
        .{ .input = "F", .want = "f" },
        .{ .input = "FooBar", .want = "fooBar" },
        .{ .input = "Foo", .want = "foo" },
        .{ .input = "FOO", .want = "foo" },
        .{ .input = "--", .want = "" },
        .{ .input = "", .want = "" },
        .{ .input = "_", .want = "_" },
        .{ .input = " ", .want = "" },
        .{ .input = ".", .want = "" },
        .{ .input = "..", .want = "" },
        .{ .input = "  ", .want = "" },
        .{ .input = "__", .want = "__" },
        .{ .input = "--__--_--_", .want = "" },
        .{ .input = "foo bar?", .want = "fooBar?" },
        .{ .input = "foo bar!", .want = "fooBar!" },
        .{ .input = "foo bar$", .want = "fooBar$" },
        .{ .input = "foo-bar#", .want = "fooBar#" },
        .{ .input = "XMLHttpRequest", .want = "xmlHttpRequest" },
        .{ .input = "AjaxXMLHttpRequest", .want = "ajaxXmlHttpRequest" },
        .{ .input = "Ajax-XMLHttpRequest", .want = "ajaxXmlHttpRequest" },
        .{ .input = "mGridCol6@md", .want = "mGridCol6@md" },
        .{ .input = "A::a", .want = "a::a" },
        .{ .input = "Hello1World", .want = "hello1World" },
        .{ .input = "Hello11World", .want = "hello11World" },
        .{ .input = "hello1world", .want = "hello1World" },
        .{ .input = "Hello1World11foo", .want = "hello1World11Foo" },
        .{ .input = "Hello1", .want = "hello1" },
        .{ .input = "hello1", .want = "hello1" },
        .{ .input = "1Hello", .want = "1Hello" },
        .{ .input = "1hello", .want = "1Hello" },
        .{ .input = "h2w", .want = "h2W" },
        .{ .input = "розовый_пушистый-единороги", .want = "розовыйПушистыйЕдинороги" },
        .{ .input = "РОЗОВЫЙ_ПУШИСТЫЙ-ЕДИНОРОГИ", .want = "розовыйПушистыйЕдинороги" },
        .{ .input = "桑德在这里。", .want = "桑德在这里。" },
        .{ .input = "桑德_在这里。", .want = "桑德在这里。" },
    });

    try runMulti(&.{
        .{ .input = &.{ "foo", "bar" }, .want = "fooBar" },
        .{ .input = &.{ "foo", "-bar" }, .want = "fooBar" },
        .{ .input = &.{ "foo", "-bar", "baz" }, .want = "fooBarBaz" },
        .{ .input = &.{ "", "" }, .want = "" },
        .{ .input = &.{}, .want = "" },
        .{ .input = &.{ "---_", "--", "", "-_- " }, .want = "" },
    });
}

test "camelCase with pascalCase option" {
    const o = cc.Options{ .pascal_case = true };
    try run(&.{
        .{ .input = "b2b_registration_request", .want = "B2bRegistrationRequest", .opts = o },
        .{ .input = "foo", .want = "Foo", .opts = o },
        .{ .input = "foo-bar", .want = "FooBar", .opts = o },
        .{ .input = "foo-bar-baz", .want = "FooBarBaz", .opts = o },
        .{ .input = "foo--bar", .want = "FooBar", .opts = o },
        .{ .input = "--foo-bar", .want = "FooBar", .opts = o },
        .{ .input = "--foo--bar", .want = "FooBar", .opts = o },
        .{ .input = "FOO-BAR", .want = "FooBar", .opts = o },
        .{ .input = "FOÈ-BAR", .want = "FoèBar", .opts = o },
        .{ .input = "-foo-bar-", .want = "FooBar", .opts = o },
        .{ .input = "--foo--bar--", .want = "FooBar", .opts = o },
        .{ .input = "foo-1", .want = "Foo1", .opts = o },
        .{ .input = "foo.bar", .want = "FooBar", .opts = o },
        .{ .input = "foo..bar", .want = "FooBar", .opts = o },
        .{ .input = "..foo..bar..", .want = "FooBar", .opts = o },
        .{ .input = "foo_bar", .want = "FooBar", .opts = o },
        .{ .input = "__foo__bar__", .want = "__FooBar", .opts = o },
        .{ .input = "foo bar", .want = "FooBar", .opts = o },
        .{ .input = "  foo  bar  ", .want = "FooBar", .opts = o },
        .{ .input = "-", .want = "", .opts = o },
        .{ .input = " - ", .want = "", .opts = o },
        .{ .input = "fooBar", .want = "FooBar", .opts = o },
        .{ .input = "fooBar-baz", .want = "FooBarBaz", .opts = o },
        .{ .input = "foìBar-baz", .want = "FoìBarBaz", .opts = o },
        .{ .input = "fooBarBaz-bazzy", .want = "FooBarBazBazzy", .opts = o },
        .{ .input = "FBBazzy", .want = "FbBazzy", .opts = o },
        .{ .input = "F", .want = "F", .opts = o },
        .{ .input = "FooBar", .want = "FooBar", .opts = o },
        .{ .input = "Foo", .want = "Foo", .opts = o },
        .{ .input = "FOO", .want = "Foo", .opts = o },
        .{ .input = "--", .want = "", .opts = o },
        .{ .input = "", .want = "", .opts = o },
        .{ .input = "--__--_--_", .want = "", .opts = o },
        .{ .input = "foo bar?", .want = "FooBar?", .opts = o },
        .{ .input = "foo bar!", .want = "FooBar!", .opts = o },
        .{ .input = "foo bar$", .want = "FooBar$", .opts = o },
        .{ .input = "foo-bar#", .want = "FooBar#", .opts = o },
        .{ .input = "XMLHttpRequest", .want = "XmlHttpRequest", .opts = o },
        .{ .input = "AjaxXMLHttpRequest", .want = "AjaxXmlHttpRequest", .opts = o },
        .{ .input = "Ajax-XMLHttpRequest", .want = "AjaxXmlHttpRequest", .opts = o },
        .{ .input = "mGridCol6@md", .want = "MGridCol6@md", .opts = o },
        .{ .input = "A::a", .want = "A::a", .opts = o },
        .{ .input = "Hello1World", .want = "Hello1World", .opts = o },
        .{ .input = "Hello11World", .want = "Hello11World", .opts = o },
        .{ .input = "hello1world", .want = "Hello1World", .opts = o },
        .{ .input = "hello1World", .want = "Hello1World", .opts = o },
        .{ .input = "hello1", .want = "Hello1", .opts = o },
        .{ .input = "Hello1", .want = "Hello1", .opts = o },
        .{ .input = "1hello", .want = "1Hello", .opts = o },
        .{ .input = "1Hello", .want = "1Hello", .opts = o },
        .{ .input = "h1W", .want = "H1W", .opts = o },
        .{ .input = "РозовыйПушистыйЕдинороги", .want = "РозовыйПушистыйЕдинороги", .opts = o },
        .{ .input = "розовый_пушистый-единороги", .want = "РозовыйПушистыйЕдинороги", .opts = o },
        .{ .input = "РОЗОВЫЙ_ПУШИСТЫЙ-ЕДИНОРОГИ", .want = "РозовыйПушистыйЕдинороги", .opts = o },
        .{ .input = "桑德在这里。", .want = "桑德在这里。", .opts = o },
        .{ .input = "桑德_在这里。", .want = "桑德在这里。", .opts = o },
        .{ .input = "a1b", .want = "A1B", .opts = o },
    });

    try runMulti(&.{
        .{ .input = &.{ "foo", "bar" }, .want = "FooBar", .opts = o },
        .{ .input = &.{ "foo", "-bar" }, .want = "FooBar", .opts = o },
        .{ .input = &.{ "foo", "-bar", "baz" }, .want = "FooBarBaz", .opts = o },
        .{ .input = &.{ "", "" }, .want = "", .opts = o },
        .{ .input = &.{ "---_", "--", "", "-_- " }, .want = "", .opts = o },
    });
}

test "camelCase with preserveConsecutiveUppercase option" {
    const o = cc.Options{ .preserve_consecutive_uppercase = true };
    try run(&.{
        .{ .input = "foo-BAR", .want = "fooBAR", .opts = o },
        .{ .input = "Foo-BAR", .want = "fooBAR", .opts = o },
        .{ .input = "fooBAR", .want = "fooBAR", .opts = o },
        .{ .input = "fooBaR", .want = "fooBaR", .opts = o },
        .{ .input = "FOÈ-BAR", .want = "FOÈBAR", .opts = o },
        .{ .input = "--", .want = "", .opts = o },
        .{ .input = "", .want = "", .opts = o },
        .{ .input = "--__--_--_", .want = "", .opts = o },
        .{ .input = "foo BAR?", .want = "fooBAR?", .opts = o },
        .{ .input = "foo BAR!", .want = "fooBAR!", .opts = o },
        .{ .input = "foo BAR$", .want = "fooBAR$", .opts = o },
        .{ .input = "foo-BAR#", .want = "fooBAR#", .opts = o },
        .{ .input = "XMLHttpRequest", .want = "XMLHttpRequest", .opts = o },
        .{ .input = "AjaxXMLHttpRequest", .want = "ajaxXMLHttpRequest", .opts = o },
        .{ .input = "Ajax-XMLHttpRequest", .want = "ajaxXMLHttpRequest", .opts = o },
        .{ .input = "mGridCOl6@md", .want = "mGridCOl6@md", .opts = o },
        .{ .input = "A::a", .want = "a::a", .opts = o },
        .{ .input = "Hello1WORLD", .want = "hello1WORLD", .opts = o },
        .{ .input = "Hello11WORLD", .want = "hello11WORLD", .opts = o },
        .{ .input = "РозовыйПушистыйFOOдинорогиf", .want = "розовыйПушистыйFOOдинорогиf", .opts = o },
        .{ .input = "桑德在这里。", .want = "桑德在这里。", .opts = o },
        .{ .input = "桑德_在这里。", .want = "桑德在这里。", .opts = o },
        .{ .input = "IDs", .want = "iDs", .opts = o },
        .{ .input = "FooIDs", .want = "fooIDs", .opts = o },
    });

    try runMulti(&.{
        .{ .input = &.{ "foo", "BAR" }, .want = "fooBAR", .opts = o },
        .{ .input = &.{ "foo", "-BAR" }, .want = "fooBAR", .opts = o },
        .{ .input = &.{ "foo", "-BAR", "baz" }, .want = "fooBARBaz", .opts = o },
        .{ .input = &.{ "", "" }, .want = "", .opts = o },
        .{ .input = &.{ "---_", "--", "", "-_- " }, .want = "", .opts = o },
    });
}

test "camelCase with both pascalCase and preserveConsecutiveUppercase" {
    const o = cc.Options{ .pascal_case = true, .preserve_consecutive_uppercase = true };
    try run(&.{
        .{ .input = "foo-BAR", .want = "FooBAR", .opts = o },
        .{ .input = "fooBAR", .want = "FooBAR", .opts = o },
        .{ .input = "fooBaR", .want = "FooBaR", .opts = o },
        .{ .input = "fOÈ-BAR", .want = "FOÈBAR", .opts = o },
        .{ .input = "--foo.BAR", .want = "FooBAR", .opts = o },
        .{ .input = "--", .want = "", .opts = o },
        .{ .input = "", .want = "", .opts = o },
        .{ .input = "--__--_--_", .want = "", .opts = o },
        .{ .input = "foo BAR?", .want = "FooBAR?", .opts = o },
        .{ .input = "foo BAR!", .want = "FooBAR!", .opts = o },
        .{ .input = "Foo BAR$", .want = "FooBAR$", .opts = o },
        .{ .input = "foo-BAR#", .want = "FooBAR#", .opts = o },
        .{ .input = "xMLHttpRequest", .want = "XMLHttpRequest", .opts = o },
        .{ .input = "ajaxXMLHttpRequest", .want = "AjaxXMLHttpRequest", .opts = o },
        .{ .input = "Ajax-XMLHttpRequest", .want = "AjaxXMLHttpRequest", .opts = o },
        .{ .input = "mGridCOl6@md", .want = "MGridCOl6@md", .opts = o },
        .{ .input = "A::a", .want = "A::a", .opts = o },
        .{ .input = "Hello1WORLD", .want = "Hello1WORLD", .opts = o },
        .{ .input = "Hello11WORLD", .want = "Hello11WORLD", .opts = o },
        .{ .input = "pозовыйПушистыйFOOдинорогиf", .want = "PозовыйПушистыйFOOдинорогиf", .opts = o },
        .{ .input = "桑德在这里。", .want = "桑德在这里。", .opts = o },
        .{ .input = "桑德_在这里。", .want = "桑德在这里。", .opts = o },
    });

    try runMulti(&.{
        .{ .input = &.{ "Foo", "BAR" }, .want = "FooBAR", .opts = o },
        .{ .input = &.{ "foo", "-BAR" }, .want = "FooBAR", .opts = o },
        .{ .input = &.{ "foo", "-BAR", "baz" }, .want = "FooBARBaz", .opts = o },
        .{ .input = &.{ "", "" }, .want = "", .opts = o },
        .{ .input = &.{ "---_", "--", "", "-_- " }, .want = "", .opts = o },
    });
}

test "camelCase with locale option" {
    const tr = cc.Options{ .locale = .turkic };
    const tr_pascal = cc.Options{ .locale = .turkic, .pascal_case = true };
    const en = cc.Options{ .locale = .default };
    try run(&.{
        .{ .input = "lorem-ipsum", .want = "loremİpsum", .opts = tr },
        .{ .input = "lorem-ipsum", .want = "loremIpsum", .opts = en },
        .{ .input = "ipsum-dolor", .want = "İpsumDolor", .opts = tr_pascal },
        .{ .input = "ipsum-dolor", .want = "IpsumDolor", .opts = .{ .locale = .default, .pascal_case = true } },
        // Turkish dotted i with numbers.
        .{ .input = "test_1i", .want = "test1İ", .opts = tr },
        .{ .input = "test_1i", .want = "test1i", .opts = .{ .locale = .turkic, .capitalize_after_number = false } },
        // An empty locale list falls back to the default mappings.
        .{ .input = "foo-bar", .want = "fooBar", .opts = en },
    });
}

test "number handling follows Google Style Guide" {
    const o = cc.Options{ .capitalize_after_number = false };
    try run(&.{
        .{ .input = "turn_on_2sv", .want = "turnOn2sv", .opts = o },
        .{ .input = "a1b_text", .want = "a1bText", .opts = o },
        .{ .input = "foo2bar", .want = "foo2bar", .opts = o },
        .{ .input = "version2", .want = "version2", .opts = o },
        .{ .input = "turn_on_2sv", .want = "TurnOn2sv", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
        .{ .input = "a1b_text", .want = "A1bText", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
    });
}

test "capitalizeAfterNumber" {
    try run(&.{
        .{ .input = "Hello1World", .want = "hello1World" },
        .{ .input = "Hello1World", .want = "hello1World", .opts = .{ .capitalize_after_number = false } },
        .{ .input = "foo2bar", .want = "foo2Bar" },
        .{ .input = "foo2bar", .want = "foo2bar", .opts = .{ .capitalize_after_number = false } },
        .{ .input = "hello1world", .want = "hello1World" },
        .{ .input = "hello1world", .want = "hello1world", .opts = .{ .capitalize_after_number = false } },
        .{ .input = "turn_on_2sv", .want = "turnOn2Sv" },
        .{ .input = "turn_on_2sv", .want = "turnOn2sv", .opts = .{ .capitalize_after_number = false } },
        .{ .input = "Hello1World", .want = "Hello1World", .opts = .{ .pascal_case = true } },
        .{ .input = "Hello1World", .want = "Hello1World", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
        .{ .input = "turn_on_2sv", .want = "TurnOn2Sv", .opts = .{ .pascal_case = true } },
        .{ .input = "turn_on_2sv", .want = "TurnOn2sv", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
    });
}

test "capitalizeAfterNumber edge cases" {
    const no_num = cc.Options{ .capitalize_after_number = false };
    try run(&.{
        .{ .input = "foo-2bar", .want = "foo2Bar" },
        .{ .input = "foo-2bar", .want = "foo2bar", .opts = no_num },
        .{ .input = "foo-2bar", .want = "Foo2Bar", .opts = .{ .pascal_case = true } },
        .{ .input = "foo-2bar", .want = "Foo2bar", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
        .{ .input = "2foo-bar", .want = "2FooBar" },
        .{ .input = "2foo-bar", .want = "2fooBar", .opts = no_num },
        .{ .input = "2foo-bar", .want = "2FooBar", .opts = .{ .pascal_case = true } },
        .{ .input = "2foo-bar", .want = "2fooBar", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
        .{ .input = "XML2HTTP", .want = "xml2Http" },
        .{ .input = "XML2HTTP", .want = "xml2Http", .opts = no_num },
        .{ .input = "XML2HTTP", .want = "Xml2Http", .opts = .{ .pascal_case = true } },
        .{ .input = "XML2HTTP", .want = "Xml2Http", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
        .{ .input = "2a", .want = "2A" },
        .{ .input = "2a", .want = "2a", .opts = no_num },
        .{ .input = "2a", .want = "2A", .opts = .{ .pascal_case = true } },
        .{ .input = "2a", .want = "2a", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
        .{ .input = "foo2BAR", .want = "foo2BAR", .opts = .{ .preserve_consecutive_uppercase = true } },
        .{ .input = "foo2BAR", .want = "foo2BAR", .opts = .{ .preserve_consecutive_uppercase = true, .capitalize_after_number = false } },
    });
}

test "case preservation after numbers" {
    const o = cc.Options{ .capitalize_after_number = false };
    try run(&.{
        .{ .input = "Textures_3d", .want = "textures3d", .opts = o },
        .{ .input = "Textures_3D", .want = "textures3D", .opts = o },
        .{ .input = "version_1a", .want = "version1a", .opts = o },
        .{ .input = "version_1A", .want = "version1A", .opts = o },
        .{ .input = "foo_2_bar", .want = "foo2Bar", .opts = o },
        .{ .input = "Textures_3d", .want = "Textures3d", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
        .{ .input = "Textures_3D", .want = "Textures3D", .opts = .{ .pascal_case = true, .capitalize_after_number = false } },
    });
}

test "preserve leading underscores and dollar signs" {
    try run(&.{
        .{ .input = "_foo_bar", .want = "_fooBar" },
        .{ .input = "$foo_bar", .want = "$fooBar" },
        .{ .input = "__foo_bar", .want = "__fooBar" },
        .{ .input = "$$foo_bar", .want = "$$fooBar" },
        .{ .input = "$_foo_bar", .want = "$_fooBar" },
        .{ .input = "_$foo_bar", .want = "_$fooBar" },
        .{ .input = "_", .want = "_" },
        .{ .input = "__", .want = "__" },
        .{ .input = "$", .want = "$" },
        .{ .input = "$$$", .want = "$$$" },
        .{ .input = "_$", .want = "_$" },
        .{ .input = "_foo_bar", .want = "_FooBar", .opts = .{ .pascal_case = true } },
        .{ .input = "$foo_bar", .want = "$FooBar", .opts = .{ .pascal_case = true } },
        .{ .input = "__foo_bar", .want = "__FooBar", .opts = .{ .pascal_case = true } },
        .{ .input = "_foo_BAR", .want = "_fooBAR", .opts = .{ .preserve_consecutive_uppercase = true } },
        .{ .input = "$foo_BAR", .want = "$fooBAR", .opts = .{ .preserve_consecutive_uppercase = true } },
        .{ .input = "_foo-bar_baz", .want = "_fooBarBaz" },
        .{ .input = "$http_service", .want = "$httpService" },
    });
}

test "emoji and unicode" {
    try run(&.{
        .{ .input = "foo-🦄-bar", .want = "foo-🦄Bar" },
        .{ .input = "foo🦄bar", .want = "foo🦄bar" },
        .{ .input = "foo\u{200D}bar", .want = "foo\u{200D}bar" },
        .{ .input = "foo_مرحبا_bar", .want = "fooمرحباBar" },
        .{ .input = "foo_שלום_bar", .want = "fooשלוםBar" },
    });
}

test "combined options" {
    try run(&.{
        .{ .input = "foo_2BAR_baz", .want = "Foo2BARBaz", .opts = .{ .pascal_case = true, .preserve_consecutive_uppercase = true, .capitalize_after_number = false } },
        .{ .input = "__foo_2BAR", .want = "__Foo2BAR", .opts = .{ .pascal_case = true, .preserve_consecutive_uppercase = true, .capitalize_after_number = false } },
        .{ .input = "$_foo_BAR", .want = "$_FooBAR", .opts = .{ .pascal_case = true, .preserve_consecutive_uppercase = true } },
    });
}

test "numbers" {
    try run(&.{
        .{ .input = "version_3.14.15", .want = "version31415" },
        .{ .input = "temp_-5_degrees", .want = "temp5Degrees" },
        .{ .input = "123", .want = "123" },
        .{ .input = "123_456_789", .want = "123456789" },
    });
}

test "special characters" {
    try run(&.{
        .{ .input = "foo##bar", .want = "foo##bar" },
        .{ .input = "foo@#$bar", .want = "foo@#$bar" },
        .{ .input = "foo_@#_bar", .want = "foo_@#Bar" },
    });
}

test "array input" {
    try runMulti(&.{
        .{ .input = &.{ "_foo", "$bar" }, .want = "_foo-$bar" },
        .{ .input = &.{ "  ", "  foo  ", "  " }, .want = "foo" },
        .{ .input = &.{ "", "  ", "" }, .want = "" },
    });
}

test "uppercase transitions" {
    try run(&.{
        .{ .input = "aAbBcC", .want = "aAbBcC" },
        .{ .input = "a1A2B3C", .want = "a1A2B3C" },
        .{ .input = "fooAbar", .want = "fooAbar", .opts = .{ .preserve_consecutive_uppercase = true } },
        .{ .input = "A", .want = "a", .opts = .{ .preserve_consecutive_uppercase = true } },
    });
}

test "extreme inputs" {
    var buf: [128]u8 = undefined;
    @memcpy(buf[0..50], "_" ** 50);
    @memcpy(buf[50..53], "foo");
    @memcpy(buf[53..103], "_" ** 50);
    @memcpy(buf[103..106], "bar");
    const input = buf[0..106];

    var want_buf: [64]u8 = undefined;
    @memcpy(want_buf[0..50], "_" ** 50);
    @memcpy(want_buf[50..56], "fooBar");
    const want = want_buf[0..56];

    const got = try cc.camelCase(std.testing.allocator, input, .{});
    defer std.testing.allocator.free(got);
    try std.testing.expectEqualStrings(want, got);

    try run(&.{
        .{ .input = "_-. _-. _-.foo", .want = "_foo" },
        .{ .input = "-_.  -_. -_.", .want = "" },
    });
}
