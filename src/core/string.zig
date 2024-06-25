// very simple string thingy
const std = @import("std");
const Assimp = @import("assimp.zig").Assimp;

const Allocator = std.mem.Allocator;

var _allocator: Allocator = undefined;

pub fn init(allocator: Allocator) void {
    _allocator = allocator;
}

pub const String = struct {
    str: []const u8,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        _allocator.free(self.str);
        _allocator.destroy(self);
    }

    pub fn new(str: []const u8) !*String {
        const string = try _allocator.create(String);
        string.* = String {
            .str = try _allocator.dupe(u8, str),
        };
        return string;
    }

    pub fn from_aiString(ai_string: Assimp.aiString) !*String {
        const str = ai_string.data[0..ai_string.length];
        return try String.new(str);
    }

    pub fn clone(self: *Self) !*String {
        return try String.new(self.str);
    }

    pub fn equals(self: *Self, other: *String) bool {
        return std.mem.eql(u8, self.str, other.str);
    }

    pub fn equalsU8(self: *Self, other: []const u8) bool {
        return std.mem.eql(u8, self.str, other);
    }

    pub fn startsWith(self: *const Self, other: *String) bool {
        if (other.str.len > self.str.len) {
            return false;
        }
        return std.mem.eql(u8, self.str[0..other.str.len], other.str);
    }

    pub fn startsWithU8(self: *const Self, other: []const u8) bool {
        if (other.len > self.str.len) {
            return false;
        }
        return std.mem.eql(u8, self.str[0..other.len], other);
    }
};
