const std = @import("std");
const Gltf = @import("zgltf/src/main.zig");

pub fn getBufferSlice(comptime T: type, gltf: *Gltf, accessor_id: usize) []T {
    const accessor = gltf.data.accessors.items[accessor_id];
    if (@sizeOf(T) != accessor.stride) {
        std.debug.panic("sizeOf(T) : {d} does not equal accessor.stride: {d}", .{@sizeOf(T), accessor.stride});
    }
    const buffer_view = gltf.data.buffer_views.items[accessor.buffer_view.?];
    const glb_buf = gltf.buffer_data.items[buffer_view.buffer];
    const start = accessor.byte_offset + buffer_view.byte_offset;
    const end = start + buffer_view.byte_length;
    const slice = glb_buf[start..end];
    const data = @as([*]T, @ptrCast(@alignCast(@constCast(slice))))[0..accessor.count];
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

