const std = @import("std");
const conds_t = @import("args.zig").conds_t;

const Value = std.json.Value;

pub fn parseJson(
    allocator: std.mem.Allocator,
    to_parse: []const u8,
    conds: conds_t,
) !std.ArrayList(u8) {
    const parsed = try std.json.parseFromSlice(Value, allocator, to_parse, .{
        .allocate = .alloc_always,
    });
    defer parsed.deinit();
    var result = std.ArrayList(u8).init(allocator);
    const date: []const u8 = parsed.value.object.get("date").?.string;
    const root = parsed.value.object.get("data").?;

    // TODO: There is lot of repetition reduce it
    const events_obj = root.object.get("Events").?.array.items;
    const events = try getValues(allocator, events_obj, conds.events);
    defer events.deinit();

    const births_obj = root.object.get("Births").?.array.items;
    const births = try getValues(allocator, births_obj, conds.births);
    defer births.deinit();

    const deaths_obj = root.object.get("Deaths").?.array.items;
    const deaths = try getValues(allocator, deaths_obj, conds.deaths);
    defer deaths.deinit();

    try result.appendSlice("\nDate: ");
    try result.appendSlice(date);
    try result.appendSlice("\n\n");
    if (conds.events > 0) {
        try result.appendSlice("Events:\n");
        try result.appendSlice(events.items);
        try result.appendSlice("\n\n");
    }
    if (conds.births > 0) {
        try result.appendSlice("Births:\n");
        try result.appendSlice(births.items);
        try result.appendSlice("\n\n");
    }
    if (conds.deaths > 0) {
        try result.appendSlice("Deaths:\n");
        try result.appendSlice(deaths.items);
    }
    try result.append('\n');
    return result;
}

fn getValues(allocator: std.mem.Allocator, obj: []Value, num: u16) !std.ArrayList(u8) {
    const len: usize = obj.len;
    var i: u16 = 0;
    var result = std.ArrayList(u8).init(allocator);
    const till = if (len < num) len else num;
    while (i < till) : (i += 1) {
        const year = obj[i].object.get("year").?.string;
        const text = obj[i].object.get("text").?.string;
        try result.appendSlice("\nYear: ");
        try result.appendSlice(year);
        try result.append('\n');
        try result.appendSlice(text);
    }
    return result;
}

test "json parsing" {
    const json = @embedFile("test.json");
    const allocator = std.testing.allocator;
    const res = try parseJson(allocator, json, conds_t{});
    defer res.deinit();
    std.debug.print("{s}\n", .{res.items});
}
