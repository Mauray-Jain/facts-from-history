const std = @import("std");
const args = @import("args.zig");
const json = @import("json_utils.zig");

// TODO: prevent repetition, implement -m x, -e x ..., implement a progress bar while waiting for request

pub fn main() !u8 {
    const stdout_file = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer if (gpa.deinit() == .leak) @panic("Achievement unlocked!: Success fully leaked memory");
    const alloc = gpa.allocator();
    var arena = std.heap.ArenaAllocator.init(alloc);
    const allocator = arena.allocator();
    defer arena.deinit();

    // Parse arguments
    var args_iter = try std.process.argsWithAllocator(allocator);
    defer args_iter.deinit();
    const args_present: bool = args_iter.skip();
    var conds = args.conds_t{};
    var args_cnt: u8 = 0;
    if (args_present) {
        while (args_iter.next()) |arg| {
            if (std.mem.eql(u8, arg, "-h") or std.mem.eql(u8, arg, "--help")) {
                try stdout.print(args.help_ops, .{});
                try bw.flush();
                return 0;
            }
            args.parseArg(&conds, arg) catch |err| switch (err) {
                error.Overflow => {
                    try args.printHelpOnError("Error: arg has very big number consider reducing it\n");
                    return 1;
                },
                error.NoNumber => {
                    try args.printHelpOnError("Error: arg has no number\n");
                    return 1;
                },
                error.InvalidArgs => {
                    try args.printHelpOnError("Error: arg is invalid\n");
                    return 1;
                },
                else => unreachable,
            };
            args_cnt += 1;
            if (args_cnt > 5) {
                try args.printHelpOnError("Error: Too many arguments. Don't repeat arguments\n");
                return 1;
            }
        }
    }

    if (!args.isDateValid(conds.date, conds.month)) {
        try stderr.print("Error: Date entered is invalid\n", .{});
        return 1;
    }
    if ((conds.date == 0 and conds.month != 0) or (conds.date != 0 and conds.month == 0)) {
        try stderr.print("Error: Please enter both month and date or don't enter any\n", .{});
        return 1;
    }

    // Make client
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var url: []const u8 = undefined;
    if (conds.month > 0 and conds.date > 0) {
        url = try std.fmt.allocPrint(allocator, "https://history.muffinlabs.com/date/{}/{}", .{ conds.month, conds.date });
    } else {
        url = try std.fmt.allocPrint(allocator, "https://history.muffinlabs.com/date", .{});
    }

    // const uri = std.Uri.parse(url) catch |err| {
    //     std.debug.panic("Parse error: {}\n", .{err});
    // };
    // defer allocator.free(url);

    // var headers = std.http.Headers{ .allocator = allocator };
    // defer headers.deinit();
    // try headers.append("accept", "application/json");

    // try req.send();
    // try req.wait();

    // const body = try req.reader().readAllAlloc(allocator, 10_00_000);
    // defer allocator.free(body);

    var list = std.ArrayList(u8).init(allocator);
    const status = try client.fetch(.{
        .headers = .{ .accept_encoding = .{ .override = "application/json" } },
        .location = .{ .url = url },
        .response_storage = .{ .dynamic = &list },
    });
    if (status.status != .ok) {
        try stderr.print("Couldn't make request\n", .{});
        return 1;
    }
    const body = try list.toOwnedSlice();
    defer allocator.free(body);
    const result = json.parseJson(allocator, body, conds) catch {
        try stderr.print("Some error ocurred while parsing JSON\n", .{});
        return 1;
    };
    defer result.deinit();
    try stdout.print("{s}\n", .{result.items});
    try bw.flush();
    return 0;
}
