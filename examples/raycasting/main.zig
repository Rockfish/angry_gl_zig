const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const cam_test = @import("cam_test.zig");

const Cubeboid = core.shapes.Cubeboid;
const Cylinder = core.shapes.Cylinder;

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;
const Ray = core.Ray;

const Allocator = std.mem.Allocator;
const EnumSet = std.EnumSet;

const ModelBuilder = core.ModelBuilder;
const Shader = core.Shader;
const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const TextureConfig = core.texture.TextureConfig;
const TextureFilter = core.texture.TextureFilter;
const TextureWrap = core.texture.TextureWrap;

const cam = @import("camera.zig");
const Camera = cam.Camera;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

const State = struct {
    viewport_width: f32,
    viewport_height: f32,
    scaled_width: f32,
    scaled_height: f32,
    window_scale: [2]f32,
    camera: *Camera,
    view: Mat4 = undefined,
    view_type: cam.ViewType,
    light_postion: Vec3,
    delta_time: f32,
    last_frame: f32,
    first_mouse: bool,
    mouse_x: f32,
    mouse_y: f32,
    scr_width: f32 = SCR_WIDTH,
    scr_height: f32 = SCR_HEIGHT,
    key_presses: EnumSet(glfw.Key),
    key_shift: bool = false,
    mouse_right_button: bool = false,
    mouse_left_button: bool = false,
    spin: bool = false,
    world_point: ?Vec3,
    selected_position: Vec3,
};

var state: State = undefined;
// var picker: PickingTexture = undefined;
// var picker: PickingTechnique = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    core.string.init(allocator);

    if (true) {
        cam_test.test_rotation();
        //return;
    }

    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);
    glfw.windowHintTyped(.opengl_forward_compat, true);

    const window = try glfw.Window.create(
        SCR_WIDTH,
        SCR_HEIGHT,
        "Skybox",
        null,
    );
    defer window.destroy();

    _ = window.setKeyCallback(key_handler);
    _ = window.setFramebufferSizeCallback(framebuffer_size_handler);
    _ = window.setCursorPosCallback(cursor_position_handler);
    _ = window.setScrollCallback(scroll_handler);
    _ = window.setMouseButtonCallback(mouse_hander);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    // window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    try run(allocator, window);
}

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    gl.enable(gl.DEPTH_TEST);

    const window_scale = window.getContentScale();

    var viewport_width = SCR_WIDTH * window_scale[0];
    var viewport_height = SCR_HEIGHT * window_scale[1];
    var scaled_width = viewport_width / window_scale[0];
    var scaled_height = viewport_height / window_scale[1];

    // const postion = vec3(0.0, 5.0, -22.0);
    // const target = vec3(0.0, -0.2, 1.0);
    // const up = vec3(0.0, 1.0, 0.0);

    // const camera = try Camera.camera_vec3(allocator, postion);
    const aspect = SCR_WIDTH / SCR_HEIGHT;
    const camera = try Camera.init(
        allocator,
        vec3(0.0, 2.0, 12.0),
        vec3(0.0, 2.0, 0.0),
        aspect,
    );
    defer camera.deinit();

    const projection = camera.get_perspective_projection();

    const key_presses = EnumSet(glfw.Key).initEmpty();

    state = State{
        .viewport_width = viewport_width,
        .viewport_height = viewport_height,
        .scaled_width = scaled_width,
        .scaled_height = scaled_height,
        .window_scale = window_scale,
        .camera = camera,
        .view_type = .LookAt,
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .last_frame = 0.0,
        .first_mouse = true,
        .mouse_x = scaled_width / 2.0,
        .mouse_y = scaled_height / 2.0,
        .key_presses = key_presses,
        .world_point = null,
        .selected_position = vec3(0.0, 0.0, 0.0),
    };

    const basic_model_shader = try Shader.new(
        allocator,
        "examples/raycasting/basic_model.vert",
        "examples/raycasting/basic_model.frag",
    );
    defer basic_model_shader.deinit();

    var texture_cache = std.ArrayList(*Texture).init(allocator);

    // const model_path = "/Users/john/Dev/Repos/ogldev/Content/jeep.obj";
    // var builder = try ModelBuilder.init(allocator, &texture_cache, "bunny", model_path);
    // try builder.addTexture("Group", texture_diffuse, "jeep_rood.jpg");
    // var model = try builder.build();
    // builder.deinit();
    // defer model.deinit();

    const cubeboid = Cubeboid.init(1.0, 1.0, 2.0);
    const plane = Cubeboid.init(20.0, 0.2, 20.0);
    const cylinder = try Cylinder.init(allocator, 0.5, 4.0, 10);

    const texture_diffuse = .{
        .texture_type = .Diffuse,
        .filter = .Linear,
        .flip_v = false,
        .gamma_correction = false,
        .wrap = .Clamp,
    };

    const cube_texture = try Texture.new(
        allocator,
        "assets/textures/container.jpg",
        texture_diffuse,
    );
    defer cube_texture.deinit();

    const surface_texture = try Texture.new(
        allocator,
        "assets/textures/IMGP5487_seamless.jpg",
        texture_diffuse,
    );
    defer surface_texture.deinit();

    basic_model_shader.use_shader();
    basic_model_shader.set_mat4("projection", &projection);

    const cube_transforms = [_]Mat4{
        Mat4.fromTranslation(&vec3(3.0, 0.6, 0.0)),
        Mat4.fromTranslation(&vec3(1.5, 0.6, 0.0)),
        Mat4.fromTranslation(&vec3(0.0, 0.6, 0.0)),
        Mat4.fromTranslation(&vec3(-1.5, 0.6, 0.0)),
        Mat4.fromTranslation(&vec3(-3.0, 0.6, 0.0)),
    };

    const xz_plane_point = vec3(0.0, 0.0, 0.0);
    const xz_plane_normal = vec3(0.0, 1.0, 0.0);

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const currentFrame: f32 = @floatCast(glfw.getTime());
        state.delta_time = currentFrame - state.last_frame;
        state.last_frame = currentFrame;

        if (viewport_width != state.viewport_width or viewport_height != state.viewport_height) {
            viewport_width = state.viewport_width;
            viewport_height = state.viewport_height;
            scaled_width = state.scaled_width;
            scaled_height = state.scaled_height;
        }

        state.view = switch (state.view_type) {
            .LookAt => camera.get_lookat_view(),
            .LookTo => camera.get_lookto_view(),
        };

        gl.clearColor(0.1, 0.3, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const world_ray = math.get_world_ray_from_mouse(
            state.scaled_width,
            state.scaled_height,
            &projection,
            &state.view,
            state.mouse_x,
            state.mouse_y,
        );

        state.world_point = math.ray_plane_intersection(
            &state.camera.position,
            &world_ray, // direction
            &xz_plane_point,
            &xz_plane_normal,
        );

        const ray = Ray{
            .origin = state.camera.position,
            .direction = world_ray,
        };

        // if (state.world_point) |point| {
        //     std.debug.print("world_point: {d}, {d}, {d}\n", .{ point.x, point.y, point.z });
        // }

        basic_model_shader.use_shader();
        basic_model_shader.set_mat4("view", &state.view);
        basic_model_shader.bind_texture(0, "texture_diffuse", cube_texture);

        // var model_transform = Mat4.identity();
        // model_transform.translate(&vec3(0.0, -1.4, -50.0));
        // model_transform.scale(&vec3(0.05, 0.05, 0.05));

        // var cube_transform2 = Mat4.identity();
        // cube_transform2.translate(&vec3(2.0, 1.0, 0.0));
        //
        // var cubeboid_transform = Mat4.identity();
        // cubeboid_transform.translate(&vec3(-2.0, 1.0, 0.0));

        for (cube_transforms, 0..) |t, i| {
            basic_model_shader.set_mat4("model", &t);
            const aabb = cubeboid.aabb.transform(&t);
            const hit = aabb.intersects_ray(ray);
            if (hit) {
                std.debug.print("hit cube: {d}\n", .{i});
            }
            cubeboid.render();
        }

        if (state.mouse_left_button and state.world_point != null) {
            state.selected_position = state.world_point.?;
        }

        const cylinder_transform = Mat4.fromTranslation(&state.selected_position);

        basic_model_shader.set_mat4("model", &cylinder_transform);
        cylinder.render();

        const plane_transform = Mat4.fromTranslation(&vec3(0.0, 0.0, 0.0));
        basic_model_shader.set_mat4("model", &plane_transform);
        basic_model_shader.bind_texture(0, "texture_diffuse", surface_texture);
        plane.render();

        if (state.spin) {
            state.camera.process_keyboard(.Right, .Polar, state.delta_time * 2.0);
        }

        window.swapBuffers();
        glfw.pollEvents();
    }

    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();

    glfw.terminate();
}

fn get_pvm_matrix(projection: *const Mat4, view: *const Mat4, model_transform: *const Mat4) Mat4 {
    return projection.mulMat4(&view.mulMat4(model_transform));
}

fn key_handler(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;

    switch (action) {
        .press => state.key_presses.insert(key),
        .release => state.key_presses.remove(key),
        else => {},
    }

    state.key_shift = mods.shift;

    const mode = if (mods.alt) cam.MovementMode.Polar else cam.MovementMode.Planar;

    var iterator = state.key_presses.iterator();
    while (iterator.next()) |k| {
        switch (k) {
            .escape => window.setShouldClose(true),
            .t => std.debug.print("time: {d}\n", .{state.delta_time}),
            .w => state.camera.process_keyboard(.Forward, mode, state.delta_time),
            .s => state.camera.process_keyboard(.Backward, mode, state.delta_time),
            .a => state.camera.process_keyboard(.Left, mode, state.delta_time),
            .d => state.camera.process_keyboard(.Right, mode, state.delta_time),
            .up => state.camera.process_keyboard(.Up, mode, state.delta_time),
            .down => state.camera.process_keyboard(.Down, mode, state.delta_time),
            .one => {
                state.view_type = .LookTo;
            },
            .two => {
                state.view_type = .LookAt;
            },
            .three => {
                state.spin = !state.spin;
            },
            else => {},
        }
    }
}

fn framebuffer_size_handler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
    set_view_port(width, height);
}

fn mouse_hander(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = window;
    _ = mods;

    state.mouse_left_button = action == .press and button == glfw.MouseButton.left;
    state.mouse_right_button = action == .press and button == glfw.MouseButton.right;
}

fn cursor_position_handler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = window;
    var xpos: f32 = @floatCast(xposIn);
    var ypos: f32 = @floatCast(yposIn);

    xpos = if (xpos < 0) 0 else if (xpos < state.scr_width) xpos else state.scr_width;
    ypos = if (ypos < 0) 0 else if (ypos < state.scr_height) ypos else state.scr_height;

    if (state.first_mouse) {
        state.mouse_x = xpos;
        state.mouse_y = ypos;
        state.first_mouse = false;
    }

    const xoffset = xpos - state.mouse_x;
    const yoffset = state.mouse_y - ypos; // reversed since y-coordinates go from bottom to top

    state.mouse_x = xpos;
    state.mouse_y = ypos;

    if (state.key_shift) {
        state.camera.process_mouse_movement(xoffset, yoffset, true);
    }
}

fn scroll_handler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.process_mouse_scroll(@floatCast(yoffset));
}

fn set_view_port(w: i32, h: i32) void {
    const width: f32 = @floatFromInt(w);
    const height: f32 = @floatFromInt(h);

    state.viewport_width = width;
    state.viewport_height = height;
    state.scaled_width = width / state.window_scale[0];
    state.scaled_height = height / state.window_scale[1];

    // const ortho_width = (state.viewport_width / 500);
    // const ortho_height = (state.viewport_height / 500);
    // const aspect_ratio = (state.viewport_width / state.viewport_height);
    //
    // state.game_projection = Mat4.perspectiveRhGl(math.degreesToRadians(state.game_camera.zoom), aspect_ratio, 0.1, 100.0);
    // state.floating_projection = Mat4.perspectiveRhGl(math.degreesToRadians(state.floating_camera.zoom), aspect_ratio, 0.1, 100.0);
    // state.orthographic_projection = Mat4.orthographicRhGl(-ortho_width, ortho_width, -ortho_height, ortho_height, 0.1, 100.0);
}
