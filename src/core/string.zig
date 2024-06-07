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
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.str);
        self.allocator.destroy(self);
    }

    pub fn new(str: []const u8) !*String {
        const string = try _allocator.create(String);
        string.* = String {
            .str = try _allocator.dupe(u8, str),
            .allocator = _allocator,
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
};
