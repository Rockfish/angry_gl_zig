const std = @import("std");
const zm = @import("zmath");
const Transform = @import("transform.zig").Transform;

const Vec2 = zm.Vec2;
const Vec3 = zm.Vec3;
const Vec4 = zm.Vec4;
const vec2 = zm.vec2;
const vec3 = zm.vec3;
const vec4 = zm.vec4;
const Mat4 = zm.Mat4;
const quat4 = zm.quat4;

const print = std.debug.print;

pub fn main() !void {
    std.debug.print("\n\n", .{});

    transform_operations();

    std.debug.print("\nDone.\n", .{});
}

fn transform_operations() void {
    const node_transform = Transform{
        .translation = vec4(-25.559093, 119.46429, 43.18399, 0.0),
        .rotation = quat4(0.26961806, -0.7235087, -0.587351, 0.24261194),
        .scale = vec4(1.0000002, 1.0000004, 1.0000004, 0.0),
    };

    const offset_transform = Transform{
        .translation = vec4(-82.265656, -130.9471, 5.502475, 0.0),
        .rotation = quat4(2.4412337e-9, -1.19209275e-7, -4.4703476e-8, 1.0),
        .scale = vec4(0.99999994, 1.0000001, 1.0, 0.0),
    };

    // const result_transform_matrix = Mat4{
    //     .x_axis = vec4(-0.7368923, -0.67513865, 0.03434265, 0.0),
    //     .y_axis = vec4(-0.10514542, 0.16464974, 0.9807328, 0.0),
    //     .z_axis = vec4(-0.6677847, 0.7190825, -0.19231756, 0.0),
    //     .w_axis = vec4(45.155804, 157.40128, -89.123566, 1.0),
    // };

    const result_transform_matrix = Mat4{
        vec4(-0.7368923, -0.67513865, 0.03434265, 0.0),
        vec4(-0.10514542, 0.16464974, 0.9807328, 0.0),
        vec4(-0.6677847, 0.7190825, -0.19231756, 0.0),
        vec4(45.155804, 157.40128, -89.123566, 1.0),
    };

    // from rust
    // point: Vec3(-82.265656, -130.9471, 5.502475)
    // scale * point: Vec3(-82.26568, -130.94714, 5.5024767)
    // rotation * point: Vec3(70.7149, 37.93699, -132.30756)
    // point + translation: Vec3(45.155804, 157.40128, -89.123566)

    // transform_point() is correct
    // mul_transform() is correct
    const mul_transform = node_transform.mul_transform(offset_transform);

    //
    const transform_matrix = mul_transform.compute_matrix();

    // from rust

    // node_transform = Transform { translation: Vec3(-25.559093, 119.46429, 43.18399), rotation: Quat(0.26961806, -0.7235087, -0.587351, 0.24261194), scale: Vec3(1.0000002, 1.0000004, 1.0000004) }
    // offset_transform = Transform { translation: Vec3(-82.265656, -130.9471, 5.502475), rotation: Quat(2.4412337e-9, -1.19209275e-7, -4.4703476e-8, 1.0), scale: Vec3(0.99999994, 1.0000001, 1.0) }

    // mul_transform = Transform { translation: Vec3(45.155804, 157.40128, -89.123566), rotation: Quat(0.26961803, -0.7235087, -0.5873511, 0.24261183), scale: Vec3(1.0000001, 1.0000005, 1.0000004) }
    // transform_matrix = Mat4 { x_axis: Vec4(-0.7368923, -0.67513865, 0.03434265, 0.0), y_axis: Vec4(-0.10514542, 0.16464974, 0.9807328, 0.0), z_axis: Vec4(-0.6677847, 0.7190825, -0.19231756, 0.0), w_axis: Vec4(45.155804, 157.40128, -89.123566, 1.0) }

    print("\n", .{});
    print("node_transform = {any}\n", .{node_transform});
    print("offset_transform = {any}\n", .{offset_transform});
    print("\n", .{});
    print("mul_transform_matrix = {any}\n", .{mul_transform});
    print("\n", .{});
    print("        transform_matrix = {any}\n", .{transform_matrix});
    print("desired transform_matrix = {any}\n", .{result_transform_matrix});
    print("\n", .{});

    const result_transform = Transform.from_matrix(transform_matrix); // correct.
    print("transform_matrix = {any}\n", .{transform_matrix});
    print("result_transform = {any}\n", .{result_transform});
    print("\n", .{});

    // weight transform from rust
    // initial transform = Transform { translation: Vec3(-24.47548, 120.0374, -20.876072), rotation: Quat(-0.012059034, -0.7141586, -0.04901746, 0.69816136), scale: Vec3(0.99999994, 1.0, 0.99999994) }
    // global_transform = Transform { translation: Vec3(-29.441895, 134.63986, -34.91539), rotation: Quat(-0.084138356, -0.6796187, -0.16701107, 0.70932823), scale: Vec3(1.0, 0.99999994, 1.0) }
    // weight = 0.009377446
    // result = Transform { translation: Vec3(-24.52205, 120.17433, -21.007725), rotation: Quat(-0.012738415, -0.7139017, -0.050132398, 0.698333), scale: Vec3(0.99999994, 1.0, 0.99999994) }
    const initial_transform = Transform{
        .translation = vec4(-24.47548, 120.0374, -20.876072, 0.0),
        .rotation = quat4(-0.012059034, -0.7141586, -0.04901746, 0.69816136),
        .scale = vec4(0.99999994, 1.0, 0.99999994, 0.0)
    };

    const global_transform = Transform{
        .translation = vec4(-29.441895, 134.63986, -34.91539, 0.0),
        .rotation = quat4(-0.084138356, -0.6796187, -0.16701107, 0.70932823),
        .scale = vec4(1.0, 0.99999994, 1.0, 0.0)
    };

    const weight = 0.009377446;

    const weighted_result = initial_transform.mul_transform_weighted(global_transform, weight); // correct

    print("initial_transform = {any}\n", .{initial_transform});
    print("global_transform = {any}\n", .{global_transform});
    print("weight = {any}\n", .{weight});
    print("weighted_result = {any}\n", .{weighted_result});
    print("\n", .{});

}
