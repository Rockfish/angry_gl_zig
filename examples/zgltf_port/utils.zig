const std = @import("std");
const Gltf = @import("zgltf/src/main.zig");

pub fn getBufferSlice(comptime T: type, gltf: *Gltf, accessor_id: usize) []T {
    const accessor = gltf.data.accessors.items[accessor_id];

    // Don't think this is correct, think it should be fine as long as stride > than sizeOf
    if (@sizeOf(T) != accessor.stride) {
        std.log.err("sizeOf(T) : {d} does not equal accessor.stride: {d}, which is not supported yet", .{@sizeOf(T), accessor.stride});
    }

    const buffer_view = gltf.data.buffer_views.items[accessor.buffer_view.?];
    const buffer = gltf.buffer_data.items[buffer_view.buffer];

    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + buffer_view.byte_length;
    
    const slice = buffer[start..end];

    // these doesn't work in all cases because the stride can be greater then sizeOf(T)
    const data = @as([*]T, @ptrCast(@alignCast(@constCast(slice))))[0..accessor.count * accessor.stride];
    return data;
}

// Cheap string hash
pub fn stringHash(str: []const u8, seed: u32) u32 {
    var hash: u32 = seed;
    if (str.len == 0) return hash;

    for (str) |char| {
        hash = ((hash << 5) - hash) + @as(u32, @intCast(char));
    }
    return hash;
}

