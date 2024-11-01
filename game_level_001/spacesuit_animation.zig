const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const core = @import("core");
const math = @import("math");

const Camera = @import("camera.zig").Camera;

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

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {

    std.debug.print("running spacesuit_animation\n", .{});

    const window_scale = window.getContentScale();

    const viewport_width = SCR_WIDTH * window_scale[0];
    const viewport_height = SCR_HEIGHT * window_scale[1];
    const scaled_width = viewport_width / window_scale[0];
    const scaled_height = viewport_height / window_scale[1];

    const camera = try Camera.init(
        allocator,
        vec3(0.0, 10.0, 30.0),
        vec3(0.0, 2.0, 0.0),
        scaled_width,
        scaled_height,
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
    };

    const state = &state_.state;
    state_.initWindowHandlers(window);

    const shader = try Shader.new(
        allocator,
        "game_level_001/shaders/player_shader.vert", 
        //"game_level_001/shaders/player_shader.frag",
        "game_level_001/shaders/basic_model.frag",
    );

    std.debug.print("Shader id: {d}\n", .{shader.id});

    const ambientColor: Vec3 = vec3(NON_BLUE * 0.7, NON_BLUE * 0.7, 0.7);
    var texture_cache = std.ArrayList(*Texture).init(allocator);

    const model_path = "/Users/john/Dev/Assets/modular_characters/Individual Characters/FBX/Spacesuit.fbx";
    std.debug.print("Main: loading model: {s}\n", .{model_path});

    var builder = try ModelBuilder.init(allocator, &texture_cache, "Spacesuit", model_path);
    var model = try builder.build();
    builder.deinit();

    const clip = AnimationClip.new(1.0, 2.0, AnimationRepeat.Forever);
    try model.playClip(clip);

    // --- event loop
    state.total_time = @floatCast(glfw.getTime());
    var frame_counter = FrameCount.new();

    gl.enable(gl.DEPTH_TEST);

    while (!window.shouldClose()) {
        const current_time: f32 = @floatCast(glfw.getTime());
        state.delta_time = current_time - state.total_time;
        state.total_time = current_time;

        state_.processKeys();

        frame_counter.update();

        glfw.pollEvents();
        gl.clearColor(0.05, 0.1, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        // const debug_camera = try Camera.camera_vec3(allocator, vec3(0.0, 40.0, 120.0));
        // defer debug_camera.deinit();

        //const projection = Mat4.perspectiveRhGl(toRadians(camera.zoom), SCR_WIDTH / SCR_HEIGHT, 0.1, 1000.0);
        const projection = state.projection;
        const view = state.camera.get_lookat_view();
        shader.set_mat4("matProjection", &projection);
        shader.set_mat4("matView", &view);
    
        var model_transform = Mat4.identity();
        // model_transform.translate(&vec3(0.0, -10.4, -400.0));
        //model_transform.scale(&vec3(1.0, 1.0, 1.0));
        //model_transform.translation(&vec3(0.0, 0.0, 0.0));
        model_transform.rotateByDegrees(&vec3(1.0, 0.0, 0.0), -90.0);
        model_transform.scale(&vec3(2.0, 2.0, 2.0));
        shader.set_mat4("matModel", &model_transform);

        shader.set_bool("useLight", true);
        shader.set_vec3("ambient", &ambientColor);
        shader.set_vec3("ambient_color", &vec3(1.0, 0.8, 0.8));
        shader.set_vec3("light_color", &vec3(0.1, 0.1, 0.1));
        shader.set_vec3("light_dir", &vec3(0.0, 0.0, 50.0));

        const identity = Mat4.identity();
        shader.set_mat4("aimRot", &identity);
        shader.set_mat4("lightSpaceMatrix", &identity);

        //try model.update_animation(state.delta_time);
        model.render(shader);

        // const bulletTransform = Mat4.fromScale(&vec3(2.0, 2.0, 2.0));
        // shader.set_mat4("model", &bulletTransform);
        // bullet_model.render(shader);

        window.swapBuffers();
    }

    std.debug.print("\nRun completed.\n\n", .{});

    shader.deinit();
    camera.deinit();
    model.deinit();
    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();
}

inline fn toRadians(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
}

// fn keyHandler(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
//     _ = scancode;
//     _ = mods;
//     switch (key) {
//         .escape => {
//             window.setShouldClose(true);
//         },
//         .t => {
//             if (action == glfw.Action.press) {
//                 std.debug.print("time: {d}\n", .{state.delta_time});
//             }
//         },
//         .w => {
//             state.camera.process_keyboard(.Forward, state.delta_time);
//         },
//         .s => {
//             state.camera.process_keyboard(.Backward, state.delta_time);
//         },
//         .a => {
//             state.camera.process_keyboard(.Left, state.delta_time);
//         },
//         .d => {
//             state.camera.process_keyboard(.Right, state.delta_time);
//         },
//         else => {},
//     }
// }
//
// fn framebufferSizeHandler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
//     _ = window;
//     gl.viewport(0, 0, width, height);
// }
//
// fn mouseHandler(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
//     _ = window;
//     _ = button;
//     _ = action;
//     _ = mods;
// }
//
// fn cursorPositionHandler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
//     _ = window;
//     var xpos: i32 = @intFromFloat(xposIn);
//     var ypos: i32 = @intFromFloat(yposIn);
//
//     xpos = if (xpos < 0) 0 else if (xpos < state.scr_width) xpos else state.scr_width;
//     ypos = if (ypos < 0) 0 else if (ypos < state.scr_height) ypos else state.scr_height;
//
//     if (state.first_mouse) {
//         state.last_x = xpos;
//         state.last_y = ypos;
//         state.first_mouse = false;
//     }
//
//     const xoffset = xpos - state.last_x;
//     const yoffset = state.last_y - ypos; // reversed since y-coordinates go from bottom to top
//
//     state.last_x = xpos;
//     state.last_y = ypos;
//
//     state.camera.process_mouse_movement(xoffset, yoffset, true);
// }
//
// fn scrollHandler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
//     _ = window;
//     _ = xoffset;
//     state.camera.process_mouse_scroll(@floatCast(yoffset));
// }
