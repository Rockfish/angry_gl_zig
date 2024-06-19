const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zstbi = @import("zstbi");
const set = @import("ziglangSet");
const core = @import("core");
const math = @import("math");
const world = @import("world.zig");

const FloatMode = @import("std").builtin.FloatMode;

const State = world.State;
const CameraType = world.CameraType;
const Player = @import("player.zig").Player;
const Enemy = @import("enemy.zig").Enemy;
const EnemySystem = @import("enemy.zig").EnemySystem;
const BulletStore = @import("bullets.zig").BulletStore;
const BurnMarks = @import("burn_marks.zig").BurnMarks;
const MuzzleFlash = @import("muzzle_flash.zig").MuzzleFlash;
const Floor = @import("floor.zig").Floor;
const SoundSystem = @import("sound_system.zig").SoundSystem;
const fb = @import("framebuffers.zig");
const quads = @import("quads.zig");

const ArrayList = std.ArrayList;

const gl = zopengl.bindings;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;

const Assimp = core.assimp.Assimp;
const Model = core.Model;
const ModelBuilder = core.ModelBuilder;
const Camera = core.Camera;
const Shader = core.Shader;
const String = core.string.String;
const FrameCount = core.FrameCount;
const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const Animator = core.animation.Animator;
const AnimationClip = core.animation.AnimationClip;
const AnimationRepeat = core.animation.AnimationRepeat;

const Window = glfw.Window;

const VIEW_PORT_WIDTH: f32 = 1500.0;
const VIEW_PORT_HEIGHT: f32 = 1000.0;

// Lighting
const LIGHT_FACTOR: f32 = 0.8;
const NON_BLUE: f32 = 0.9;
const BLUR_SCALE: i32 = 2;
const FLOOR_LIGHT_FACTOR: f32 = 0.35;
const FLOOR_NON_BLUE: f32 = 0.7;

const content_dir = "angrygl_assets";

const PV = struct {
    projection: Mat4,
    view: Mat4,
};

var state: State = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();
    core.string.init(allocator);

    // var arena_state = std.heap.ArenaAllocator.init(allocator);
    // defer arena_state.deinit();
    // const arena = arena_state.allocator();

    try glfw.init();
    defer glfw.terminate();

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(600, 600, "Angry ", null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    try run(allocator, window);
}

pub fn run(allocator: std.mem.Allocator, window: *glfw.Window) !void {
    var buffer: [1024]u8 = undefined;
    const root_path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
    _ = root_path;


    // Shaders

    const player_shader = try Shader.new( allocator, "game/shaders/player_shader.vert", "game/shaders/player_shader.frag");
    const player_emissive_shader = try Shader.new(allocator, "shaders/player_shader.vert", "shaders/texture_emissive_shader.frag");
    const wiggly_shader = try Shader.new(allocator, "shaders/wiggly_shader.vert", "shaders/player_shader.frag");
    const floor_shader = try Shader.new(allocator, "shaders/basic_texture_shader.vert", "shaders/floor_shader.frag");

    // bullets, muzzle flash, burn marks
    const instanced_texture_shader = try Shader.new(allocator, "shaders/instanced_texture_shader.vert", "shaders/basic_texture_shader.frag");
    const sprite_shader = try Shader.new(allocator, "shaders/geom_shader2.vert", "shaders/sprite_shader.frag");
    const basic_texture_shader = try Shader.new(allocator, "shaders/basic_texture_shader.vert", "shaders/basic_texture_shader.frag");

    // blur and scene
    const blur_shader = try Shader.new(allocator, "shaders/basicer_shader.vert", "shaders/blur_shader.frag");
    const scene_draw_shader = try Shader.new(allocator, "shaders/basicer_shader.vert", "shaders/texture_merge_shader.frag");

    // for debug
    const basicer_shader = try Shader.new(allocator, "shaders/basicer_shader.vert", "shaders/basicer_shader.frag");
    // const _depth_shader = try Shader.new(allocator, "shaders/depth_shader.vert", "shaders/depth_shader.frag");
    // const _debug_depth_shader = try Shader.new(allocator, "shaders/debug_depth_quad.vert", "shaders/debug_depth_quad.frag");

    // --- Lighting ---

    const light_dir = vec3(-0.8, 0.0, -1.0).normalize();
    const player_light_dir = vec3(-1.0, -1.0, -1.0).normalize();
    const muzzle_point_light_color = vec3(1.0, 0.2, 0.0);

    const light_color = vec3(NON_BLUE * 0.406, NON_BLUE * 0.723, 1.0).mulScalar(LIGHT_FACTOR * 1.0);
    const ambient_color =vec3(NON_BLUE * 0.7, NON_BLUE * 0.7, 0.7).mulScalar(LIGHT_FACTOR * 0.10);

    const floor_light_color = vec3(FLOOR_NON_BLUE * 0.406, FLOOR_NON_BLUE * 0.723, 1.0).mulScalar(FLOOR_LIGHT_FACTOR * 1.0);
    const floor_ambient_color =  vec3(FLOOR_NON_BLUE * 0.7, FLOOR_NON_BLUE * 0.7, 0.7).mulScalar(FLOOR_LIGHT_FACTOR * 0.50);

    const window_scale = window.getContentScale();

    var viewport_width = VIEW_PORT_WIDTH * window_scale[0];
    var viewport_height = VIEW_PORT_HEIGHT * window_scale[1];
    var scaled_width = viewport_width / window_scale[0];
    var scaled_height = viewport_height / window_scale[1];

    // -- Framebuffers ---

    const depth_map_fbo = fb.create_depth_map_fbo();
    var emissions_fbo = fb.create_emission_fbo(viewport_width, viewport_height);
    var scene_fbo = fb.create_scene_fbo(viewport_width, viewport_height);
    var horizontal_blur_fbo = fb.create_horizontal_blur_fbo(viewport_width, viewport_height);
    var vertical_blur_fbo = fb.create_vertical_blur_fbo(viewport_width, viewport_height);

    // --- quads ---

    const unit_square_quad = quads.create_unit_square_vao();
    // const _obnoxious_quad_vao = quads.create_obnoxious_quad_vao();
    const more_obnoxious_quad_vao = quads.create_more_obnoxious_quad_vao();


    // --- Cameras ---

    const camera_follow_vec = vec3(-4.0, 4.3, 0.0);
    // const _camera_up = vec3(0.0, 1.0, 0.0);

    const game_camera = try Camera.camera_vec3_up_yaw_pitch(
        allocator,
        vec3(0.0, 20.0, 80.0), // for xz world
        vec3(0.0, 1.0, 0.0),
        -90.0,
        -20.0,
    );

    const floating_camera = try Camera.camera_vec3_up_yaw_pitch(
        allocator,
        vec3(0.0, 10.0, 20.0), // for xz world
        vec3(0.0, 1.0, 0.0),
        -90.0,
        -20.0,
    );

    const ortho_camera = try Camera.camera_vec3_up_yaw_pitch(allocator, vec3(0.0, 1.0, 0.0), vec3(0.0, 1.0, 0.0), 0.0, -90.0);

    const ortho_width = VIEW_PORT_WIDTH / 130.0;
    const ortho_height = VIEW_PORT_HEIGHT / 130.0;
    const aspect_ratio = VIEW_PORT_WIDTH / VIEW_PORT_HEIGHT;
    const game_projection = Mat4.perspectiveRhGl(math.degreesToRadians(game_camera.zoom), aspect_ratio, 0.1, 100.0);
    const floating_projection = Mat4.perspectiveRhGl(math.degreesToRadians(floating_camera.zoom), aspect_ratio, 0.1, 100.0);
    const orthographic_projection = Mat4.orthographicRhGl(-ortho_width, ortho_width, -ortho_height, ortho_height, 0.1, 100.0);

    // Models and systems

    var texture_cache = ArrayList(*Texture).init(allocator);

    var player = try Player.new(allocator, &texture_cache);
    var enemies = try EnemySystem.new(allocator, &texture_cache);
    var muzzle_flash = try MuzzleFlash.new(allocator, unit_square_quad);
    var bullet_store = try BulletStore.new(allocator, unit_square_quad);
    const floor = try Floor.new(allocator);

    // Initialize the world state
    state = State{
        .viewport_width = viewport_width,
        .viewport_height = viewport_height,
        .scaled_width = scaled_width,
        .scaled_height = scaled_height,
        .game_camera = game_camera,
        .floating_camera = floating_camera,
        .ortho_camera = ortho_camera,
        .active_camera = CameraType.Game,
        .game_projection = game_projection,
        .floating_projection = floating_projection,
        .orthographic_projection = orthographic_projection,
        .player = player,
        .enemies = ArrayList(Enemy).init(allocator),
        .light_postion = vec3(1.2, 1.0, 2.0),
        .delta_time = 0.0,
        .last_frame = 0.0,
        .first_mouse = true,
        .last_x = VIEW_PORT_WIDTH / 2.0,
        .last_y = VIEW_PORT_HEIGHT / 2.0,
        .mouse_x = scaled_width / 2.0,
        .mouse_y = scaled_height / 2.0,
        .burn_marks = try BurnMarks.new(allocator, unit_square_quad),
        // .sound_system = undefined,
        .key_presses = set.Set(glfw.Key).init(allocator),
        .frame_time = 0.0,
        .run = true,
    };

    // Set fixed shader uniforms

    const shadow_texture_unit = 10;

    player_shader.use_shader();
    player_shader.set_vec3("directionLight.dir", &player_light_dir);
    player_shader.set_vec3("directionLight.color", &light_color);
    player_shader.set_vec3("ambient", &ambient_color);

    player_shader.set_int("shadow_map", shadow_texture_unit);
    player_shader.set_texture_unit(shadow_texture_unit, depth_map_fbo.texture_id);

    floor_shader.use_shader();
    floor_shader.set_vec3("directionLight.dir", &light_dir);
    floor_shader.set_vec3("directionLight.color", &floor_light_color);
    floor_shader.set_vec3("ambient", &floor_ambient_color);

    floor_shader.set_int("shadow_map", shadow_texture_unit);
    floor_shader.set_texture_unit(shadow_texture_unit, depth_map_fbo.texture_id);

    wiggly_shader.use_shader();
    wiggly_shader.set_vec3("directionLight.dir", &player_light_dir);
    wiggly_shader.set_vec3("directionLight.color", &light_color);
    wiggly_shader.set_vec3("ambient", &ambient_color);

    // --------------------------------

    const use_framebuffers = true;

    var buffer_ready = false;
    var aim_theta: f32 = 0.0;
    var quad_vao: gl.Uint = 0;

    const emission_texture_unit = 0;
    const horizontal_texture_unit = 1;
    const vertical_texture_unit = 2;
    const scene_texture_unit = 3;

    // --- event loop
    state.last_frame = @floatCast(glfw.getTime());
    var frame_counter = FrameCount.new();

    _ = window.setKeyCallback(key_handler);
    _ = window.setFramebufferSizeCallback(framebuffer_size_handler);
    _ = window.setCursorPosCallback(cursor_position_handler);
    _ = window.setScrollCallback(scroll_handler);

    while (!window.shouldClose()) {
        glfw.pollEvents();

        const currentFrame: f32 = @floatCast(glfw.getTime());
        state.delta_time = currentFrame - state.last_frame;
        state.last_frame = currentFrame;

        frame_counter.update();

        gl.clearColor(0.0, 0.02, 0.25, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        gl.enable(gl.DEPTH_TEST);

        if (viewport_width != state.viewport_width or viewport_height != state.viewport_height) {
            viewport_width = state.viewport_width;
            viewport_height = state.viewport_height;
            scaled_width = state.scaled_width;
            scaled_height = state.scaled_height;

            if (use_framebuffers) {
                emissions_fbo = fb.create_emission_fbo(viewport_width, viewport_height);
                scene_fbo = fb.create_scene_fbo(viewport_width, viewport_height);
                horizontal_blur_fbo = fb.create_horizontal_blur_fbo(viewport_width, viewport_height);
                vertical_blur_fbo = fb.create_vertical_blur_fbo(viewport_width, viewport_height);
            }
            std.debug.print( "view port size: {d}, {d}  scaled size: {d}, {d}\n", .{viewport_width, viewport_height, scaled_width, scaled_height});
        }

        state.game_camera.position = player.position.add(&camera_follow_vec);
        const game_view = Mat4.lookAtRhGl(&state.game_camera.position, &player.position, &state.game_camera.up);

        var pv: PV = undefined;
        switch (state.active_camera) {
            CameraType.Game => {
                pv = .{ .projection = state.game_projection, .view = game_view, };
            },
            CameraType.Floating => {
                const view = Mat4.lookAtRhGl(&state.floating_camera.position, &player.position, &state.floating_camera.up);
                pv = .{ .projection = state.floating_projection, .view = view, };
            },
            CameraType.TopDown => {
                const view = Mat4.lookAtRhGl(
                    &vec3(player.position.data[0], 1.0, player.position.data[1]),
                    &player.position,
                    &vec3(0.0, 0.0, -1.0),
                );
                pv = .{ .projection = state.orthographic_projection, .view = view, };
            },
            CameraType.Side => {
                const view = Mat4.lookAtRhGl(&vec3(0.0, 0.0, -3.0), &player.position, &vec3(0.0, 1.0, 0.0));
                pv = .{ .projection = state.orthographic_projection, .view = view, };
            },
        }

        const projection_view = pv.projection.mulMat4(&pv.view);

        var dx: f32 = 0.0;
        var dz: f32 = 0.0;

        if (player.is_alive and buffer_ready) {
            const world_ray = math.get_world_ray_from_mouse(
                state.mouse_x,
                state.mouse_y,
                state.scaled_width,
                state.scaled_height,
                &game_view,
                &state.game_projection,
            );

            const xz_plane_point = vec3(0.0, 0.0, 0.0);
            const xz_plane_normal = vec3(0.0, 1.0, 0.0);

            const world_point = math.ray_plane_intersection(&state.game_camera.position, &world_ray, &xz_plane_point, &xz_plane_normal);

            dx = world_point.?.data[0] - player.position.data[0];
            dz = world_point.?.data[1] - player.position.data[1];

            if (dz < 0.0) {
                aim_theta = math.atan(dx / dz) + math.pi;
            } else {
                aim_theta = math.atan(dx / dz);
            }

            if (@abs(state.mouse_x) < 0.005 and @abs(state.mouse_y) < 0.005) {
                aim_theta = 0.0;
            }
        }

        const aim_rot = Mat4.fromAxisAngle(&vec3(0.0, 1.0, 0.0), aim_theta);

        var player_transform = Mat4.fromTranslation(&player.position);
        player_transform.mulByMat4(&Mat4.fromScale(&Vec3.splat(world.PLAYER_MODEL_SCALE)));
        player_transform.mulByMat4(&aim_rot);

        const muzzle_transform = player.get_muzzle_position(&player_transform);

        if (player.is_alive and player.is_trying_to_fire and (player.last_fire_time + world.FIRE_INTERVAL) < state.frame_time) {
            player.last_fire_time = state.frame_time;
            if (try bullet_store.create_bullets(dx, dz, &muzzle_transform, world.SPREAD_AMOUNT)) {
                try muzzle_flash.add_flash();
                // state.sound_system.play_player_shooting();
            }
        }

        muzzle_flash.update(state.delta_time);
        bullet_store.update_bullets(&state);

        if (player.is_alive) {
            try enemies.update(&state);
            enemies.chase_player(&state);
        }

        // Update Player
        try player.update(&state, aim_theta);

        var use_point_light = false;
        var muzzle_world_position = Vec3.default();

        if (muzzle_flash.muzzle_flash_sprites_age.items.len != 0) {
            const min_age = muzzle_flash.get_min_age();
            const muzzle_world_position_vec4 = muzzle_transform.mulVec4(&vec4(0.0, 0.0, 0.0, 1.0));

            muzzle_world_position = vec3(
                muzzle_world_position_vec4.data[0] / muzzle_world_position_vec4.data[3],
                muzzle_world_position_vec4.data[1] / muzzle_world_position_vec4.data[3],
                muzzle_world_position_vec4.data[2] / muzzle_world_position_vec4.data[3],
            );

            use_point_light = min_age < 0.03;
        }

        const near_plane: f32 = 1.0;
        const far_plane: f32 = 50.0;
        const ortho_size: f32 = 10.0;
        const player_position = player.position;

        const light_projection = Mat4.orthographicRhGl(-ortho_size, ortho_size, -ortho_size, ortho_size, near_plane, far_plane);
        const light_view = Mat4.lookAtRhGl(&player_position.sub(&player_light_dir.mulScalar(-20)), &player_position, &vec3(0.0, 1.0, 0.0));
        const light_space_matrix = light_projection.mulMat4(&light_view);

        player_shader.use_shader();
        player_shader.set_mat4("projectionView", &projection_view);
        player_shader.set_mat4("model", &player_transform);
        player_shader.set_mat4("aimRot", &aim_rot);
        player_shader.set_vec3("viewPos", &state.game_camera.position);
        player_shader.set_mat4("lightSpaceMatrix", &light_space_matrix);
        player_shader.set_bool("usePointLight", use_point_light);
        player_shader.set_vec3("pointLight.color", &muzzle_point_light_color);
        player_shader.set_vec3("pointLight.worldPos", &muzzle_world_position);

        floor_shader.use_shader();
        floor_shader.set_vec3("viewPos", &state.game_camera.position);
        floor_shader.set_mat4("lightSpaceMatrix", &light_space_matrix);
        floor_shader.set_bool("usePointLight", use_point_light);
        floor_shader.set_vec3("pointLight.color", &muzzle_point_light_color);
        floor_shader.set_vec3("pointLight.worldPos", &muzzle_world_position);

        // shadows start - render to depth fbo
        gl.bindFramebuffer(gl.FRAMEBUFFER, depth_map_fbo.framebuffer_id);
        gl.viewport(0, 0, fb.SHADOW_WIDTH, fb.SHADOW_HEIGHT);
        gl.clear(gl.DEPTH_BUFFER_BIT);

        player_shader.use_shader();
        player_shader.set_bool("depth_mode", true);
        player_shader.set_bool("useLight", false);

        try player.render(player_shader);

        wiggly_shader.use_shader();
        wiggly_shader.set_mat4("projectionView", &projection_view);
        wiggly_shader.set_mat4("lightSpaceMatrix", &light_space_matrix);
        wiggly_shader.set_bool("depth_mode", true);

        enemies.draw_enemies(wiggly_shader, &state);

        // shadows end

        if (use_framebuffers) {
            // render to emission buffer

            gl.bindFramebuffer(gl.FRAMEBUFFER, emissions_fbo.framebuffer_id);
            gl.viewport(0, 0, @intFromFloat(viewport_width), @intFromFloat(viewport_height));
            gl.clearColor(0.0, 0.0, 0.0, 0.0);
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

            player_emissive_shader.use_shader();
            player_emissive_shader.set_mat4("projectionView", &projection_view);
            player_emissive_shader.set_mat4("model", &player_transform);

            try player.render(player_emissive_shader);

            // doesn't seem to do anything
            // {
            //     unsafe {
            //         gl.ColorMask(gl.FALSE, gl.FALSE, gl.FALSE, gl.FALSE);
            //     }
            //
            //     floor_shader.use_shader();
            //     floor_shader.set_bool("usePointLight", true);
            //     floor_shader.set_bool("useLight", true);
            //     floor_shader.set_bool("useSpec", true);
            //
            //     // floor.draw(&floor_shader, &projection_view);
            //
            //     unsafe {
            //         gl.ColorMask(gl.TRUE, gl.TRUE, gl.TRUE, gl.TRUE);
            //     }
            // }

            bullet_store.draw_bullets(instanced_texture_shader, &projection_view);

            const debug_emission = false;
            if (debug_emission) {
                const texture_unit = 0;
                gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
                gl.viewport(0, 0, viewport_width, viewport_height);
                gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

                gl.activeTexture(gl.TEXTURE0 + texture_unit);
                gl.bindTexture(gl.TEXTURE_2D, emissions_fbo.texture_id);

                basicer_shader.use_shader();
                basicer_shader.set_bool("greyscale", false);
                basicer_shader.set_int("tex", texture_unit);

                quads.render_quad(&quad_vao);

                buffer_ready = true;
                window.swap_buffers();
                continue;
            }
        }

        // const debug_depth = false;
        // if debug_depth {
        //     unsafe {
        //         gl.activeTexture(gl.TEXTURE0);
        //         gl.bindTexture(gl.TEXTURE_2D, depth_map_fbo.texture_id);
        //         gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        //     }
        //     debug_depth_shader.use_shader();
        //     debug_depth_shader.set_float("near_plane", near_plane);
        //     debug_depth_shader.set_float("far_plane", far_plane);
        //     render_quad(&quad_vao);
        // }

        // render to scene buffer for base texture
        if (use_framebuffers) {
            gl.bindFramebuffer(gl.FRAMEBUFFER, scene_fbo.framebuffer_id);
            gl.viewport(0, 0, @intFromFloat(viewport_width), @intFromFloat(viewport_height));
            gl.clearColor(0.0, 0.02, 0.25, 1.0);
            gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
        } else {
            gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
            gl.viewport(0, 0, viewport_width, viewport_height);
        }

        floor_shader.use_shader();
        floor_shader.set_bool("useLight", true);
        floor_shader.set_bool("useSpec", true);

        floor.draw(floor_shader, &projection_view);

        player_shader.use_shader();
        player_shader.set_bool("useLight", true);
        player_shader.set_bool("useEmissive", true);
        player_shader.set_bool("depth_mode", false);

        try player.render(player_shader);

        muzzle_flash.draw(sprite_shader, &projection_view, &muzzle_transform);

        wiggly_shader.use_shader();
        wiggly_shader.set_bool("useLight", true);
        wiggly_shader.set_bool("useEmissive", false);
        wiggly_shader.set_bool("depth_mode", false);

        enemies.draw_enemies(wiggly_shader, &state);

        state.burn_marks.draw_marks(basic_texture_shader, &projection_view, state.delta_time);
        bullet_store.draw_bullet_impacts(sprite_shader, &projection_view);

        if (!use_framebuffers) {
            bullet_store.draw_bullets(instanced_texture_shader, &projection_view);
        }

        if (use_framebuffers) {
            // generated blur and combine with emission and scene for final draw to framebuffer 0
            // gl.Disable(gl.DEPTH_TEST);

            // view port for blur effect
            gl.viewport(0, 0, viewport_width / BLUR_SCALE, viewport_height / BLUR_SCALE);

            // Draw horizontal blur
            gl.bindFramebuffer(gl.FRAMEBUFFER, horizontal_blur_fbo.framebuffer_id);
            gl.bindVertexArray(more_obnoxious_quad_vao);

            gl.activeTexture(gl.TEXTURE0 + emission_texture_unit);
            gl.bindTexture(gl.TEXTURE_2D, emissions_fbo.texture_id);

            blur_shader.use_shader();
            blur_shader.set_int("image", emission_texture_unit);
            blur_shader.set_bool("horizontal", true);

            gl.DrawArrays(gl.TRIANGLES, 0, 6);

            // Draw vertical blur
            gl.bindFramebuffer(gl.FRAMEBUFFER, vertical_blur_fbo.framebuffer_id);
            gl.bindVertexArray(more_obnoxious_quad_vao);

            gl.activeTexture(gl.TEXTURE0 + horizontal_texture_unit);
            gl.bindTexture(gl.TEXTURE_2D, horizontal_blur_fbo.texture_id);

            blur_shader.use_shader();
            blur_shader.set_int("image", horizontal_texture_unit);
            blur_shader.set_bool("horizontal", false);

            gl.drawArrays(gl.TRIANGLES, 0, 6);

            // view port for final draw combining everything
            gl.viewport(0, 0, viewport_width, viewport_height);

            gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
            gl.bindVertexArray(more_obnoxious_quad_vao);

            gl.activeTexture(gl.TEXTURE0 + vertical_texture_unit);
            gl.bindTexture(gl.TEXTURE_2D, vertical_blur_fbo.texture_id);

            gl.activeTexture(gl.TEXTURE0 + emission_texture_unit);
            gl.bindTexture(gl.TEXTURE_2D, emissions_fbo.texture_id);

            gl.activeTexture(gl.TEXTURE0 + scene_texture_unit);
            gl.bindTexture(gl.TEXTURE_2D, scene_fbo.texture_id);

            scene_draw_shader.use_shader();
            scene_draw_shader.set_int("base_texture", scene_texture_unit);
            scene_draw_shader.set_int("emission_texture", vertical_texture_unit);
            scene_draw_shader.set_int("bright_texture", emission_texture_unit);

            gl.drawArrays(gl.TRIANGLES, 0, 6);

            // gl.Enable(gl.DEPTH_TEST);

            const debug_blur = false;
            if (debug_blur) {
                const texture_unit = 0;
                gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

                gl.viewport(0, 0, viewport_width, viewport_height);
                gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

                gl.activeTexture(gl.TEXTURE0 + texture_unit);
                gl.bindTexture(gl.TEXTURE_2D, scene_fbo.texture_id);

                basicer_shader.use_shader();
                basicer_shader.set_bool("greyscale", false);
                basicer_shader.set_int("tex", texture_unit);

                quads.render_quad(&quad_vao);

                buffer_ready = true;
                window.swap_buffers();
                continue;
            }
        }

        buffer_ready = true;

        window.swapBuffers();
    }

    std.debug.print("\nRun completed.\n\n", .{});

    // shader.deinit();
    game_camera.deinit();
    // model.deinit();
    for (texture_cache.items) |_texture| {
        _texture.deinit();
    }
    texture_cache.deinit();
}

inline fn toRadians(degrees: f32) f32 {
    return degrees * (std.math.pi / 180.0);
}

fn key_handler (window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;
    _ = mods;
    switch (key) {
        .escape => { window.setShouldClose(true); },
        .t => {
            if (action == glfw.Action.press) {
                std.debug.print("time: {d}\n", .{state.delta_time});
            }
        },
        .w => { state.game_camera.process_keyboard(.Forward, state.delta_time);},
        .s => { state.game_camera.process_keyboard(.Backward, state.delta_time);},
        .a => { state.game_camera.process_keyboard(.Left, state.delta_time);},
        .d => { state.game_camera.process_keyboard(.Right, state.delta_time);},
        else => {}
    }
}

fn framebuffer_size_handler(window: *glfw.Window, width: i32, height: i32) callconv(.C) void {
    _ = window;
    gl.viewport(0, 0, width, height);
}

fn mouse_hander(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = window;
    _ = button;
    _ = action;
    _ = mods;
}

fn cursor_position_handler(window: *glfw.Window, xposIn: f64, yposIn: f64) callconv(.C) void {
    _ = window;
    const xpos: f32 = @floatCast(xposIn);
    const ypos: f32 = @floatCast(yposIn);

    if (state.first_mouse) {
        state.last_x = xpos;
        state.last_y = ypos;
        state.first_mouse = false;
    }

    const xoffset = xpos - state.last_x;
    const yoffset = state.last_y - ypos; // reversed since y-coordinates go from bottom to top

    state.last_x = xpos;
    state.last_y = ypos;

    state.game_camera.process_mouse_movement(xoffset, yoffset, true);
}

fn scroll_handler(window: *Window, xoffset: f64, yoffset: f64) callconv(.C) void {
    _ = window;
    _ = xoffset;
    state.game_camera.process_mouse_scroll(@floatCast(yoffset));
}
