const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const core = @import("core");
const math = @import("math");

const cglm = math.cglm;

const gl = zopengl.bindings;

const Assimp = core.assimp.Assimp;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const animation = core.animation;
const Camera = core.Camera;
const Shader = core.Shader;
const String = core.string.String;
const FrameCount = core.FrameCount;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const quat = math.quat;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const Animator = animation.Animator;
const AnimationClip = animation.AnimationClip;
const AnimationRepeat = animation.AnimationRepeatMode;
const Transform = core.Transform;

const print = std.debug.print;

pub fn transform_operations() void {
    {
        const node_transform = Transform{
            .translation = vec3(-25.559093, 119.46429, 43.18399),
            .rotation = quat(0.26961806, -0.7235087, -0.587351, 0.24261194),
            .scale = vec3(1.0000002, 1.0000004, 1.0000004),
        };

        const offset_transform = Transform{
            .translation = vec3(-82.265656, -130.9471, 5.502475),
            .rotation = quat(2.4412337e-9, -1.19209275e-7, -4.4703476e-8, 1.0),
            .scale = vec3(0.99999994, 1.0000001, 1.0),
        };

        // const result_transform_matrix = Mat4{
        //     .x_axis = vec4(-0.7368923, -0.67513865, 0.03434265, 0.0),
        //     .y_axis = vec4(-0.10514542, 0.16464974, 0.9807328, 0.0),
        //     .z_axis = vec4(-0.6677847, 0.7190825, -0.19231756, 0.0),
        //     .w_axis = vec4(45.155804, 157.40128, -89.123566, 1.0),
        // };

        const result_transform_matrix: Mat4 = Mat4.from_cols(
            vec4(-0.7368923, -0.67513865, 0.03434265, 0.0),
            vec4(-0.10514542, 0.16464974, 0.9807328, 0.0),
            vec4(-0.6677847, 0.7190825, -0.19231756, 0.0),
            vec4(45.155804, 157.40128, -89.123566, 1.0),
        );

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

        const result_transform = Transform.from_matrix(&transform_matrix); // correct.
        print("transform_matrix = {any}\n", .{transform_matrix});
        print("result_transform = {any}\n", .{result_transform});
        print("\n", .{});

        // weight transform from rust
        // initial transform = Transform { translation: Vec3(-24.47548, 120.0374, -20.876072), rotation: Quat(-0.012059034, -0.7141586, -0.04901746, 0.69816136), scale: Vec3(0.99999994, 1.0, 0.99999994) }
        // global_transform = Transform { translation: Vec3(-29.441895, 134.63986, -34.91539), rotation: Quat(-0.084138356, -0.6796187, -0.16701107, 0.70932823), scale: Vec3(1.0, 0.99999994, 1.0) }
        // weight = 0.009377446
        // result = Transform { translation: Vec3(-24.52205, 120.17433, -21.007725), rotation: Quat(-0.012738415, -0.7139017, -0.050132398, 0.698333), scale: Vec3(0.99999994, 1.0, 0.99999994) }
        const initial_transform = Transform{
            .translation = vec3(-24.47548, 120.0374, -20.876072),
            .rotation = quat(-0.012059034, -0.7141586, -0.04901746, 0.69816136),
            .scale = vec3(0.99999994, 1.0, 0.99999994)
        };

        const global_transform = Transform{
            .translation = vec3(-29.441895, 134.63986, -34.91539),
            .rotation = quat(-0.084138356, -0.6796187, -0.16701107, 0.70932823),
            .scale = vec3(1.0, 0.99999994, 1.0)
        };

        const weight = 0.009377446;

        const weighted_result = initial_transform.mul_transform_weighted(global_transform, weight); // correct

        print("initial_transform = {any}\n", .{initial_transform});
        print("global_transform = {any}\n", .{global_transform});
        print("weight = {any}\n", .{weight});
        print("weighted_result = {any}\n", .{weighted_result});
    }
    {

        // from rust
        // aiMatrix = aiMatrix4x4 { a1: 1.0, a2: 0.0, a3: 0.0, a4: -24.243824, b1: 0.0, b2: 1.0, b3: -6.610211e-8, b4: -14.433588, c1: 0.0, c2: 6.610211e-8, c3: 1.0, c4: 4.5035524, d1: 0.0, d2: 0.0, d3: 0.0, d4: 1.0 }
        // mat = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 6.610211e-8, 0.0, 0.0, -6.610211e-8, 1.0, 0.0, -24.243824, -14.433588, 4.5035524, 1.0]

        // from zig 2
        // aiMatrix = aiMatrix4x4{ .a1 = 1e0, .a2 = 0e0, .a3 = 0e0, .a4 = -2.4243824e1, .b1 = 0e0, .b2 = 1e0, .b3 = -6.610211e-8, .b4 = -1.4433588e1, .c1 = 0e0, .c2 = 6.610211e-8, .c3 = 1e0, .c4 = 4.5035524e0, .d1 = 0e0, .d2 = 0e0, .d3 = 0e0, .d4 = 1e0 }
        // mat = { 1e0, 0e0, 0e0, 0e0, 0e0, 1e0, 6.610211e-8, 0e0, 0e0, -6.610211e-8, 1e0, 0e0, -2.4243824e1, -1.4433588e1, 4.5035524e0, 1e0 }

        // rust
        // NodeAnimation[0] position[0] = KeyPosition { position: Vec3(-1.1496555e-5, 9.356725, 3.478571), time_stamp: 50.0 }
        // NodeAnimation[0] rotations[0] = KeyRotation { orientation: Quat(0.0, 0.0, 0.0, 1.0), time_stamp: 50.0 }
        // NodeAnimation[0] scales[0] = KeyScale { scale: Vec3(1.0, 0.99999994, 1.0), time_stamp: 50.0 }

        // zig
        // NodeAnimation[0] position[0] = core.node_animation.KeyPosition{ .position = { -1.1496555e-5, 9.356725e0, 3.478571e0, 0e0 }, .time_stamp = 5e1 }
        // NodeAnimation[0] rotations[0] = core.node_animation.KeyRotation{ .orientation = { 0e0, 0e0, 0e0, 1e0 }, .time_stamp = 5e1 }
        // NodeAnimation[0] scales[0] = core.node_animation.KeyScale{ .scale = { 1e0, 9.9999994e-1, 1e0, 0e0 }, .time_stamp = 5e1 }

        // orientation = { 0e0, 0e0, 0e0, 1e0 }
        // rotation = { nan, nan, nan, inf }
        const orientation: Vec4 = Vec4.new( 0e0, 0e0, 0e0, 1e0 );
        const rotation3 = orientation.normalizeTo();

        std.debug.print("orientation = {any}  rotation3 = {any} \n", .{orientation, rotation3});

        // rust bones
        // finalBonesMatrices[0]  bone_transform = Mat4 { x_axis: Vec4(0.5087325, 0.119134754, 0.8526418, 0.0), y_axis: Vec4(-0.06421837, 0.9928712, -0.10041203, 0.0), z_axis: Vec4(-0.858526, -0.0036724054, 0.51275647, 0.0), w_axis: Vec4(5.9589906, -13.970596, 14.851699, 1.0) }
        // finalBonesMatrices[1]  bone_transform = Mat4 { x_axis: Vec4(0.70931125, 0.31911877, 0.6285229, 0.0), y_axis: Vec4(-0.039144438, 0.90811056, -0.4168974, 0.0), z_axis: Vec4(-0.70380783, 0.2711068, 0.6566246, 0.0), w_axis: Vec4(-0.17534828, -8.2896805, 52.710648, 1.0) }
        // finalBonesMatrices[2]  bone_transform = Mat4 { x_axis: Vec4(0.72448534, 0.3167287, 0.612213, 0.0), y_axis: Vec4(-0.38460916, 0.9228112, -0.022275042, 0.0), z_axis: Vec4(-0.5720119, -0.21932462, 0.7903796, 0.0), w_axis: Vec4(18.659718, -7.5574265, 30.29604, 1.0) }
        // finalBonesMatrices[40]  bone_transform = Mat4 { x_axis: Vec4(0.92669636, 0.07759953, 0.36771378, 0.0), y_axis: Vec4(-0.09362594, 0.99527043, 0.025917724, 0.0), z_axis: Vec4(-0.36396334, -0.058445368, 0.9295784, 0.0), w_axis: Vec4(-4.6102123, -17.084442, 3.5402665, 1.0) }
        // mesh name = Player  nodeTransform = Mat4 { x_axis: Vec4(1.0, 0.0, 0.0, 0.0), y_axis: Vec4(0.0, 1.0, 0.0, 0.0), z_axis: Vec4(0.0, 0.0, 1.0, 0.0), w_axis: Vec4(0.0, 0.0, 0.0, 1.0) }
        // mesh name = Gun  nodeTransform = Mat4 { x_axis: Vec4(-0.023347735, 0.039729923, 0.99893785, 0.0), y_axis: Vec4(0.019812306, 0.9990322, -0.03927063, 0.0), z_axis: Vec4(-0.99953127, 0.018874392, -0.024112225, 0.0), w_axis: Vec4(-30.257719, 26.143032, -93.78992, 1.0) }

        // zig bones
        // finalBonesMatrices[0]  bone_transform = { { 5.087323e-1, 1.1913478e-1, 8.52642e-1, 0e0 }, { -6.421838e-2, 9.928713e-1, -1.00412056e-1, 0e0 }, { -8.585262e-1, -3.6724205e-3, 5.127563e-1, 0e0 }, { 5.958991e0, -1.3970589e1, 1.4851701e1, 0e0 } }
        // finalBonesMatrices[1]  bone_transform = { { 6.433309e-1, 4.3044204e-1, 6.3312364e-1, 0e0 }, { -3.4882516e-1, 9.009524e-1, -2.58082e-1, 0e0 }, { -6.815033e-1, -5.481729e-2, 7.2975916e-1, 0e0 }, { 3.4971607e1, -8.196602e0, 3.4872955e1, 0e0 } }
        // finalBonesMatrices[2]  bone_transform = { { 6.5979975e-1, 5.3248074e-2, 7.495532e-1, 0e0 }, { -3.472517e-1, 9.0619755e-1, 2.4129489e-1, 0e0 }, { -6.6639435e-1, -4.1948962e-1, 6.1639905e-1, 0e0 }, { 3.450128e1, 2.899971e-1, 4.599289e0, 0e0 } }
        // finalBonesMatrices[40]  bone_transform = { { 8.7443954e-1, 5.7476503e-3, 4.8510176e-1, 0e0 }, { 3.2702167e-2, 9.969575e-1, -7.076091e-2, 0e0 }, { -4.8403233e-1, 7.7739984e-2, 8.715908e-1, 0e0 }, { -1.1082136e1, -1.7411758e1, 2.789093e1, 0e0 } }
        // mesh name = Player  nodeTransform = { { 1e0, 0e0, 0e0, 0e0 }, { 0e0, 1e0, 0e0, 0e0 }, { 0e0, 0e0, 1e0, 0e0 }, { 0e0, 0e0, 0e0, 0e0 } }
        // mesh name = Gun  nodeTransform = { { -2.3347497e-2, 3.9729957e-2, 9.989377e-1, 0e0 }, { 1.9812282e-2, 9.990322e-1, -3.9270658e-2, 0e0 }, { -9.9953115e-1, 1.8874366e-2, -2.4111986e-2, 0e0 }, { -3.025772e1, 2.614302e1, -9.378992e1, 0e0 } }

        // rust calculate transform maps
        // calculate_transform_maps  node_data.name = Character1_Hips  parent_transform = Transform { translation: Vec3(0.0, 0.0, 0.0), rotation: Quat(0.0, 0.0, 0.0, 1.0), scale: Vec3(1.0, 1.0, 1.0) }  global_transform = Transform { translation: Vec3(-1.5485802, 102.102905, 3.1128397), rotation: Quat(-0.02785973, -0.4927937, 0.052803274, 0.86809564), scale: Vec3(1.0000002, 1.0000002, 1.0000001) }
        // calculate_transform_maps  node_data.name = Character1_LeftUpLeg  parent_transform = Transform { translation: Vec3(-1.5485802, 102.102905, 3.1128397), rotation: Quat(-0.02785973, -0.4927937, 0.052803274, 0.86809564), scale: Vec3(1.0000002, 1.0000002, 1.0000001) }  global_transform = Transform { translation: Vec3(3.8379974, 97.5582, 17.625187), rotation: Quat(-0.19011967, -0.368163, 0.098997265, 0.9047155), scale: Vec3(1.0000005, 1.0000005, 1.0000004) }
        // calculate_transform_maps  node_data.name = Character1_LeftLeg  parent_transform = Transform { translation: Vec3(3.8379974, 97.5582, 17.625187), rotation: Quat(-0.19011967, -0.368163, 0.098997265, 0.9047155), scale: Vec3(1.0000005, 1.0000005, 1.0000004) }  global_transform = Transform { translation: Vec3(9.832235, 50.41722, 43.90512), rotation: Quat(0.05313893, -0.31935343, 0.18913183, 0.9270485), scale: Vec3(1.0000006, 1.0000006, 1.0000005) }

        // zig calculate transform maps
        // calculate_transform_maps  node_data.name = Character1_Hips  parent_transform = core.transform.Transform{ .translation = { 0e0, 0e0, 0e0, 0e0 }, .rotation = { 0e0, 0e0, 0e0, 1e0 }, .scale = { 1e0, 1e0, 1e0, 0e0 } }  global_transform = core.transform.Transform{ .translation = { -1.5485802e0, 1.02102905e2, 3.1128397e0, 0e0 }, .rotation = { -2.7859729e-2, -4.927937e-1, 5.280327e-2, 8.6809564e-1 }, .scale = { 1.0000002e0, 1.0000002e0, 1.0000001e0, 0e0 } }
        // calculate_transform_maps  node_data.name = Character1_LeftUpLeg  parent_transform = core.transform.Transform{ .translation = { -1.5485802e0, 1.02102905e2, 3.1128397e0, 0e0 }, .rotation = { -2.7859729e-2, -4.927937e-1, 5.280327e-2, 8.6809564e-1 }, .scale = { 1.0000002e0, 1.0000002e0, 1.0000001e0, 0e0 } }  global_transform = core.transform.Transform{ .translation = { 3.8379965e0, 9.75582e1, 1.7625189e1, 0e0 }, .rotation = { -5.617182e-2, -3.6326978e-1, 2.1533626e-1, 9.047155e-1 }, .scale = { 1.0000005e0, 1.0000005e0, 1.0000004e0, 0e0 } }
        // calculate_transform_maps  node_data.name = Character1_LeftLeg  parent_transform = core.transform.Transform{ .translation = { 3.8379965e0, 9.75582e1, 1.7625189e1, 0e0 }, .rotation = { -5.617182e-2, -3.6326978e-1, 2.1533626e-1, 9.047155e-1 }, .scale = { 1.0000005e0, 1.0000005e0, 1.0000004e0, 0e0 } }  global_transform = core.transform.Transform{ .translation = { 2.6183197e1, 5.135757e1, 3.5374313e1, 0e0 }, .rotation = { 1.8520492e-1, -3.9686233e-1, 1.1225224e-1, 8.9196354e-1 }, .scale = { 1.0000006e0, 1.0000006e0, 1.0000005e0, 0e0 } }

        // rust
        // get_animation_transform current_tick = 134.0
        // parent_transform = Transform { translation: Vec3(2.567844, 107.55968, 5.1279597), rotation: Quat(0.0073709576, -0.064708374, -0.04417714, 0.99689865), scale: Vec3(1.0000002, 1.0000002, 1.0000002) }
        // node_transform = Transform { translation: Vec3(14.572726, -6.31544, 2.8334708), rotation: Quat(-0.34014052, 0.050750144, 0.0056805885, 0.938987), scale: Vec3(1.0000001, 1.0000002, 1.0000002) }
        // global_transform = Transform { translation: Vec3(16.044008, 99.94666, 9.6790905), rotation: Quat(-0.33029, 0.0048169913, -0.057454653, 0.942117), scale: Vec3(1.0000004, 1.0000005, 1.0000005) }

        // zig
        // get_animation_transform current_tick = 1.34e2
        // parent_transform = core.transform.Transform{ .translation = { 2.567844e0, 1.0755968e2, 5.1279597e0, 0e0 }, .rotation = { 7.3709576e-3, -6.4708374e-2, -4.417714e-2, 9.9689865e-1 }, .scale = { 1.0000002e0, 1.0000002e0, 1.0000002e0, 0e0 } }
        // node_transform = core.transform.Transform{ .translation = { 1.4572726e1, -6.31544e0, 2.8334708e0, 0e0 }, .rotation = { -3.4014052e-1, 5.0750144e-2, 5.680588e-3, 9.38987e-1 }, .scale = { 1.0000002e0, 1.0000002e0, 1.0000002e0, 0e0 } }
        // global_transform = core.transform.Transform{ .translation = { 1.6044008e1, 9.994666e1, 9.6790905e0, 0e0 }, .rotation = { -3.3403882e-1, -2.515214e-2, -1.4182929e-2, 9.42117e-1 }, .scale = { 1.0000005e0, 1.0000005e0, 1.0000005e0, 0e0 } }

        const parent_transform = Transform{
            .translation = vec3(2.567844e0, 1.0755968e2, 5.1279597e0 ),
            .rotation = quat(7.3709576e-3, -6.4708374e-2, -4.417714e-2, 9.9689865e-1 ),
            .scale = vec3(1.0000002e0, 1.0000002e0, 1.0000002e0 ),
        };

        const node_transform = Transform{
            .translation = vec3(1.4572726e1, -6.31544e0, 2.8334708e0 ),
            .rotation = quat(-3.4014052e-1, 5.0750144e-2, 5.680588e-3, 9.38987e-1 ),
            .scale = vec3(1.0000002e0, 1.0000002e0, 1.0000002e0 ),
        };
        _ = parent_transform;
        _ = node_transform;

        // doesn't agree with rust
        // const global_transform = Transform{
        //     .translation = .{ 1.6044008e1, 9.994666e1, 9.6790905e0, 0e0 },
        //     .rotation = .{ -3.3403882e-1, -2.515214e-2, -1.4182929e-2, 9.42117e-1 }, // diff
        //     .scale = .{ 1.0000005e0, 1.0000005e0, 1.0000005e0, 0e0 }
        // };

        const parent_rotation =  quat(7.3709576e-3, -6.4708374e-2, -4.417714e-2, 9.9689865e-1);
        const node_rotation = quat(-3.4014052e-1, 5.0750144e-2, 5.680588e-3, 9.38987e-1);

        const global_rotation = node_rotation.mulQuat(&parent_rotation); // reverse operands!

        std.debug.print("\n", .{});
        std.debug.print("parent_rotation = {any}\n", .{parent_rotation});
        std.debug.print("node_rotation = {any}\n", .{node_rotation});
        std.debug.print("global_rotation = {any}\n", .{global_rotation});
    }

// rust
// mesh name = Player  nodeTransform = Mat4 { x_axis: Vec4(1.0, 0.0, 0.0, 0.0), y_axis: Vec4(0.0, 1.0, 0.0, 0.0), z_axis: Vec4(0.0, 0.0, 1.0, 0.0), w_axis: Vec4(0.0, 0.0, 0.0, 1.0) }
// mesh name = Gun  nodeTransform = Mat4 { x_axis: Vec4(0.0833236, -0.09724815, 0.99176615, 0.0), y_axis: Vec4(0.24570267, 0.96650666, 0.07412852, 0.0), z_axis: Vec4(-0.9657574, 0.23750292, 0.10442692, 0.0), w_axis: Vec4(-56.49005, 56.790943, -81.72132, 1.0) }
// finalBonesMatrices[0]  bone_transform = Mat4 { x_axis: Vec4(0.98772234, -0.089034185, 0.12836412, 0.0), y_axis: Vec4(0.08712633, 0.995988, 0.020413456, 0.0), z_axis: Vec4(-0.12966663, -0.008978932, 0.99151695, 0.0), w_axis: Vec4(-7.617824, -8.878197, 2.741486, 1.0) }
// finalBonesMatrices[1]  bone_transform = Mat4 { x_axis: Vec4(0.9933515, -0.11144002, 0.028877052, 0.0), y_axis: Vec4(0.10507641, 0.7752203, -0.62289083, 0.0), z_axis: Vec4(0.04702888, 0.62178385, 0.78177595, 0.0), w_axis: Vec4(-10.185644, 14.076111, 75.92954, 1.0) }
// finalBonesMatrices[2]  bone_transform = Mat4 { x_axis: Vec4(0.9810553, -0.097614, 0.16733932, 0.0), y_axis: Vec4(0.13710617, 0.960097, -0.24375519, 0.0), z_axis: Vec4(-0.13686801, 0.26208052, 0.95529157, 0.0), w_axis: Vec4(-11.18033, 4.4446526, 51.126827, 1.0) }

// zig
// mesh name = Player  nodeTransform = { { 1e0, 0e0, 0e0, 0e0 }, { 0e0, 1e0, 0e0, 0e0 }, { 0e0, 0e0, 1e0, 0e0 }, { 0e0, 0e0, 0e0, 0e0 } }
// mesh name = Gun  nodeTransform = { { 8.33236e-2, -9.724815e-2, 9.9176615e-1, 0e0 }, { 2.4570267e-1, 9.6650666e-1, 7.412852e-2, 0e0 }, { -9.657574e-1, 2.3750292e-1, 1.0442692e-1, 0e0 }, { -5.6490044e1, 5.6790943e1, -8.172132e1, 0e0 } }
// finalBonesMatrices[0] = { { 9.877224e-1, -8.903419e-2, 1.2836413e-1, 0e0 }, { 8.712634e-2, 9.959881e-1, 2.0413458e-2, 0e0 }, { -1.2966664e-1, -8.978933e-3, 9.91517e-1, 0e0 }, { -7.617825e0, -8.878197e0, 2.7414858e0, 0e0 } }
// finalBonesMatrices[1] = { { 9.9335176e-1, -1.1144005e-1, 2.887706e-2, 0e0 }, { 1.0507641e-1, 7.752203e-1, -6.2289083e-1, 0e0 }, { 4.7028877e-2, 6.2178385e-1, 7.8177595e-1, 0e0 }, { -1.0185646e1, 1.4076118e1, 7.592953e1, 0e0 } }
// finalBonesMatrices[2] = { { 9.8105556e-1, -9.761401e-2, 1.6733935e-1, 0e0 }, { 1.3710615e-1, 9.60097e-1, -2.4375519e-1, 0e0 }, { -1.3686801e-1, 2.6208052e-1, 9.5529157e-1, 0e0 }, { -1.1180334e1, 4.44466e0, 5.112683e1, 0e0 } }


// rust shader_mat4
// finalBonesMatrices[0] = [0.98772234, -0.089034185, 0.12836412, 0.0, 0.08712633, 0.995988, 0.020413456, 0.0, -0.12966663, -0.008978932, 0.99151695, 0.0, -7.617824, -8.878197, 2.741486, 1.0]
// finalBonesMatrices[1] = [0.9933515, -0.11144002, 0.028877052, 0.0, 0.10507641, 0.7752203, -0.62289083, 0.0, 0.04702888, 0.62178385, 0.78177595, 0.0, -10.185644, 14.076111, 75.92954, 1.0]
// finalBonesMatrices[2] = [0.9810553, -0.097614, 0.16733932, 0.0, 0.13710617, 0.960097, -0.24375519, 0.0, -0.13686801, 0.26208052, 0.95529157, 0.0, -11.18033, 4.4446526, 51.126827, 1.0]

// zig shader_mat4
// finalBonesMatrices[0] = { 9.877224e-1, -8.903419e-2, 1.2836413e-1, 0e0, 8.712634e-2, 9.959881e-1, 2.0413458e-2, 0e0, -1.2966664e-1, -8.978933e-3, 9.91517e-1, 0e0, -7.617825e0, -8.878197e0, 2.7414858e0, 0e0 }
// finalBonesMatrices[1] = { 9.9335176e-1, -1.1144005e-1, 2.887706e-2, 0e0, 1.0507641e-1, 7.752203e-1, -6.2289083e-1, 0e0, 4.7028877e-2, 6.2178385e-1, 7.8177595e-1, 0e0, -1.0185646e1, 1.4076118e1, 7.592953e1, 0e0 }
// finalBonesMatrices[2] = { 9.8105556e-1, -9.761401e-2, 1.6733935e-1, 0e0, 1.3710615e-1, 9.60097e-1, -2.4375519e-1, 0e0, -1.3686801e-1, 2.6208052e-1, 9.5529157e-1, 0e0, -1.1180334e1, 4.44466e0, 5.112683e1, 0e0 }

// rust
// finalBonesMatrices[33] = [-0.9793253, 0.18336889, -0.08543661, 0.0, -0.14571625, -0.34646887, 0.92667526, 0.0, 0.1403222, 0.9199653, 0.36602515, 0.0, -81.049484, 175.96823, -105.40663, 1.0]
// finalBonesMatrices[34] = [-0.54897875, 0.41569942, -0.7251332, 0.0, -0.8242342, -0.12518711, 0.55223894, 0.0, 0.13878807, 0.9008462, 0.41135806, 0.0, 34.673897, 168.67685, -111.823746, 1.0]
// finalBonesMatrices[35] = [-0.97694695, 0.20301926, -0.06602385, 0.0, -0.1455159, -0.40696865, 0.90177786, 0.0, 0.15620853, 0.89059603, 0.4271289, 0.0, -83.04655, 184.29364, -98.06193, 1.0]

// zig
// finalBonesMatrices[33] = { -9.793259e-1, 1.8336879e-1, -8.54366e-2, 0e0, -1.4571625e-1, -3.4646958e-1, 9.266754e-1, 0e0, 1.4032201e-1, 9.199654e-1, 3.6602533e-1, 0e0, -8.104951e1, 1.7596832e2, -1.0540665e2, 0e0 }
// finalBonesMatrices[34] = { -5.48979e-1, 4.1569963e-1, -7.251333e-1, 0e0, -8.2423437e-1, -1.2518749e-1, 5.5223894e-1, 0e0, 1.3878796e-1, 9.008461e-1, 4.113583e-1, 0e0, 3.4673897e1, 1.6867693e2, -1.1182375e2, 0e0 }
// finalBonesMatrices[35] = { -9.7694767e-1, 2.0301925e-1, -6.602383e-2, 0e0, -1.4551589e-1, -4.0696925e-1, 9.01778e-1, 0e0, 1.5620844e-1, 8.9059603e-1, 4.27129e-1, 0e0, -8.30466e1, 1.8429373e2, -9.806194e1, 0e0 }

// rust
// 416 - nodeTransform = [1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 1.0]
// 416 - nodeTransform = [0.0833236, -0.09724815, 0.99176615, 0.0, 0.24570267, 0.96650666, 0.07412852, 0.0, -0.9657574, 0.23750292, 0.10442692, 0.0, -56.49005, 56.790943, -81.72132, 1.0]

// zig
// 16 - nodeTransform = { 1e0, 0e0, 0e0, 0e0, 0e0, 1e0, 0e0, 0e0, 0e0, 0e0, 1e0, 0e0, 0e0, 0e0, 0e0, 0e0 }
// 416 - nodeTransform = { 8.33236e-2, -9.724815e-2, 9.9176615e-1, 0e0, 2.4570267e-1, 9.6650666e-1, 7.412852e-2, 0e0, -9.657574e-1, 2.3750292e-1, 1.0442692e-1, 0e0, -5.6490044e1, 5.6790943e1, -8.172132e1, 0e0 }

// rust
// node_name: Gun -
//     node_transform = NodeTransform { transform: Transform { translation: Vec3(-56.49005, 56.790943, -81.72132), rotation: Quat(-0.05565513, -0.6668501, -0.11682964, 0.73386943), scale: Vec3(1.0, 1.0, 1.0) }, meshes: [1] }
//     final_node_matrices[1] = Mat4 { x_axis: Vec4(0.0833236, -0.09724815, 0.99176615, 0.0), y_axis: Vec4(0.24570267, 0.96650666, 0.07412852, 0.0), z_axis: Vec4(-0.9657574, 0.23750292, 0.10442692, 0.0), w_axis: Vec4(-56.49005, 56.790943, -81.72132, 1.0) }

// zig
// node_name: Gun -
//     node_transform = core.animator.NodeTransform{ .transform = core.transform.Transform{ .translation = { -5.6490044e1, 5.6790943e1, -8.172132e1, 0e0 }, .rotation = { -5.565513e-2, -6.668501e-1, -1.1682964e-1, 7.3386943e-1 }, .scale = { 1e0, 1e0, 1e0, 0e0 } }, .meshes = array_list.ArrayListAligned(u32,null){ .items = { 1 }, .capacity = 8, .allocator = mem.Allocator{ .ptr = anyopaque@16dcf6ca0, .vtable = mem.Allocator.VTable{ ... } } } }
//     final_node_matrices[1] = { { 8.33236e-2, -9.724815e-2, 9.9176615e-1, 0e0 }, { 2.4570267e-1, 9.6650666e-1, 7.412852e-2, 0e0 }, { -9.657574e-1, 2.3750292e-1, 1.0442692e-1, 0e0 }, { -5.6490044e1, 5.6790943e1, -8.172132e1, 0e0 } }

}

