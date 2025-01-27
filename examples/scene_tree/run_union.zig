const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const nodes_ = @import("nodes_union.zig");

const main = @import("main.zig");
const shapes = core.shapes;

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;
const Ray = core.Ray;

const Allocator = std.mem.Allocator;
const EnumSet = std.EnumSet;

const State = @import("main.zig").State;
const ModelBuilder = core.ModelBuilder;
const Shader = core.Shader;
const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const TextureConfig = core.texture.TextureConfig;
const TextureFilter = core.texture.TextureFilter;
const TextureWrap = core.texture.TextureWrap;
const Transform = core.Transform;
const Camera = core.Camera;

// const cam = @import("camera.zig");
// const Camera = cam.Camera;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    gl.enable(gl.DEPTH_TEST);

    const window_scale = window.getContentScale();

    const viewport_width = SCR_WIDTH * window_scale[0];
    const viewport_height = SCR_HEIGHT * window_scale[1];
    const scaled_width = viewport_width / window_scale[0];
    const scaled_height = viewport_height / window_scale[1];

    const camera = try Camera.init(
        allocator,
        .{
            .position = vec3(0.0, 2.0, 14.0),
            .target = vec3(0.0, 2.0, 0.0),
            .scr_width = scaled_width,
            .scr_height = scaled_height,
        },
    );
    defer camera.deinit();

    main.state = State{
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
        .world_point = null,
        .current_position = vec3(0.0, 0.0, 0.0),
        .target_position = vec3(0.0, 0.0, 0.0),
        .input = .{
            .first_mouse = true,
            .mouse_x = scaled_width / 2.0,
            .mouse_y = scaled_height / 2.0,
            .key_presses = EnumSet(glfw.Key).initEmpty(),
        },
    };

    const basic_model_shader = try Shader.init(
        allocator,
        "examples/scene_tree/basic_model.vert",
        "examples/scene_tree/basic_model.frag",
    );
    defer basic_model_shader.deinit();

    var texture_cache = std.ArrayList(*Texture).init(allocator);

    var cubeboid = try shapes.createCube(
        allocator,
        .{
            .width = 1.0,
            .height = 1.0,
            .depth = 2.0,
        },
    );
    defer cubeboid.deinit();

    var plane = try shapes.createCube(
        allocator,
        .{
            .width = 100.0,
            .height = 2.0,
            .depth = 100.0,
            .num_tiles_x = 50.0,
            .num_tiles_y = 1.0,
            .num_tiles_z = 50.0,
        },
    );
    defer plane.deinit();

    var cylinder = try shapes.createCylinder(
        allocator,
        1.0,
        4.0,
        20.0,
    );
    defer cylinder.deinit();

    var sphere = try shapes.createSphere(allocator, 1.0, 20, 20);
    defer sphere.deinit();

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
        //"assets/texturest/IMGP5487_seamless.jpg",
        texture_diffuse,
    );
    defer surface_texture.deinit();

    const model_paths = [_][]const u8{
        "/Users/john/Dev/Assets/spacekit_2/Models/OBJ format/alien.obj",
        "/Users/john/Dev/Assets/Low_P_Bot_0201.fbx",
        "assets/models/Capsule.obj",
        "/Users/john/Dev/Assets/glTF-Sample-Models/1.0/BarramundiFish/glTF/BarramundiFish.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/1.0/RiggedFigure/glTF/RiggedFigure.gltf",
        "/Users/john/Dev/Dev_Rust/small_gl_core/examples/sample_animation/source/cube_capoeira_martelo_cruzando.fbx",
        "/Users/john/Dev/Repos/irrlicht/media/faerie.md2", // use skipModelTextures
        "/Users/john/Downloads/Robot2.fbx",
        // these are not loading
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/RiggedFigure/glTF-Binary/RiggedFigure.glb",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/RiggedFigure/glTF/RiggedFigure.gltf",
        "/Users/john/Dev/Repos/Egregoria/assets/models/pedestrian.glb",
    };

    var builder = try ModelBuilder.init(allocator, &texture_cache, "alien", model_paths[7]);
    //builder.skipModelTextures();
    try builder.addTexture("Robot2", texture_diffuse, "/Users/john/Dev/Zig/Dev/angry_gl_zig/assets/textures/IMGP5487_seamless.jpg");
    var model = try builder.build();
    builder.deinit();
    defer model.deinit();

    var node_list = std.ArrayList(*nodes_.Node).init(allocator);
    defer {
        for (node_list.items) |node| {
            node.deinit();
        }
        node_list.deinit();
    }

    var basic_obj = nodes_.BasicObj.init("basic");
    var cube_obj = nodes_.ShapeObj.init(&cubeboid, "cubeShape", cube_texture);
    var cylinder_obj = nodes_.ShapeObj.init(&cylinder, "cylinderShape", cube_texture);
    var sphere_obj = nodes_.ShapeObj.init(&sphere, "SphereShape", cube_texture);
    var model_obj = nodes_.ModelObj.init(model, "Bot_Model");

    const root_node = try nodes_.Node.init(allocator, "root_node", .{ .basic = &basic_obj });
    try node_list.append(root_node);

    const node_model = try nodes_.Node.init(allocator, "node_model", .{ .model = &model_obj });
    try node_list.append(node_model);

    node_model.setTranslation(vec3(2.0, 0.0, 2.0));
    //node_model.transform.rotation = Quat.fromAxisAngle(&vec3(1.0, 0.0, 0.0), math.degreesToRadians(-90.0));
    node_model.transform.scale = vec3(1.5, 1.5, 1.5);

    const node_cylinder = try nodes_.Node.init(allocator, "shape_cylinder", .{ .shape = &cylinder_obj });
    try node_list.append(node_cylinder);

    const node_sphere = try nodes_.Node.init(allocator, "shpere_shape", .{ .shape = &sphere_obj });
    try node_list.append(node_sphere);
    node_sphere.setTranslation(vec3(-3.0, 1.0, 3.0));

    try root_node.addChild(node_model);
    try root_node.addChild(node_cylinder);

    const cube_positions = [_]Vec3{
        vec3(3.0, 0.5, 0.0),
        vec3(1.5, 0.5, 0.0),
        vec3(0.0, 0.5, 0.0),
        vec3(-1.5, 0.5, 0.0),
        vec3(-3.0, 0.5, 0.0),
    };

    for (cube_positions) |position| {
        const cube = try nodes_.Node.init(allocator, "shape_cubeboid", .{ .shape = &cube_obj });
        try node_list.append(cube);
        cube.setTranslation(position);
        try root_node.addChild(cube);

        const fix_cube = try nodes_.Node.init(allocator, "shape_cubeboid", .{ .shape = &cube_obj });
        try node_list.append(fix_cube);
        fix_cube.setTranslation(position);
    }

    const node_cube_spin = try nodes_.Node.init(allocator, "shape_cubeboid", .{ .shape = &cube_obj });
    try node_list.append(node_cube_spin);

    node_cube_spin.setTranslation(vec3(0.0, 6.0, 0.0));
    try node_cylinder.addChild(node_cube_spin);

    const xz_plane_point = vec3(0.0, 0.0, 0.0);
    const xz_plane_normal = vec3(0.0, 1.0, 0.0);

    var moving = false;

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const current_time: f32 = @floatCast(glfw.getTime());
        main.state.delta_time = current_time - main.state.total_time;
        main.state.total_time = current_time;

        main.state.view = switch (main.state.view_type) {
            .LookAt => camera.getLookAtView(),
            .LookTo => camera.getLookToView(),
        };

        main.processKeys();

        gl.clearColor(0.1, 0.3, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const world_ray = math.getWorldRayFromMouse(
            main.state.scaled_width,
            main.state.scaled_height,
            &main.state.projection,
            &main.state.view,
            main.state.input.mouse_x,
            main.state.input.mouse_y,
        );

        main.state.world_point = math.getRayPlaneIntersection(
            &main.state.camera.position,
            &world_ray, // direction
            &xz_plane_point,
            &xz_plane_normal,
        );

        const ray = Ray{
            .origin = main.state.camera.position,
            .direction = world_ray,
        };

        basic_model_shader.useShader();
        basic_model_shader.setMat4("matProjection", &main.state.projection);
        basic_model_shader.setMat4("matView", &main.state.view);

        basic_model_shader.setVec3("ambient_color", &vec3(1.0, 0.6, 0.6));
        basic_model_shader.setVec3("light_color", &vec3(0.35, 0.4, 0.5));
        basic_model_shader.setVec3("light_dir", &vec3(3.0, 3.0, 3.0));

        basic_model_shader.bindTexture(0, "texture_diffuse", cube_texture);

        if (main.state.input.mouse_left_button and main.state.world_point != null) {
            main.state.target_position = main.state.world_point.?;
            moving = true;
        }

        if (moving) {
            var direction = main.state.target_position.sub(&main.state.current_position);
            const distance = direction.length();

            if (distance < 0.1) {
                main.state.current_position = main.state.target_position;
                moving = false;
            } else {
                direction = direction.normalize();
                const moveDistance = main.state.delta_time * 20.0;

                if (moveDistance > distance) {
                    main.state.current_position = main.state.target_position;
                    moving = false;
                } else {
                    main.state.current_position = main.state.current_position.add(&direction.mulScalar(moveDistance));
                }
            }
        }

        root_node.setTranslation(main.state.current_position);

        updateSpin(node_cylinder, &main.state);
        root_node.updateTransforms(null);

        const Picked = struct {
            id: ?u32,
            distance: f32,
        };

        var picked = Picked{
            .id = null,
            .distance = 10000.0,
        };

        for (node_list.items, 0..) |n, id| {
            if (n.object.getBoundingBox()) |aabb| {
                const box = aabb.transform(&n.global_transform.getMatrix());
                const distance = box.rayIntersects(ray);
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
        }

        for (node_list.items, 0..) |n, id| {
            if (picked.id != null and picked.id == @as(u32, @intCast(id))) {
                basic_model_shader.setVec4("hit_color", &vec4(1.0, 0.0, 0.0, 0.0));
            }
            n.render(basic_model_shader);
            basic_model_shader.setVec4("hit_color", &vec4(0.0, 0.0, 0.0, 0.0));
        }

        const plane_transform = Mat4.fromTranslation(&vec3(0.0, -1.0, 0.0));
        basic_model_shader.setMat4("matModel", &plane_transform);
        basic_model_shader.bindTexture(0, "texture_diffuse", surface_texture);
        plane.render();

        if (main.state.spin) {
            main.state.camera.processMovement(.OrbitRight, main.state.delta_time * 1.0);
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

// updatefn
pub fn updateSpin(node: *nodes_.Node, st: *State) void {
    const up = vec3(0.0, 1.0, 0.0);
    const velocity: f32 = 5.0 * st.delta_time;
    const angle = math.degreesToRadians(velocity);
    const turn_rotation = Quat.fromAxisAngle(&up, angle);
    node.transform.rotation = node.transform.rotation.mulQuat(&turn_rotation);
}
// Exponential decay function
pub fn exponentialDecay(a: f32, b: f32, decay: f32, dt: f32) f32 {
    return b + (a - b) * std.math.expm1(-decay * dt);
}

// Exponential decay constant
// useful range approx. 1 to 25 from slow to fast
// const decay: f32 = 16;
//
// pub fn update(delta_time: f32) void {
// 	a = exp_decay(a, b, decay, delta_time);
// }
//
pub fn moveTowards(currentPosition: Vec3, targetPosition: Vec3, speed: f32, deltaTime: f32) Vec3 {
    // Calculate the direction vector towards the target
    var direction = targetPosition.sub(currentPosition);

    // Calculate the distance to the target
    const distanceToTarget = direction.length();

    // If the character is very close to the target, snap to the target position
    if (distanceToTarget < 0.01) {
        return targetPosition;
    }

    // Normalize the direction to get a constant movement vector
    direction = direction.normalize();

    // Calculate how far to move this frame (based on speed and deltaTime)
    const moveDistance = speed * deltaTime;

    // Ensure we don't overshoot the target
    if (moveDistance > distanceToTarget) {
        return targetPosition;
    }

    // Move the character by moveDistance in the direction of the target
    return currentPosition.add(direction.scale(moveDistance));
}
