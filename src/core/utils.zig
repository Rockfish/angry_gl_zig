const std = @import("std");

pub fn bufCopyZ(buf: []u8, source: []const u8) [:0]const u8 {
    std.mem.copyForwards(u8, buf, source);
    buf[source.len] = 0;
    return buf[0..source.len :0];
}

pub fn fileExists(path: []const u8) bool {
    const stat = std.fs.cwd().statFile(path) catch return false;
    return stat.kind == .file;
}

/// Attempts to fix odd file paths that might be found in model files.
pub fn getExistsFilename(allocator: std.mem.Allocator, directory: []const u8, filename: []const u8) ![]const u8 {
    var path = try std.fs.path.join(allocator, &[_][]const u8{ directory, filename });

    if (fileExists(path)) {
        return path;
    }

    const filepath = try std.mem.replaceOwned(u8, allocator, filename, "\\", "/");
    defer allocator.free(filepath);

    const file_name = std.fs.path.basename(filepath);
    path = try std.fs.path.join(allocator, &[_][]const u8{ directory, file_name });

    if (fileExists(path)) {
        return path;
    }

    std.debug.print("getExistsFilename file not found error. initial filename: {s}  fixed filename: {s}\n", .{filename, path});
    @panic("getExistsFilename file not found error.");
}

pub fn retain(comptime TA: type, comptime TS: type, list: *std.ArrayList(?*TA), tester: TS, allocator: std.mem.Allocator) !void {
    _ = allocator;
    const length = list.items.len;
    var i: usize = 0;
    var f: usize = 0;
    var flag = true;
    var count: usize = 0;

    while (true) {
        // test if false
        if (i < length and (list.items[i] == null or !tester.predicate(list.items[i].?))) {
            if (flag) {
                f = i;
                flag = false;
            }

            while (i < length and (list.items[i] == null or !tester.predicate(list.items[i].?))) {
                i += 1;
            }

            // move true to here
            if (i < length) {
                const delete = list.items[f];
                list.items[f] = list.items[i];
                list.items[i] = null;

                if (delete != null) {
                    delete.?.deinit();
                    // allocator.destroy(delete.?);
                }
                f += 1;
                count += 1;
            }
        } else {
            count += 1;
            // fill in gaps
            if (i < length and f < i and flag == false) {
                const delete = list.items[f];
                list.items[f] = list.items[i];
                list.items[i] = null;

                if (delete != null) {
                    delete.?.deinit();
                    // allocator.destroy(delete.?);
                }
                f += 1;
            }
        }
        i += 1;
        if (i >= length) {
            break;
        }
    }

    // delete remainder
    if (count < length) {
        for (list.items[count..length]) |d| {
            if (d != null) {
                d.?.deinit();
                // allocator.destroy(d.?);
            }
        }
        list.items = list.items[0..count];
    }
}

pub fn removeRange(comptime T: type, list: *std.ArrayList(T), start: usize, end: usize) !void {
    if (start >= end or end >= list.items.len) {
        return error.InvalidRange;
    }
    const count = end - start + 1;

    // Call deinit on each item in the range
    // for (start..end) |i| {
    //     list.items[i].deinit();
    // }

    // Move the items to fill the gap
    for (end + 1..list.items.len) |i| {
        list.items[i - count] = list.items[i];
    }

    // Update the length of the list
    list.shrinkAndFree(list.items.len - count);
}
