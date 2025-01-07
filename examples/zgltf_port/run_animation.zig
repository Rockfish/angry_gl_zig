const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const core = @import("core");
const math = @import("math");

const Camera = @import("camera.zig").Camera;
const Builder = @import("builder.zig").GltfBuilder;

const gl = zopengl.bindings;

const Assimp = core.assimp.Assimp;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const animation = core.animation;
//const Camera = core.Camera;
const Shader = core.Shader;
const String = core.string.String;
const FrameCount = core.FrameCount;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const Animator = animation.Animator;
const AnimationClip = animation.AnimationClip;
const AnimationRepeat = animation.AnimationRepeatMode;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 800.0;
const SCR_HEIGHT: f32 = 800.0;

// Lighting
const LIGHT_FACTOR: f32 = 1.0;
const NON_BLUE: f32 = 0.9;

const FLOOR_LIGHT_FACTOR: f32 = 0.35;
const FLOOR_NON_BLUE: f32 = 0.7;

const content_dir = "assets";

const state_ = @import("state.zig");
const State = state_.State;

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window, model_path: []const u8) !void {

    std.debug.print("running test_animation\n", .{});

    const window_scale = window.getContentScale();

    const viewport_width = SCR_WIDTH * window_scale[0];
    const viewport_height = SCR_HEIGHT * window_scale[1];
    const scaled_width = viewport_width / window_scale[0];
    const scaled_height = viewport_height / window_scale[1];

    const camera = try Camera.init(
        allocator,
        .{
            .position = vec3(0.0, 10.0, 30.0),
            .target = vec3(0.0, 2.0, 0.0),
            .scr_width = scaled_width,
            .scr_height = scaled_height,
        },
    );

    state_.state = state_.State {
        .viewport_width = viewport_width,
        .viewport_height = viewport_height,
        .scaled_width = scaled_width,
        .scaled_height = scaled_height,
        .window_scale = window_scale,
        .camera = camera,
        .projection = camera.get_perspective_projection(),
        .projection_type = .Perspective,
        .view_type = .LookAt,
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .total_time = 0.0,
        .world_point = null,
        .current_position = vec3(0.0, 0.0, 0.0),
        .target_position = vec3(0.0, 0.0, 0.0),
        .input = .{
            .first_mouse = true,
            .mouse_x = scaled_width / 2.0,
            .mouse_y = scaled_height / 2.0,
            .key_presses = std.EnumSet(glfw.Key).initEmpty(),
        },
        .animation_id = 0,
    };

    const state = &state_.state;
    state_.initWindowHandlers(window);

    const shader = try Shader.new(
        allocator,
        "examples/zgltf_port/shaders/player_shader.vert", 
        //"game_level_001/shaders/player_shader.frag",
        "examples/zgltf_port/shaders/basic_model.frag",
    );

    std.debug.print("Shader id: {d}\n", .{shader.id});

    const ambientColor: Vec3 = vec3(NON_BLUE * 0.7, NON_BLUE * 0.7, 0.7);
    var texture_cache = std.ArrayList(*Texture).init(allocator);

    var model = blk: {
        std.debug.print("Main: loading model: {s}\n", .{model_path});
        var builder = try ModelBuilder.init(allocator, &texture_cache, "Spacesuit", model_path);
        const model = try builder.build();
        builder.deinit();
        break :blk model;
    };

    // std.debug.print("\n--- Assimp model ----------------------\n\n", .{});
    //
    // const mesh = model.meshes.items[0];
    // for (mesh.vertices.items, 0..) |vertex, i| {
    //     std.debug.print("  {d} : {any}\n", .{i, vertex.position});
    // }

    std.debug.print("\n--- Build gltf model ----------------------\n\n", .{});
    const gltfmodel = blk: {
        std.debug.print("Main: loading model: {s}\n", .{model_path});
        var builder = try Builder.init(allocator, &texture_cache, "Spacesuit", model_path);
        const gltfmodel = try builder.build();
        builder.deinit();
        break :blk gltfmodel;
    };

    defer gltfmodel.deinit();

    std.debug.print("\n----------------------\n", .{});


    // const clip = AnimationClip {
    //     .id = 16,
    //     .start_tick = 0.0,
    //     .end_tick = 60.0,
    //     .repeat_mode = .Forever
    // };
    // CesiumMan
    // const clip = AnimationClip {
    //     .id = 0,
    //     .start_tick = 1.0,
    //     .end_tick = 2000.0,
    //     .repeat_mode = .Forever
    // };
    // // const clip = AnimationClip.new(1.0, 2.0, AnimationRepeat.Forever);
    // try model.playClip(clip);

    // try model.animator.playAnimationById(0);

    // try core.dumpModelNodes(model);

    // --- event loop
    state.total_time = @floatCast(glfw.getTime());
    var frame_counter = FrameCount.new();

    gl.enable(gl.DEPTH_TEST);

    // state.single_mesh_id = 2;
    var last_animation: i32 = 0;

    shader.set_bool("has_color", false);
    shader.set_vec3("diffuse_color", &vec3(0.0, 0.0, 0.0));
    shader.set_vec3("ambient_color", &vec3(0.0, 0.0, 0.0));
    shader.set_vec3("specular_color", &vec3(0.0, 0.0, 0.0));
    shader.set_vec3("emissive_color", &vec3(0.0, 0.0, 0.0));
    shader.set_vec3("hit_color", &vec3(0.0, 0.0, 0.0));

    while (!window.shouldClose()) {
        const current_time: f32 = @floatCast(glfw.getTime());
        state.delta_time = current_time - state.total_time;
        state.total_time = current_time;

        state_.processKeys();

        frame_counter.update();

        glfw.pollEvents();
        gl.clearColor(0.05, 0.5, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // const debug_camera = try Camera.camera_vec3(allocator, vec3(0.0, 40.0, 120.0));
        // defer debug_camera.deinit();

        shader.set_mat4("matProjection", &state.projection);
        shader.set_mat4("matView", &state.camera.get_lookat_view());
  
        var model_transform = Mat4.identity();
        // model_transform.translate(&vec3(0.0, -10.4, -400.0));
        //model_transform.scale(&vec3(1.0, 1.0, 1.0));
        //model_transform.translation(&vec3(0.0, 0.0, 0.0));
        model_transform.rotateByDegrees(&vec3(1.0, 0.0, 0.0), -90.0);
        model_transform.scale(&vec3(3.0, 3.0, 3.0));
        // model_transform.scale(&vec3(0.02, 0.02, 0.02));
        shader.set_mat4("matModel", &model_transform);

        shader.set_bool("useLight", true);
        shader.set_vec3("ambient", &ambientColor);
        shader.set_vec3("ambient_light", &vec3(1.0, 0.8, 0.8));
        shader.set_vec3("light_color", &vec3(0.1, 0.1, 0.1));
        shader.set_vec3("light_dir", &vec3(10.0, 10.0, 2.0));

        const identity = Mat4.identity();
        shader.set_mat4("aimRot", &identity);
        shader.set_mat4("lightSpaceMatrix", &identity);

        try model.update_animation(state.delta_time);
        //try model.playTick(1.0);
        //model.single_mesh_select = state.single_mesh_id;
        if (last_animation != state.animation_id) {
            try model.animator.playAnimationById(@intCast(state.animation_id));
            last_animation = state.animation_id;
        }

       // model.render(shader);
       gltfmodel.render(shader);

        //try core.dumpModelNodes(model);
        window.swapBuffers();

        //break;
    }

    // try core.dumpModelNodes(model);
    // model.meshes.items[2].printMeshVertices(); 

    std.debug.print("\nRun completed.\n\n", .{});

    shader.deinit();
    camera.deinit();
    model.deinit();
    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();
}


