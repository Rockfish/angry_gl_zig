const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const nodes = @import("nodes.zig");
const shapes = core.shapes;

const state_ = @import("state.zig");
const State = state_.State;

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
const Transform = core.Transform;

const AnimationClip = core.animation.AnimationClip;

const Camera = core.Camera;

const Window = glfw.Window;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

// pub var state: State = undefined;

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {

    state_.initWindowHandlers(window);

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
    defer camera.deinit();

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
            .key_presses = EnumSet(glfw.Key).initEmpty(),
        },
    };

    const state = &state_.state;

    var node_manager = try nodes.NodeManager.init(allocator);
    defer node_manager.deinit();

    var texture_cache = std.ArrayList(*Texture).init(allocator);
    defer {
        for (texture_cache.items) |_texture| { 
            _texture.deinit(); 
        }
        texture_cache.deinit();
    }

    const basic_shader = try Shader.new(
        allocator,
        "game_level_001/shaders/basic_model.vert",
        "game_level_001/shaders/basic_model.frag",
    );
    defer basic_shader.deinit();

    const model_shader = try Shader.new(allocator, 
        "game_level_001/shaders/player_shader.vert", 
        //"game_level_001/shaders/player_shader.frag",
        "game_level_001/shaders/basic_model.frag",
    );
    defer model_shader.deinit();

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
    try texture_cache.append(cube_texture);

    texture_diffuse.wrap = TextureWrap.Repeat;

    const surface_texture = try Texture.init(
        allocator,
        "angrybots_assets/Models/Floor D.png",
        //"assets/texturest/IMGP5487_seamless.jpg",
        texture_diffuse,
    );
    try texture_cache.append(surface_texture);

    const model_paths = [_][]const u8{
        "/Users/john/Dev/Assets/spacekit_2/Models/OBJ format/alien.obj",
        "/Users/john/Dev/Assets/Low_P_Bot_0201.fbx",
        "assets/models/Capsule.obj",
        "/Users/john/Dev/Assets/glTF-Sample-Models/1.0/BarramundiFish/glTF/BarramundiFish.gltf",
        "/Users/john/Dev/Assets/glTF-Sample-Models/1.0/RiggedFigure/glTF/RiggedFigure.gltf",
        "/Users/john/Dev/Repos/irrlicht/media/faerie.md2", // use skipModelTextures
        "/Users/john/Downloads/Robot2.fbx",
        "/Users/john/Dev/Assets/modular_characters/Individual Characters/FBX/Spacesuit.fbx",
        // these are not loading
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/RiggedFigure/glTF-Binary/RiggedFigure.glb",
        "/Users/john/Dev/Assets/glTF-Sample-Models/2.0/RiggedFigure/glTF/RiggedFigure.gltf",
        "/Users/john/Dev/Repos/Egregoria/assets/models/pedestrian.glb",
    };

    std.debug.print("Loading model: {s}\n", .{model_paths[7]});
    var builder = try ModelBuilder.init(allocator, &texture_cache, "alien", model_paths[7]);
    //try builder.addTexture("Robot2", texture_diffuse, "/Users/john/Dev/Zig/Dev/angry_gl_zig/assets/textures/IMGP5487_seamless.jpg");
    var model = try builder.build();
    builder.deinit();

    defer model.deinit();

    var basic_obj = nodes.BasicObj.init("basic");

    var cube_obj = nodes.ShapeObj.init(&cubeboid, "cubeShape", cube_texture);
    var cylinder_obj = nodes.ShapeObj.init(&cylinder, "cylinderShape", cube_texture);
    var sphere_obj = nodes.ShapeObj.init(&sphere, "SphereShape", cube_texture);
    var model_obj = nodes.ModelObj.init(model, "Bot_Model");

    const root_node = try node_manager.create("root_node", .{ .basic = &basic_obj });
    const model_node = try nodes.Node.init(allocator, "robot", .{ .model = &model_obj });
    defer model_node.deinit();

    model_node.setTranslation(vec3(0.0, 0.0, 0.0));
    model_node.setRotation(Quat.fromAxisAngle(&vec3(1.0, 0.0, 0.0), math.degreesToRadians(-90.0)));
    model_node.setScale(vec3(3.5, 3.5, 3.5));
    model_node.updateTransforms(null);

    const node_cylinder = try node_manager.create("shape_cylinder", .{ .shape = &cylinder_obj });
    const node_sphere = try node_manager.create("shpere_shape", .{ .shape = &sphere_obj });

    node_sphere.setTranslation(vec3(-3.0, 1.0, 3.0));

    //try root_node.addChild(node_model);
    try root_node.addChild(node_cylinder);

    const cube_positions = [_]Vec3{
        vec3(3.0, 0.5, 0.0),
        vec3(1.5, 0.5, 0.0),
        vec3(0.0, 0.5, 0.0),
        vec3(-1.5, 0.5, 0.0),
        vec3(-3.0, 0.5, 0.0),
    };

    for (cube_positions) |position| {
        const cube = try node_manager.create("cube_shape", .{ .shape = &cube_obj });
        cube.setTranslation(position);
        try root_node.addChild(cube);

        const fix_cube = try node_manager.create("cube_shape", .{ .shape = &cube_obj });
        fix_cube.setTranslation(position);
    }

    const node_cube_spin = try node_manager.create("spin_cube", .{ .shape = &cube_obj });

    node_cube_spin.setTranslation(vec3(0.0, 6.0, 0.0));
    try node_cylinder.addChild(node_cube_spin);

    const xz_plane_point = vec3(0.0, 0.0, 0.0);
    const xz_plane_normal = vec3(0.0, 1.0, 0.0);

    var moving = false;

    const clip = AnimationClip.init(0.0, 32.0, core.animation.AnimationRepeatMode.Forever);
    try model_obj.model.playClip(clip);

    gl.enable(gl.DEPTH_TEST);

    // render loop
    // -----------
    while (!window.shouldClose()) {
        const current_time: f32 = @floatCast(glfw.getTime());
        state.delta_time = current_time - state.total_time;
        state.total_time = current_time;

        state.view = switch (state.view_type) {
            .LookAt => camera.get_lookat_view(),
            .LookTo => camera.get_lookto_view(),
        };

        state_.processKeys();

        gl.clearColor(0.1, 0.3, 0.1, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const world_ray = math.getWorldRayFromMouse(
            state.scaled_width,
            state.scaled_height,
            &state.projection,
            &state.view,
            state.input.mouse_x,
            state.input.mouse_y,
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


        basic_shader.setMat4("matProjection", &state.projection);
        basic_shader.setMat4("matView", &state.view);
        basic_shader.setVec3("ambient_color", &vec3(1.0, 0.6, 0.6));
        basic_shader.setVec3("light_color", &vec3(0.35, 0.4, 0.5));
        basic_shader.setVec3("light_dir", &vec3(3.0, 3.0, 3.0));
        basic_shader.bindTexture(0, "texture_diffuse", cube_texture);

        model_shader.setMat4("matProjection", &state.projection);
        model_shader.setMat4("matView", &state.view);
        model_shader.setVec3("ambient_color", &vec3(1.0, 0.6, 0.6));
        model_shader.setVec3("light_color", &vec3(0.35, 0.4, 0.5));
        model_shader.setVec3("light_dir", &vec3(3.0, 3.0, 3.0));

        if (state.input.mouse_left_button and state.world_point != null) {
            state.target_position = state.world_point.?;
            moving = true;
        }

        if (moving) {
            var direction = state.target_position.sub(&state.current_position);
            const distance = direction.length();

            if (distance < 0.1) {
                state.current_position = state.target_position;
                moving = false;
            } else {
                direction = direction.normalize();
                const moveDistance = state.delta_time * 20.0;

                if (moveDistance > distance) {
                    state.current_position = state.target_position;
                    moving = false;
                } else {
                    state.current_position = state.current_position.add(&direction.mulScalar(moveDistance));
                }
            }
        }

        // model_node.updateAnimation(state.delta_time);
        model_node.render(model_shader);
        //model_node.render(basic_shader);

        root_node.setTranslation(state.current_position);

        updateSpin(node_cylinder, state);
        root_node.updateTransforms(null);

        const Picked = struct {
            id: ?u32,
            distance: f32,
        };

        var picked = Picked{
            .id = null,
            .distance = 10000.0,
        };

        for (node_manager.node_list.items, 0..) |n, id| {
            if (n.object.getBoundingBox()) |aabb| {
                const box = aabb.transform(&n.global_transform.get_matrix());
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

        for (node_manager.node_list.items, 0..) |n, id| {
            if (picked.id != null and picked.id == @as(u32, @intCast(id))) {
                basic_shader.setVec4("hit_color", &vec4(1.0, 0.0, 0.0, 0.0));
            }
            _ = n;
            //n.render(basic_shader);
            basic_shader.setVec4("hit_color", &vec4(0.0, 0.0, 0.0, 0.0));
        }

        const plane_transform = Mat4.fromTranslation(&vec3(0.0, -1.0, 0.0));

        basic_shader.setMat4("matModel", &plane_transform);
        basic_shader.bindTexture(0, "texture_diffuse", surface_texture);
        plane.render();

        if (state.spin) {
            state.camera.processMovement(.OrbitRight, state.delta_time * 1.0);
        }

        window.swapBuffers();
        glfw.pollEvents();
    }

    //glfw.terminate();
}

// updatefn
pub fn updateSpin(node: *nodes.Node, st: *const State) void {
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
