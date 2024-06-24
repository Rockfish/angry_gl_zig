const std = @import("std");
const debug = std.debug;
const assert = debug.assert;
const testing = std.testing;

pub fn removeRange(comptime T: type, list: *std.ArrayList(T), start: usize, end: usize) !void {
    if (start >= end or end > list.items.len) {
        return error.InvalidRange;
    }
    const count = end - start; // + 1;

    // Call deinit on each item in the range if T is a pointer type
    if (@typeInfo(T) == .Pointer) {
        for (start..end) |i| {
            list.items[i].deinit();
        }
    }

    // Move the items to fill the gap
    for (end..list.items.len) |i| {
        list.items[i - count] = list.items[i];
    }

    // Update the length of the list
    list.shrinkRetainingCapacity(list.items.len - count);
}

fn hasDeinit(comptime T: type) bool {
    const type_info = @typeInfo(T);
    const target_type = switch (type_info) {
        .Pointer => type_info.Pointer.child,
        else => T,
    };

    const deinitFn = @field(target_type, "deinit") catch return false;
    return @TypeOf(deinitFn) == fn (target_type) void;
}

//  try core.utils.removeRange(Vec3, &self.all_bullet_positions, 0, first_live_bullet);
test "removeRange.removeVec" {
    debug.print("\n", .{});

    const a = testing.allocator;

    const testVec3 = struct { x: usize, y: usize, z: usize };

    const items = a.create(std.ArrayList(testVec3)) catch unreachable;
    items.* = std.ArrayList(testVec3).init(a);

    debug.print("items type = {s}\n", .{@typeName(@TypeOf(items))});

    for (0..10) |i| {
        const tv: testVec3 = .{.x = i, .y = i, .z = i};
        items.append(tv) catch unreachable;
    }


    for (items.items, 0..) |item, c| {
        debug.print("{d} : item = {any}\n", .{c, item});
    }

    debug.print("\n", .{});

    removeRange(testVec3, items, 1, 10) catch unreachable;

    for (items.items, 0..) |item, c| {
        debug.print("{d} : item = {any}\n", .{c, item});
    }

    debug.print("items.items.len = {d}\n", .{items.items.len});

    items.deinit();
    a.destroy(items);
}

test "removeRange.removePtrVec" {
    debug.print("\n", .{});

    const testVec3Ptr = struct {
        x: usize, y: usize, z: usize,
        a: std.mem.Allocator,

        const Self = @This();
        pub fn deinit(self: *Self) void {
            self.a.destroy(self);
        }
    };

    const a = testing.allocator;

    const items = a.create(std.ArrayList(*testVec3Ptr)) catch unreachable;
    items.* = std.ArrayList(*testVec3Ptr).init(a);

    debug.print("items type = {s}\n", .{@typeName(@TypeOf(items))});

    for (0..10) |i| {
        const tv = a.create(testVec3Ptr) catch unreachable;
        tv.* = .{.x = i, .y = i, .z = i, .a = a};
        items.append(tv) catch unreachable;
    }

    for (items.items, 0..) |item, c| {
        debug.print("{d} : item = {any}\n", .{c, item});
    }

    debug.print("\n", .{});

    removeRange(*testVec3Ptr, items, 0, 10) catch unreachable;

    for (items.items, 0..) |item, c| {
        debug.print("{d} : item = {any}\n", .{c, item});
    }

    debug.print("items.items.len = {d}\n", .{items.items.len});

    for (items.items) |item| {
        item.*.deinit();
    }

    items.deinit();
    a.destroy(items);
}