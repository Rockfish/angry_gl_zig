
const std = @import("std");
const zm = @import("zmath");
const Assimp = @import("assimp.zig").Assimp;
const Transform = @import("transform.zig").Transform;

pub fn bufCopyZ(buf: []u8, source: []const u8) [:0]const u8 {
    std.mem.copyForwards(u8, buf, source);
    buf[source.len] = 0;
    return buf[0 .. source.len :0];
}

pub fn mat4_from_aiMatrix(aiMatrix: Assimp.aiMatrix4x4) zm.Mat4 {
    // todo: implement mat4_from_aiMatrix
    _ = aiMatrix;
    return zm.identity();
}

pub fn vec4_from_aiVector3D(vec3d: Assimp.aiVector3D) zm.Vec4 {
    return .{vec3d.x, vec3d.y, vec3d.z, 0.0 };
}

pub fn quat_from_aiQuaternion(ai_quad: Assimp.aiQuaternion) zm.Quat {
    // todo: implment quat_from_aiQuaternion
    _ = ai_quad;
    return .{0.0, 0.0, 0.0, 1.0};
}

pub fn transfrom_from_aiMatrix(m: Assimp.aiMatrix4x4) Transform {
    // todo!
    _ = m;

    return Transform {
        .translation = undefined,
        .rotation = undefined,
        .scale = undefined,
    };
}

pub fn retain(comptime T: type, list: *std.ArrayList(?*T), testFn: *const fn (a: *T) bool, allocator: std.mem.Allocator) !void {
    const length = list.items.len;
    var i: usize = 0;
    var f: usize = 0;
    var flag = true;
    var count: usize = 0;

    while (true) {
        // test if false
        if (i < length and (list.items[i] == null or !testFn(list.items[i].?))) {
            if (flag) {
                f = i;
                flag = false;
            }

            while (i < length and (list.items[i] == null or !testFn(list.items[i].?))) {
                i += 1;
            }

            // move true to here
            if (i < length) {
                const delete = list.items[f];
                list.items[f] = list.items[i];
                list.items[i] = null;

                if (delete != null) {
                    allocator.destroy(delete.?);
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
                    allocator.destroy(delete.?);
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
    for (list.items[count..length]) |d| {
        if (d != null) {
            allocator.destroy(d.?);
        }
    }

    list.items = list.items[0..count];
}