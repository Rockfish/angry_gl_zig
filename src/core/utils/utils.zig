const std = @import("std");

const retain_ = @import("retain.zig");
const remove_ = @import("remove.zig");

pub const retain = retain_.retain;
pub const removeRange = remove_.removeRange;

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



