const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const tests = @import("tests.zig");

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
const Camera = core.Camera;

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
    // scr_width: f32 = SCR_WIDTH,
    // scr_height: f32 = SCR_HEIGHT,
    window_scale: [2]f32,
    camera: *Camera,
    projection: Mat4 = undefined,
    projection_type: core.ProjectionType,
    view: Mat4 = undefined,
    view_type: core.ViewType,
    light_postion: Vec3,
    delta_time: f32,
    total_time: f32,
    first_mouse: bool,
    mouse_x: f32,
    mouse_y: f32,
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

    if (false) {
        std.debug.print("---\n", .{});
        //tests.test_rotation();
        try tests.test_aabb_transform();
        return;
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
    _ = window.setFramebufferSizeCallback(framebufferSizeHandler);
    _ = window.setCursorPosCallback(cursorPositionHandler);
    _ = window.setScrollCallback(scrollHandler);
    _ = window.setMouseButtonCallback(mouseHandler);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    // window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    try run(allocator, window);
}

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    gl.enable(gl.DEPTH_TEST);

    const window_scale = window.getContentScale();

    const viewport_width = SCR_WIDTH * window_scale[0];
    const viewport_height = SCR_HEIGHT * window_scale[1];
    const scaled_width = viewport_width / window_scale[0];
    const scaled_height = viewport_height / window_scale[1];

    const camera = try Camera.init(
        allocator,
        . {
            .position = vec3(0.0, 2.0, 14.0),
            .target = vec3(0.0, 2.0, 0.0),
            .scr_width = scaled_width,
            .scr_height = scaled_height,
        },
    );
    defer camera.deinit();

    const key_presses = EnumSet(glfw.Key).initEmpty();

    state = State{
        .viewport_width = viewport_width,
        .viewport_height = viewport_height,
        .scaled_width = scaled_width,
        .scaled_height = scaled_height,
        .window_scale = window_scale,
        .camera = camera,
        .projection = camera.getPerspectiveProjection(),
        .projection_type = .Perspective,
        .view_type = .LookAt,
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .total_time = 0.0,
        .first_mouse = true,
        .mouse_x = scaled_width / 2.0,
        .mouse_y = scaled_height / 2.0,
        .key_presses = key_presses,
        .world_point = null,
        .selected_position = vec3(0.0, 0.0, 0.0),
    };

    const basic_model_shader = try Shader.init(
        allocator,
        "examples/ray_selection/basic_model.vert",
        "examples/ray_selection/basic_model.frag",
    );
    defer basic_model_shader.deinit();

    var texture_cache = std.ArrayList(*Texture).init(allocator);

    const cubeboid = try core.shapes.createCube(allocator, .{ .width = 1.0, .height = 1.0, .depth = 2.0 });
    const plane = try core.shapes.createCube(allocator, .{
        .width = 20.0,
        .height = 2.0,
        .depth = 20.0,
        .num_tiles_x = 10.0,
        .num_tiles_y = 1.0,
        .num_tiles_z = 10.0,
    });
    const cylinder = try core.shapes.createCylinder(
        allocator,
        1.0,
        4.0,
        20.0,
    );

    var texture_diffuse = TextureConfig{
        .texture_type = .Diffuse,
        .filter = .Linear,
        .flip_v = false,
        .gamma_correction = false,
        .wrap = TextureWrap.Repeat,
    };

    const cube_texture = try Texture.init(
        allocator,
        "assets/textures/container.jpg",
        texture_diffuse,
    );
    defer cube_texture.deinit();

    texture_diffuse.wrap = TextureWrap.Repeat;
    const surface_texture = try Texture.init(
        allocator,
        "angrybots_assets/Models/Floor D.png",
        //"assets/textures/IMGP5487_seamless.jpg",
        texture_diffuse,
    );
    defer surface_texture.deinit();

    const model_path = "/Users/john/Dev/Assets/spacekit_2/Models/OBJ format/alien.obj";
    var builder = try ModelBuilder.init(allocator, &texture_cache, "alien", model_path);
    //try builder.addTexture("Group", texture_diffuse, "jeep_rood.jpg");
    var model = try builder.build();
    builder.deinit();
    defer model.deinit();

    const cube_transforms = [_]Mat4{
        Mat4.fromTranslation(&vec3(3.0, 0.5, 0.0)),
        Mat4.fromTranslation(&vec3(1.5, 0.5, 0.0)),
        Mat4.fromTranslation(&vec3(0.0, 0.5, 0.0)),
        Mat4.fromTranslation(&vec3(-1.5, 0.5, 0.0)),
        Mat4.fromTranslation(&vec3(-3.0, 0.5, 0.0)),
    };

    const xz_plane_point = vec3(0.0, 0.0, 0.0);
    const xz_plane_normal = vec3(0.0, 1.0, 0.0);

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const current_time: f32 = @floatCast(glfw.getTime());
        state.delta_time = current_time - state.total_time;
        state.total_time = current_time;

        // if (viewport_width != state.viewport_width or viewport_height != state.viewport_height) {
        //     viewport_width = state.viewport_width;
        //     viewport_height = state.viewport_height;
        //     scaled_width = state.scaled_width;
        //     scaled_height = state.scaled_height;
        // }

        state.view = switch (state.view_type) {
            .LookAt => camera.getLookAtView(),
            .LookTo => camera.getLookToView(),
        };

        gl.clearColor(0.1, 0.3, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const world_ray = math.getWorldRayFromMouse(
            state.scaled_width,
            state.scaled_height,
            &state.projection,
            &state.view,
            state.mouse_x,
            state.mouse_y,
        );

        state.world_point = math.getRayPlaneIntersection(
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

        basic_model_shader.useShader();
        basic_model_shader.setMat4("projection", &state.projection);
        basic_model_shader.setMat4("view", &state.view);
        basic_model_shader.setVec3("ambient_color", &vec3(1.0, 0.6, 0.6));
        basic_model_shader.setVec3("light_color", &vec3(0.35, 0.4, 0.5));
        basic_model_shader.setVec3("light_dir", &vec3(3.0, 3.0, 3.0));

        basic_model_shader.bindTexture(0, "texture_diffuse", cube_texture);

        var model_transform = Mat4.identity();
        model_transform.translate(&vec3(1.0, 0.0, 5.0));
        model_transform.scale(&vec3(1.5, 1.5, 1.5));

        basic_model_shader.setMat4("model", &model_transform);
        model.render(basic_model_shader);

        // var cube_transform2 = Mat4.identity();
        // cube_transform2.translate(&vec3(2.0, 1.0, 0.0));
        //
        // var cubeboid_transform = Mat4.identity();
        // cubeboid_transform.translate(&vec3(-2.0, 1.0, 0.0));

        const Picked = struct {
            id: ?u32,
            distance: f32,
        };

        var picked = Picked{
            .id = null,
            .distance = 10000.0,
        };

        for (cube_transforms, 0..) |t, id| {
            basic_model_shader.setMat4("model", &t);
            const aabb = cubeboid.aabb.transform(&t);
            const distance = aabb.rayIntersects(ray);
            if (distance) |d| {
                if (picked.id != null) {
                    if (d < picked.distance) {
                        picked.id = @intCast(id);
                        picked.distance = d;
                    }
                } else {
                    picked.id = @intCast(id);
                    picked.distance = d;
                }
            }
        }

        for (cube_transforms, 0..) |t, i| {
            basic_model_shader.setMat4("model", &t);
            if (picked.id != null and picked.id == @as(u32, @intCast(i))) {
                basic_model_shader.setVec4("hit_color", &vec4(1.0, 0.0, 0.0, 0.0));
            }
            cubeboid.render();
            basic_model_shader.setVec4("hit_color", &vec4(0.0, 0.0, 0.0, 0.0));
        }

        if (state.mouse_left_button and state.world_point != null) {
            state.selected_position = state.world_point.?;
        }

        const cylinder_transform = Mat4.fromTranslation(&state.selected_position);

        basic_model_shader.setMat4("model", &cylinder_transform);
        cylinder.render();

        const plane_transform = Mat4.fromTranslation(&vec3(0.0, -1.0, 0.0));
        basic_model_shader.setMat4("model", &plane_transform);
        basic_model_shader.bindTexture(0, "texture_diffuse", surface_texture);
        plane.render();

        if (state.spin) {
            state.camera.processMovement(.OrbitRight, state.delta_time * 1.0);
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

    // const mode = if (mods.alt) cam.MovementMode.Polar else cam.MovementMode.Planar;

    var iterator = state.key_presses.iterator();
    while (iterator.next()) |k| {
        switch (k) {
            .escape => window.setShouldClose(true),
            .t => std.debug.print("time: {d}\n", .{state.delta_time}),
            .w => {
                if (state.key_shift) {
                    state.camera.processMovement(.Forward, state.delta_time);
                } else {
                    state.camera.processMovement(.RadiusIn, state.delta_time);
                }
            },
            .s => {
                if (state.key_shift) {
                    state.camera.processMovement(.Backward, state.delta_time);
                } else {
                    state.camera.processMovement(.RadiusOut, state.delta_time);
                }
            },
            .a => {
                if (state.key_shift) {
                    state.camera.processMovement(.Left, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitLeft, state.delta_time);
                }
            },
            .d => {
                if (state.key_shift) {
                    state.camera.processMovement(.Right, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitRight, state.delta_time);
                }
            },
            .up => {
                if (state.key_shift) {
                    state.camera.processMovement(.Up, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitUp, state.delta_time);
                }
            },
            .down => {
                if (state.key_shift) {
                    state.camera.processMovement(.Down, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitDown, state.delta_time);
                }
            },
            .one => {
                state.view_type = .LookTo;
            },
            .two => {
                state.view_type = .LookAt;
            },
            .three => {
                state.spin = !state.spin;
            },
            .four => {
                state.projection_type = .Perspective;
                state.projection = state.camera.getPerspectiveProjection();
            },
            .five => {
                state.projection_type = .Orthographic;
                state.projection = state.camera.getOrthoProjection();
            },
            else => {},
        }
    }
}

fn framebufferSizeHandler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
    setViewPort(width, height);
}

fn setViewPort(w: i32, h: i32) void {
    const width: f32 = @floatFromInt(w);
    const height: f32 = @floatFromInt(h);

    state.viewport_width = width;
    state.viewport_height = height;
    state.scaled_width = width / state.window_scale[0];
    state.scaled_height = height / state.window_scale[1];

    // const ortho_width = (state.viewport_width / 500);
    // const ortho_height = (state.viewport_height / 500);
    const aspect_ratio = (state.scaled_width / state.scaled_height);
    state.camera.setAspect(aspect_ratio);

    switch (state.projection_type) {
        .Perspective => {
            state.projection = state.camera.getPerspectiveProjection();
        },
        .Orthographic => {
            state.camera.setScreenDimensions(state.scaled_width, state.scaled_height);
            state.camera.setOrthoDimensions(state.scaled_width / 100.0, state.scaled_height / 100.0);
            state.projection = state.camera.getOrthoProjection();
        },
    }

    // state.game_projection = Mat4.perspectiveRhGl(math.degreesToRadians(state.game_camera.zoom), aspect_ratio, 0.1, 100.0);
    // state.floating_projection = Mat4.perspectiveRhGl(math.degreesToRadians(state.floating_camera.zoom), aspect_ratio, 0.1, 100.0);
    // state.orthographic_projection = Mat4.orthographicRhGl(-ortho_width, ortho_width, -ortho_height, ortho_height, 0.1, 100.0);
}

fn mouseHandler(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = window;
    _ = mods;

    state.mouse_left_button = action == .press and button == glfw.MouseButton.left;
    state.mouse_right_button = action == .press and button == glfw.MouseButton.right;
}

fn cursorPositionHandler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = window;
    var xpos: f32 = @floatCast(xposIn);
    var ypos: f32 = @floatCast(yposIn);

    xpos = if (xpos < 0) 0 else if (xpos < state.scaled_width) xpos else state.scaled_width;
    ypos = if (ypos < 0) 0 else if (ypos < state.scaled_height) ypos else state.scaled_height;

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
        state.camera.processMouseMovement(xoffset, yoffset, true);
    }
}

fn scrollHandler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.processMouseScroll(@floatCast(yoffset));
}
