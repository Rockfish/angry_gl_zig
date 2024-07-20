const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const gl = zopengl.bindings;

const settings = @import("settings.zig");

const Allocator = std.mem.Allocator;

const content_dir = @import("build_options").content_dir;
const window_title = "gui settings";

// only works if file is in the current package
//const embedded_font_data = @embedFile("FiraCode-Medium.ttf");

const GuiState = struct {
    texture: *Texture,
    //font_normal: zgui.Font,
    //font_large: zgui.Font,
    alloced_input_text_buf: [:0]u8,
    alloced_input_text_multiline_buf: [:0]u8,
    alloced_input_text_with_hint_buf: [:0]u8,
};

var game_settings: settings.GameSettings = undefined;
var frame_counter: FrameCount = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try glfw.init();
    defer glfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(1600, 1000, window_title, null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    window.setSizeLimits(400, 400, -1, -1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    gl.enable(gl.DEPTH_TEST);

    const guiState = try create(allocator, window);
    defer destroy(allocator, guiState);

    frame_counter = FrameCount.new();

    const settings_file = content_dir ++ "settings.toml";
    std.debug.print("settings_file = {s}\n", .{settings_file});

    game_settings = try settings.getSettings(allocator, settings_file, 0.0);

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        glfw.pollEvents();

        gl.clearColor(0.05, 0.4, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        const time: f32 = @floatCast(glfw.getTime());

        try settings.writeSettings(allocator, settings_file, game_settings, time);

        try update(guiState);

        draw(guiState);

        window.swapBuffers();
    }
}

fn create(allocator: std.mem.Allocator, window: *glfw.Window) !*GuiState {
    const texture = try Texture.new(allocator, content_dir ++ "images/genart_0025_5.png");

    zgui.init(allocator);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    const font_size = 16.0 * scale_factor;
    const font_large = zgui.io.addFontFromFile(content_dir ++ "fonts/FiraCode-Medium.ttf", math.floor(font_size));
    const font_normal = zgui.io.addFontFromFile(content_dir ++ "fonts/Roboto-Medium.ttf", math.floor(font_size));

    assert(zgui.io.getFont(0) == font_large);
    assert(zgui.io.getFont(1) == font_normal);

    // This needs to be called *after* adding your custom fonts.
    zgui.backend.init(window);

    // This call is optional. Initially, zgui.io.getFont(0) is a default font.
    zgui.io.setDefaultFont(font_normal);

    // You can directly manipulate zgui.Style *before* `newFrame()` call.
    // Once frame is started (after `newFrame()` call) you have to use
    // zgui.pushStyleColor*()/zgui.pushStyleVar*() functions.
    const style = zgui.getStyle();

    style.window_min_size = .{ 320.0, 240.0 };
    style.scrollbar_size = 6.0;
    var color = style.getColor(.scrollbar_grab);
    color[1] = 0.8;
    style.setColor(.scrollbar_grab, color);
    style.scaleAllSizes(scale_factor);

    const guiState = try allocator.create(GuiState);
    guiState.* = .{
        .texture = texture,
        //.font_normal = font_normal,
        //.font_large = font_large,
        .alloced_input_text_buf = try allocator.allocSentinel(u8, 4, 0),
        .alloced_input_text_multiline_buf = try allocator.allocSentinel(u8, 4, 0),
        .alloced_input_text_with_hint_buf = try allocator.allocSentinel(u8, 4, 0),
    };

    guiState.alloced_input_text_buf[0] = 0;
    guiState.alloced_input_text_multiline_buf[0] = 0;
    guiState.alloced_input_text_with_hint_buf[0] = 0;

    return guiState;
}

fn destroy(allocator: std.mem.Allocator, state: *GuiState) void {
    zgui.backend.deinit();
    zgui.deinit();
    state.texture.deinit();
    allocator.free(state.alloced_input_text_buf);
    allocator.free(state.alloced_input_text_multiline_buf);
    allocator.free(state.alloced_input_text_with_hint_buf);
    allocator.destroy(state);
}

var check_b = false;

const SimpleEnum = enum {
    first,
    second,
    third,
};
const SparseEnum = enum(i32) {
    first = 10,
    second = 100,
    third = 1000,
};
const NonExhaustiveEnum = enum(i32) {
    first = 10,
    second = 100,
    third = 1000,
    _,
};

fn update(state: *GuiState) !void {
    _ = state;
    frame_counter.update();

    zgui.backend.newFrame(
        1600.0,
        1000.0,
    );

    zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
    zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

    zgui.pushStyleVar1f(.{ .idx = .window_rounding, .v = 5.0 });
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 5.0, 5.0 } });
    defer zgui.popStyleVar(.{ .count = 2 });

    if (zgui.begin("Settings", .{})) {
        zgui.bullet();
        zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Performance :");
        zgui.sameLine(.{});
        zgui.text(
            "{d:.3} ms/frame ({d:.1} fps)",
            .{ frame_counter.frame_time, frame_counter.fps }, // todo: fix
        );

        zgui.separator();

        zgui.text("Lighting Settings", .{});
        const light_factor: zgui.DragFloat = .{ .v = &game_settings.lighting_settings.light_factor, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const non_blue: zgui.DragFloat = .{ .v = &game_settings.lighting_settings.non_blue, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const blur_scale: zgui.DragInt = .{ .v = &game_settings.lighting_settings.blur_scale, .max = 10, .min = 0, .speed = 1 };
        const floor_light_factor: zgui.DragFloat = .{ .v = &game_settings.lighting_settings.floor_light_factor, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const floor_non_blue: zgui.DragFloat = .{ .v = &game_settings.lighting_settings.floor_non_blue, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const light_direction: zgui.DragFloat3 = .{ .v = game_settings.lighting_settings.light_direction.asArrayPtr(), .max = 1.0, .min = 0.0, .speed = 0.01 };
        const player_light_direction: zgui.DragFloat3 = .{ .v = game_settings.lighting_settings.player_light_direction.asArrayPtr(), .max = 1.0, .min = 0.0, .speed = 0.01 };
        const muzzle_point_light_color: zgui.DragFloat3 = .{ .v = game_settings.lighting_settings.muzzle_point_light_color.asArrayPtr(), .max = 1.0, .min = 0.0, .speed = 0.01 };

        _ = zgui.dragFloat("light_factor", light_factor);
        _ = zgui.dragFloat("non_blue", non_blue);
        _ = zgui.dragInt("blur_scale", blur_scale);
        _ = zgui.dragFloat("floor_light_factor", floor_light_factor);
        _ = zgui.dragFloat("floor_non_blue", floor_non_blue);
        _ = zgui.dragFloat3("light_direction", light_direction);
        _ = zgui.dragFloat3("player_light_direction", player_light_direction);
        _ = zgui.dragFloat3("muzzle_point_light_color", muzzle_point_light_color);

        zgui.separator();

        zgui.text("Player Settings", .{});
        const player_speed: zgui.DragFloat = .{ .v = &game_settings.player_settings.player_speed, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const fire_interval: zgui.DragFloat = .{ .v = &game_settings.player_settings.fire_interval, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const player_collision_radius: zgui.DragFloat = .{ .v = &game_settings.player_settings.player_collision_radius, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const player_model_scale: zgui.DragFloat = .{ .v = &game_settings.player_settings.player_model_scale, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const player_model_gun_height: zgui.DragFloat = .{ .v = &game_settings.player_settings.player_model_gun_height, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const player_model_gun_muzzle_offset: zgui.DragFloat = .{ .v = &game_settings.player_settings.player_model_gun_muzzle_offset, .max = 1.0, .min = 0.0, .speed = 0.01 };
        const anim_transition_time: zgui.DragFloat = .{ .v = &game_settings.player_settings.anim_transition_time, .max = 1.0, .min = 0.0, .speed = 0.01 };

        _ = zgui.dragFloat("player_speed", player_speed);
        _ = zgui.dragFloat("fire_interval", fire_interval);
        _ = zgui.dragFloat("player_collision_radius", player_collision_radius);
        _ = zgui.dragFloat("player_model_scale", player_model_scale);
        _ = zgui.dragFloat("player_model_gun_height", player_model_gun_height);
        _ = zgui.dragFloat("player_model_gun_muzzle_offset", player_model_gun_muzzle_offset);
        _ = zgui.dragFloat("anim_transition_time", anim_transition_time);

        zgui.separator();
    }
    zgui.end();
}

fn draw(state: *GuiState) void {
    _ = state;

    zgui.backend.draw();
}

pub const Texture = struct {
    id: u32,
    width: u32,
    height: u32,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *const Texture) void {
        self.allocator.destroy(self);
    }

    pub fn new(allocator: std.mem.Allocator, path: [:0]const u8) !*Texture {
        zstbi.init(allocator);
        defer zstbi.deinit();

        // zstbi.setFlipVerticallyOnLoad(texture_config.flip_v);

        var image = zstbi.Image.loadFromFile(path, 0) catch |err| {
            std.debug.print("Texture loadFromFile error: {any}  filepath: {s}\n", .{ err, path });
            @panic(@errorName(err));
        };
        defer image.deinit();

        const format: u32 = switch (image.num_components) {
            0 => gl.RED,
            3 => gl.RGB,
            4 => gl.RGBA,
            else => gl.RED,
        };

        var texture_id: gl.Uint = undefined;

        // std.debug.print("Texture: generating a texture\n", .{});
        gl.genTextures(1, &texture_id);

        // std.debug.print("Texture: binding a texture\n", .{});
        gl.bindTexture(gl.TEXTURE_2D, texture_id);

        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            format,
            @intCast(image.width),
            @intCast(image.height),
            0,
            format,
            gl.UNSIGNED_BYTE,
            image.data.ptr,
        );

        gl.generateMipmap(gl.TEXTURE_2D);

        const wrap_param: i32 = gl.REPEAT;

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_param);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_param);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        const texture = try allocator.create(Texture);
        texture.* = Texture{
            .id = texture_id,
            .width = image.width,
            .height = image.height,
            .allocator = allocator,
        };
        return texture;
    }
};

pub const FrameCount = struct {
    last_printed_instant: i64,
    frame_count: f32,
    fps: f32,
    frame_time: f32,

    const Self = @This();

    pub fn new() Self {
        return .{
            .last_printed_instant = std.time.milliTimestamp(),
            .frame_count = 0.0,
            .frame_time = 0.0,
            .fps = 0.0,
        };
    }

    pub fn update(self: *Self) void {
        self.frame_count += 1.0;

        const new_instant = std.time.milliTimestamp();
        const diff: f32 = @floatFromInt(new_instant - self.last_printed_instant);
        const elapsed_secs: f32 = diff / 1000.0;

        if (elapsed_secs > 1.0) {
            const elapsed_ms = elapsed_secs * 1000.0;
            self.frame_time = elapsed_ms / self.frame_count;
            self.fps = self.frame_count / elapsed_secs;
            //std.debug.print("FPS: {d:.4}  Frame time {d:.2}ms\n", .{self.fps, self.frame_time});
            self.last_printed_instant = new_instant;
            self.frame_count = 0.0;
        }
    }
};
