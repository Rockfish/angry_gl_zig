const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const nodes_ = @import("nodes_interfaces.zig");
const run_interfaces = @import("run_interfaces.zig").run;
const run_union = @import("run_union.zig").run;

const Cubeboid = core.shapes.Cubeboid;
const Cylinder = core.shapes.Cylinder;
const Sphere = core.shapes.Sphere;

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
const Node = nodes_.Node;
const Transform = core.Transform;

const cam = @import("camera.zig");
const Camera = cam.Camera;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

pub const State = struct {
    viewport_width: f32,
    viewport_height: f32,
    scaled_width: f32,
    scaled_height: f32,
    window_scale: [2]f32,
    camera: *Camera,
    projection: Mat4 = undefined,
    projection_type: cam.ProjectionType,
    view: Mat4 = undefined,
    view_type: cam.ViewType,
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

pub var state: State = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    core.string.init(allocator);

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

    _ = window.setKeyCallback(keyHandler);
    _ = window.setFramebufferSizeCallback(framebufferSizeHandler);
    _ = window.setCursorPosCallback(cursorPositionHandler);
    _ = window.setScrollCallback(scrollHandler);
    _ = window.setMouseButtonCallback(mouseHandler);
    // window.setInputMode(.cursor, glfw.Cursor.Mode.disabled);
 
    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    //try run_interfaces(allocator, window);
    try run_union(allocator, window);
}

fn getPVMMatrix(projection: *const Mat4, view: *const Mat4, model_transform: *const Mat4) Mat4 {
    return projection.mulMat4(&view.mulMat4(model_transform));
}

fn keyHandler(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;

    switch (action) {
        .press => state.key_presses.insert(key),
        .release => state.key_presses.remove(key),
        else => {},
    }

    state.key_shift = mods.shift;

    if (key == .escape) {
        window.setShouldClose(true);
    }
}

pub fn processKeys() void {
    const toggle = struct {
        var spin_is_set: bool = false;
    };

    var iterator = state.key_presses.iterator();
    while (iterator.next()) |k| {
        switch (k) {
            .t => std.debug.print("time: {d}\n", .{state.delta_time}),
            .w => {
                if (state.key_shift) {
                    state.camera.process_keyboard(.Forward, state.delta_time);
                } else {
                    state.camera.process_keyboard(.MoveIn, state.delta_time);
                }
            },
            .s => {
                if (state.key_shift) {
                    state.camera.process_keyboard(.Backward, state.delta_time);
                } else {
                    state.camera.process_keyboard(.MoveOut, state.delta_time);
                }
            },
            .a => {
                if (state.key_shift) {
                    state.camera.process_keyboard(.Left, state.delta_time);
                } else {
                    state.camera.process_keyboard(.OrbitLeft, state.delta_time);
                }
            },
            .d => {
                if (state.key_shift) {
                    state.camera.process_keyboard(.Right, state.delta_time);
                } else {
                    state.camera.process_keyboard(.OrbitRight, state.delta_time);
                }
            },
            .up => {
                if (state.key_shift) {
                    state.camera.process_keyboard(.Up, state.delta_time);
                } else {
                    state.camera.process_keyboard(.OrbitUp, state.delta_time);
                }
            },
            .down => {
                if (state.key_shift) {
                    state.camera.process_keyboard(.Down, state.delta_time);
                } else {
                    state.camera.process_keyboard(.OrbitDown, state.delta_time);
                }
            },
            .one => {
                state.view_type = .LookTo;
            },
            .two => {
                state.view_type = .LookAt;
            },
            .three => {
                if (!toggle.spin_is_set) {
                    state.spin = !state.spin;
                }
            },
            .four => {
                state.projection_type = .Perspective;
                state.projection = state.camera.get_perspective_projection();
            },
            .five => {
                state.projection_type = .Orthographic;
                state.projection = state.camera.get_ortho_projection();
            },
            else => {},
        }
    }
    toggle.spin_is_set = state.key_presses.contains(.three);
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
    state.camera.set_aspect(aspect_ratio);

    switch (state.projection_type) {
        .Perspective => {
            state.projection = state.camera.get_perspective_projection();
        },
        .Orthographic => {
            state.camera.set_ortho_dimensions(state.scaled_width / 100.0, state.scaled_height / 100.0);
            state.projection = state.camera.get_ortho_projection();
        },
    }
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
        state.camera.process_mouse_movement(xoffset, yoffset, true);
    }
}

fn scrollHandler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.process_mouse_scroll(@floatCast(yoffset));
}
