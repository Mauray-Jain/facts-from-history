const std = @import("std");

pub const MyError = error{ InvalidArgs, Overflow, NoNumber };

/// This struct holds the information given by user in command line
pub const conds_t = struct {
    date: u5 = 0,
    month: u4 = 0,
    births: u16 = 1,
    events: u16 = 1,
    deaths: u16 = 1,
};

/// Help options
pub const help_ops =
    \\Usage:
    \\facts [OPTIONS]
    \\
    \\Options:
    \\
    \\  --help or -h       : Prints this help menu
    \\  --events=x or -e=x : Prints x amount of events (By default x = 1)
    \\  --births=x or -b=x : Prints x amount of births (By default x = 1)
    \\  --deaths=x or -s=x : Prints x amount of deaths (By default x = 1) (Why s? bcoz its sad)
    \\  --month=m or -m=m  : Sets the month as m (By default this month)
    \\  --date=d or -d=d   : Sets the date as d (By default this date)
    \\
;

/// These options only can hold data
const valid_args_with_data: [5][2][]const u8 = .{
    .{ "-m=", "--month=" },
    .{ "-d=", "--date=" },
    .{ "-e=", "--events=" },
    .{ "-b=", "--births=" },
    .{ "-s=", "--deaths=" },
};

/// Get a number from the options that can hold data
fn getNum(comptime T: type, arg: []const u8, idx: usize) MyError!T {
    inline for (valid_args_with_data[idx]) |opt| {
        if (std.mem.containsAtLeast(u8, arg, 1, opt)) {
            const index: usize = std.mem.indexOfScalar(u8, opt, '=').?;
            const num_str: []const u8 = arg[index + 1 ..];
            const num: T = std.fmt.parseInt(T, num_str, 10) catch |err| switch (err) {
                error.Overflow => return MyError.Overflow,
                error.InvalidCharacter => return MyError.InvalidArgs,
                else => unreachable,
            };
            return num;
        }
    }
    return MyError.NoNumber;
}

/// Get the index of the option from valid_args_with_data
fn indexOfArg(opt: []const u8) ?usize {
    var index: ?usize = std.mem.indexOfScalar(u8, opt, '=');
    if (index) |idx| {
        index = idx + 1;
    } else {
        index = opt.len;
    }
    for (valid_args_with_data, 0..) |args, i| {
        for (args) |arg| {
            if (std.mem.eql(u8, arg, opt[0..index.?])) return i;
        }
    }
    return null;
}

/// Get the field name of conds_t corresponding to index of argument in valid_args_with_data
fn getFieldName(idx: usize) MyError![]const u8 {
    if (idx > valid_args_with_data.len) return MyError.InvalidArgs;
    const long_name = valid_args_with_data[idx][1];
    const idx_name_end = std.mem.indexOfScalar(u8, long_name, '=').?;
    return long_name[2..idx_name_end];
}

/// Checks if date is valid
pub fn isDateValid(date: u5, month: u4) bool {
    // if (date > 31) return false; // Not reqd as date > 31 overflows
    if (month > 12) return false;
    if (month == 2 and date > 29) return false;
    if (month < 8) {
        if (month % 2 == 0 and date > 30 and month > 0) return false;
    } else {
        if (month % 2 != 0 and date > 30) return false;
    }
    return true;
}

/// As the name suggests
pub fn printHelpOnError(msg: []const u8) !void {
    const stderr = std.io.getStdErr().writer();
    try stderr.writeAll(msg);
    try stderr.writeAll(help_ops);
    std.process.exit(1);
}

/// Parses the arg and sets conds
pub fn parseArg(conds: *conds_t, arg: []const u8) MyError!void {
    // Courtesy: https://en.liujiacai.net/2022/12/14/argparser-in-zig/
    inline for (std.meta.fields(conds_t)) |field| {
        const idx = indexOfArg(arg) orelse return MyError.InvalidArgs;
        const name = try getFieldName(idx);

        if (std.mem.eql(u8, name, field.name)) {
            const num = try getNum(field.type, arg, idx);
            @field(conds.*, field.name) = num;
            break;
        }
    }
}

// Tests
test "validity of date" {
    try std.testing.expect(isDateValid(30, 2) == false);
    try std.testing.expect(isDateValid(24, 13) == false);
    try std.testing.expect(isDateValid(31, 6) == false);
    try std.testing.expect(isDateValid(31, 7) == true);
    try std.testing.expect(isDateValid(31, 8) == true);
    try std.testing.expect(isDateValid(31, 12) == true);
}

test "validity of arg" {
    try std.testing.expect(indexOfArg("-h") == null);
    try std.testing.expect(indexOfArg("--help") == null);
    try std.testing.expect(indexOfArg("-m=").? == 0);
    try std.testing.expect(indexOfArg("--month=").? == 0);
    try std.testing.expect(indexOfArg("-d=").? == 1);
    try std.testing.expect(indexOfArg("--date=").? == 1);
    try std.testing.expect(indexOfArg("-e=").? == 2);
    try std.testing.expect(indexOfArg("--events=").? == 2);
    try std.testing.expect(indexOfArg("-b=").? == 3);
    try std.testing.expect(indexOfArg("--births=").? == 3);
    try std.testing.expect(indexOfArg("-s=").? == 4);
    try std.testing.expect(indexOfArg("--deaths=").? == 4);
}

fn expectFieldName(opt: []const u8, field_name: []const u8) !bool {
    const name = try getFieldName(indexOfArg(opt).?);
    const result = std.mem.eql(u8, name, field_name);
    return result;
}

test "field name" {
    try std.testing.expect(try expectFieldName("-m=", "month"));
    try std.testing.expect(try expectFieldName("--month=", "month"));
    try std.testing.expect(try expectFieldName("-d=", "date"));
    try std.testing.expect(try expectFieldName("--date=", "date"));
    try std.testing.expect(try expectFieldName("-e=", "events"));
    try std.testing.expect(try expectFieldName("--events=", "events"));
    try std.testing.expect(try expectFieldName("-b=", "births"));
    try std.testing.expect(try expectFieldName("--births=", "births"));
    try std.testing.expect(try expectFieldName("-s=", "deaths"));
    try std.testing.expect(try expectFieldName("--deaths=", "deaths"));
}

test "parse args" {
    var conds = conds_t{};
    try parseArg(&conds, "-m=12");
    try std.testing.expect(conds.month == 12);
}
