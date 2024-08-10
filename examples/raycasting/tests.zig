const std = @import("std");
const math = @import("math");

pub fn test_rotation() void {
    const vec3 = math.vec3;
    //const vec4 = math.vec4;
    //const Mat4 = math.Mat4;
    const Quat = math.Quat;

    const up = vec3(0.0, 1.0, 0.0);
    const speed = 1.0;
    const move = 1.0;

    _ = speed;
    _ = move;

    const forward = vec3(0.0, 0.0, -1.0);
    var position = vec3(0.0, 0.0, 6.0);
    const target = vec3(0.0, 0.0, 0.0);

    _ = forward;
    std.debug.print("initial position: {d}, {d}, {d}\n", .{ position.x, position.y, position.z });
    std.debug.print("target: {d}, {d}, {d}\n", .{ target.x, target.y, target.z });

    const angle = to_rads(5.0);
    const turn_rotation = Quat.fromAxisAngle(&up, angle);
    const radius_vec = position.sub(&target);
    const right = turn_rotation.rotateVec(&radius_vec);
    // position = position.add(&right.mulScalar(speed * move));
    position = target.add(&right);

    //std.debug.print("forward: {d}, {d}, {d}\n", .{ forward.x, forward.y, forward.z });
    std.debug.print("right: {d}, {d}, {d}\n", .{ right.x, right.y, right.z });
    std.debug.print("position: {d}, {d}, {d}\n", .{ position.x, position.y, position.z });
}

pub inline fn to_rads(degrees: f32) f32 {
    return degrees * std.math.rad_per_deg;
}

pub fn test_aabb_transform() !void {
    const aabb = math.AABB{
        .min = math.vec3(0.0, 1.0, 2.0),
        .max = math.vec3(3.0, 4.0, 5.0),
    };

    const transfrom = math.Mat4.identity();

    const result_c = aabb.aabb_transform(&transfrom);
    const result_zig = aabb.aabb_transform_zig(&transfrom);
    std.debug.print("aabb: {any}\nresult_c: {any}\nresult_zig: {any}\n", .{ aabb, result_c, result_zig });

    try std.testing.expectEqual(result_c, result_zig);
}
