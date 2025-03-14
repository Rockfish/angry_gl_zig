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
const Camera = core.Camera;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

pub const Input = struct {
    first_mouse: bool = false,
    mouse_x: f32 = 0.0,
    mouse_y: f32 = 0.0,
    mouse_right_button: bool = false,
    mouse_left_button: bool = false,
    key_presses: EnumSet(glfw.Key),
    key_shift: bool = false,
};

pub const State = struct {
    viewport_width: f32,
    viewport_height: f32,
    scaled_width: f32,
    scaled_height: f32,
    window_scale: [2]f32,
    input: Input,
    camera: *Camera,
    projection: Mat4 = undefined,
    projection_type: core.ProjectionType,
    view: Mat4 = undefined,
    view_type: core.ViewType,
    light_postion: Vec3,
    delta_time: f32,
    total_time: f32,
    spin: bool = false,
    world_point: ?Vec3,
    current_position: Vec3,
    target_position: Vec3,
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
        .press => state.input.key_presses.insert(key),
        .release => state.input.key_presses.remove(key),
        else => {},
    }

    state.input.key_shift = mods.shift;

    if (key == .escape) {
        window.setShouldClose(true);
    }
}

pub fn processKeys() void {
    const toggle = struct {
        var spin_is_set: bool = false;
    };

    var iterator = state.input.key_presses.iterator();
    while (iterator.next()) |k| {
        switch (k) {
            .t => std.debug.print("time: {d}\n", .{state.delta_time}),
            .w => {
                if (state.input.key_shift) {
                    state.camera.processMovement(.Forward, state.delta_time);
                } else {
                    state.camera.processMovement(.RadiusIn, state.delta_time);
                }
            },
            .s => {
                if (state.input.key_shift) {
                    state.camera.processMovement(.Backward, state.delta_time);
                } else {
                    state.camera.processMovement(.RadiusOut, state.delta_time);
                }
            },
            .a => {
                if (state.input.key_shift) {
                    state.camera.processMovement(.Left, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitLeft, state.delta_time);
                }
            },
            .d => {
                if (state.input.key_shift) {
                    state.camera.processMovement(.Right, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitRight, state.delta_time);
                }
            },
            .up => {
                if (state.input.key_shift) {
                    state.camera.processMovement(.Up, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitUp, state.delta_time);
                }
            },
            .down => {
                if (state.input.key_shift) {
                    state.camera.processMovement(.Down, state.delta_time);
                } else {
                    state.camera.processMovement(.OrbitDown, state.delta_time);
                }
            },
            // .one => {
            //     state.view_type = .LookTo;
            // },
            // .two => {
            //     state.view_type = .LookAt;
            // },
            .three => {
                if (!toggle.spin_is_set) {
                    state.spin = !state.spin;
                }
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
    toggle.spin_is_set = state.input.key_presses.contains(.three);
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
            state.camera.setOrthoDimensions(state.scaled_width / 100.0, state.scaled_height / 100.0);
            state.projection = state.camera.getOrthoProjection();
        },
    }
}

fn mouseHandler(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = window;
    _ = mods;

    state.input.mouse_left_button = action == .press and button == glfw.MouseButton.left;
    state.input.mouse_right_button = action == .press and button == glfw.MouseButton.right;
}

fn cursorPositionHandler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = window;
    var xpos: f32 = @floatCast(xposIn);
    var ypos: f32 = @floatCast(yposIn);

    xpos = if (xpos < 0) 0 else if (xpos < state.scaled_width) xpos else state.scaled_width;
    ypos = if (ypos < 0) 0 else if (ypos < state.scaled_height) ypos else state.scaled_height;

    if (state.input.first_mouse) {
        state.input.mouse_x = xpos;
        state.input.mouse_y = ypos;
        state.input.first_mouse = false;
    }

    const xoffset = xpos - state.input.mouse_x;
    const yoffset = state.input.mouse_y - ypos; // reversed since y-coordinates go from bottom to top

    state.input.mouse_x = xpos;
    state.input.mouse_y = ypos;

    if (state.input.key_shift) {
        state.camera.processMouseMovement(xoffset, yoffset, true);
    }
}

fn scrollHandler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.processMouseScroll(@floatCast(yoffset));
}
