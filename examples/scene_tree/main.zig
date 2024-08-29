const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const nodes_ = @import("nodes.zig");

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
    // scr_width: f32 = SCR_WIDTH,
    // scr_height: f32 = SCR_HEIGHT,
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

var state: State = undefined;
// var picker: PickingTexture = undefined;
// var picker: PickingTechnique = undefined;

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

pub const BasicNode = struct {
    const Self = @This();

    pub fn init() Self {
        return .{
        };
    }

    pub fn hello(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        std.debug.print("BasicNode. self: {any}\n", .{self});
    }
};


pub const ShapeNode = struct {
    ptr: *anyopaque,
    renderfn: *const fn(ptr: *anyopaque) void,
    name: []const u8,

    const Self = @This();

    pub fn init(ptr: anytype, name: []const u8) Self {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn render(pointer: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.render(self);
            }
        };

        return .{
            .ptr = ptr,
            .renderfn = gen.render,
            .name = name,
        };
    }

    pub fn update(ptr: *anyopaque, st: *State) anyerror!void {
        _ = ptr;
        _ = st;
    }

    pub fn render(ptr: *anyopaque, shader: *Shader) void {
        _ = shader; 
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.renderfn(self.ptr);
    }

    pub fn hello(self: *Self) void {
        std.debug.print("hello from self: {s}\n", .{self.name});
    }

    pub fn hellox(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        std.debug.print("hello from ShapeNode. self: {any}\n", .{self});
    }
};

pub const SceneModelNode = struct {
    ptr: *anyopaque,
    renderfn: *const fn(ptr: *anyopaque, shader: *Shader) void,

    const Self = @This();

    pub fn init(ptr: anytype) Self {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn render(pointer: *anyopaque, shader: *Shader) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.render(self, shader);
            }
        };

        return .{
            .ptr = ptr,
            .renderfn = gen.render,
        };
    }

    pub fn update(ptr: *anyopaque, st: *State) anyerror!void {
        _ = ptr;
        _ = st;
    }

    pub fn render(ptr: *anyopaque, shader: *Shader) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.renderfn(self.ptr, shader);
    }
};

// updatefn
pub fn updateSpin(node: *Node, st: *State) void {
    const up = vec3(0.0, 1.0, 0.0); 
    const velocity: f32 = 5.0 * st.delta_time;
    const angle = math.degreesToRadians(velocity);
    const turn_rotation = Quat.fromAxisAngle(&up, angle);
    node.transform.rotation = node.transform.rotation.mulQuat(&turn_rotation);
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
        vec3(0.0, 2.0, 14.0),
        vec3(0.0, 2.0, 0.0),
        scaled_width,
        scaled_height,
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
        .projection = camera.get_perspective_projection(),
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

    const basic_model_shader = try Shader.new(
        allocator,
        "examples/scene_tree/basic_model.vert",
        "examples/scene_tree/basic_model.frag",
    );
    defer basic_model_shader.deinit();

    var texture_cache = std.ArrayList(*Texture).init(allocator);

    var cubeboid = Cubeboid.init(.{ .width = 1.0, .height = 1.0, .depth = 2.0 });

    const plane = Cubeboid.init(.{
        .width = 20.0,
        .height = 2.0,
        .depth = 20.0,
        .num_tiles_x = 10.0,
        .num_tiles_y = 1.0,
        .num_tiles_z = 10.0,
    });

    var cylinder = try Cylinder.init(
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

    const cube_texture = try Texture.new(
        allocator,
        "assets/textures/container.jpg",
        texture_diffuse,
    );
    defer cube_texture.deinit();

    texture_diffuse.wrap = TextureWrap.Repeat;
    const surface_texture = try Texture.new(
        allocator,
        "angrybots_assets/Models/Floor D.png",
        //"assets/textures/IMGP5487_seamless.jpg",
        texture_diffuse,
    );
    defer surface_texture.deinit();

    const model_path = "/Users/john/Dev/Assets/spacekit_2/Models/OBJ format/alien.obj";
    var builder = try ModelBuilder.init(allocator, &texture_cache, "alien", model_path);
    var model = try builder.build();
    builder.deinit();
    defer model.deinit();


    var basic = BasicNode.init();
    var cubeShape = ShapeNode.init(&cubeboid, "cubeShape");
    var cylinderShape = ShapeNode.init(&cylinder, "cylinderShape");
    var scene_model = SceneModelNode.init(model);


    const node_test = nodes_.Node2.init2(&cubeShape);
    std.debug.print("node_test: {any}\n", .{node_test});
    // this works since we're passing an actual ShapeNode object pointer
    node_test.hellofn(&cubeShape);
    // This fails because there is no valid ShapeNode object pointer in node_test
    // node_test.hello();
 
    const root_node = try Node.init(allocator, "root_node", &basic, &state);

    const node_model = try Node.init(allocator, "node_model", &scene_model, &state);
    defer node_model.deinit();
 
    const node_cylinder = try Node.init(allocator, "shape_cylinder", &cylinderShape, &state);
    defer node_cylinder.deinit();

    root_node.addChild(node_model);
    root_node.addChild(node_cylinder);

    const cube_positions = [_]Vec3{
        vec3(3.0, 0.5, 0.0),
        vec3(1.5, 0.5, 0.0),
        vec3(0.0, 0.5, 0.0),
        vec3(-1.5, 0.5, 0.0),
        vec3(-3.0, 0.5, 0.0),
    };

    for (cube_positions) |position| {
        const cube = try Node.init(allocator, "shape_cubeboid", &cubeShape, &state);
        cube.transform.translation = position; // .add(&vec3(0.0, 1.0, 0.0));
        root_node.addChild(cube);
    }

    const node_cube_spin = try Node.init(allocator, "shape_cubeboid", &cubeShape, &state);
    defer node_cube_spin.deinit();
    node_cube_spin.transform.translation = vec3(0.0, 4.0, 0.0);

    node_cylinder.addChild(node_cube_spin);

    const node_cube = try Node.init(allocator, "shape_cubeboid", &cubeShape, &state);
    defer node_cube.deinit();

    node_cube.hello();
    node_model.hello();

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
            .LookAt => camera.get_lookat_view(),
            .LookTo => camera.get_lookto_view(),
        };

        gl.clearColor(0.1, 0.3, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const world_ray = math.get_world_ray_from_mouse(
            state.scaled_width,
            state.scaled_height,
            &state.projection,
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
        // const near_plane: f32 = 1.0;
        // const far_plane: f32 = 50.0;
        // const ortho_size: f32 = 10.0;
        //
        // const light_projection = Mat4.orthographicRhGl(-ortho_size, ortho_size, -ortho_size, ortho_size, near_plane, far_plane);
        // const light_view = Mat4.lookAtRhGl(&vec3(3.0, 3.0, -3.0), &vec3(0.0, 0.0, 0.0), &vec3(0.0, 1.0, 0.0));
        // const light_space_matrix = light_projection.mulMat4(&light_view);
        // basic_model_shader.set_mat4("light_space_matrix", &light_space_matrix);

        basic_model_shader.use_shader();
        basic_model_shader.set_mat4("projection", &state.projection);
        basic_model_shader.set_mat4("view", &state.view);

        basic_model_shader.set_vec3("ambient_color", &vec3(1.0, 0.6, 0.6));
        basic_model_shader.set_vec3("light_color", &vec3(0.35, 0.4, 0.5));
        basic_model_shader.set_vec3("light_dir", &vec3(3.0, 3.0, 3.0));

        basic_model_shader.bind_texture(0, "texture_diffuse", cube_texture);

        var model_transform = Mat4.identity();
        model_transform.translate(&vec3(1.0, 0.0, 5.0));
        model_transform.scale(&vec3(1.5, 1.5, 1.5));

        basic_model_shader.set_mat4("model", &model_transform);
        node_model.render(basic_model_shader);

        const Picked = struct {
            id: ?u32,
            distance: f32,
        };

        var picked = Picked{
            .id = null,
            .distance = 10000.0,
        };

        for (cube_transforms, 0..) |t, id| {
            basic_model_shader.set_mat4("model", &t);
            const aabb = cubeboid.aabb.transform(&t);
            const distance = aabb.ray_intersects(ray);
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

        for (cube_positions, 0..) |t, i| {
            if (picked.id != null and picked.id == @as(u32, @intCast(i))) {
                basic_model_shader.set_vec4("hit_color", &vec4(1.0, 0.0, 0.0, 0.0));
            }

            //basic_model_shader.set_mat4("model", &t);
            node_cube.transform.translation = t;
            node_cube.updateTransform(null);
            node_cube.render(basic_model_shader);

            basic_model_shader.set_vec4("hit_color", &vec4(0.0, 0.0, 0.0, 0.0));
        }

        if (state.mouse_left_button and state.world_point != null) {
            state.selected_position = state.world_point.?;
        }

        updateSpin(node_cylinder, &state);
        //basic_model_shader.set_mat4("modelRot", &node_cylinder.transform.get_matrix());

        // const cylinder_transform = Mat4.fromTranslation(&state.selected_position);
        // basic_model_shader.set_mat4("model", &cylinder_transform);

        // node_cylinder.transform.translation = state.selected_position;
        // var transform = Transform.init();
        // transform.translation = vec3(0.0, 2.0, 0.0);
        // node_cylinder.updateTransform(&transform);

        root_node.transform.translation = state.selected_position;
        root_node.updateTransform(null);
        root_node.render(basic_model_shader);

        const plane_transform = Mat4.fromTranslation(&vec3(0.0, -1.0, 0.0));
        basic_model_shader.set_mat4("model", &plane_transform);
        basic_model_shader.bind_texture(0, "texture_diffuse", surface_texture);
        plane.render();

        if (state.spin) {
            state.camera.process_keyboard(.OrbitRight, state.delta_time * 1.0);
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
                state.spin = !state.spin;
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
}

fn framebuffer_size_handler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
    set_view_port(width, height);
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

    // state.game_projection = Mat4.perspectiveRhGl(math.degreesToRadians(state.game_camera.zoom), aspect_ratio, 0.1, 100.0);
    // state.floating_projection = Mat4.perspectiveRhGl(math.degreesToRadians(state.floating_camera.zoom), aspect_ratio, 0.1, 100.0);
    // state.orthographic_projection = Mat4.orthographicRhGl(-ortho_width, ortho_width, -ortho_height, ortho_height, 0.1, 100.0);
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

fn scroll_handler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.camera.process_mouse_scroll(@floatCast(yoffset));
}
