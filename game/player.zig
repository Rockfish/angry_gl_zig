const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Player = struct {

    const Self = @This();

    pub fn new(allocator: Allocator) Self {
        _ = allocator;
        return .{};
    }
};