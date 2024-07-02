const std = @import("std");
const glfw = @import("zglfw");
const a = @import("miniaudio").MiniAudio;

const Allocator = std.mem.Allocator;
const log = std.log.scoped(.SoundEngine);

const SoundEngine = struct {
    allocator: Allocator,
    engine: *a.ma_engine,
    sound: *a.ma_sound,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        a.ma_sound_uninit(self.sound);
        self.allocator.destroy(self.sound);

        _ = a.ma_engine_stop(self.engine);
        a.ma_engine_uninit(self.engine);
        self.allocator.destroy(self.engine);
    }

    pub fn init(allocator: Allocator) !Self {
        const engine = try allocator.create(a.ma_engine);

        if (a.ma_engine_init(null, engine) != a.MA_SUCCESS) {
            log.info("error.AudioInitError", .{});
            return error.AudioInitError;
        }

        const path: [:0]const u8 = "assets/Audio/Enemy_SFX/enemy_Spider_DestroyedExplosion.wav";

        const sound = try allocator.create(a.ma_sound);

        const result = a.ma_sound_init_from_file(
            engine,
            path,
            a.MA_SOUND_FLAG_ASYNC |
            a.MA_SOUND_FLAG_NO_PITCH | a.MA_SOUND_FLAG_NO_SPATIALIZATION | a.MA_SOUND_FLAG_STREAM,
            null,
            null,
            sound,
        );

        if (result != a.MA_SUCCESS) {
            log.info("error: {any}", .{result});
            // std.log.scoped(.audio).warn("Could not load music '{s}'", .{path});
            // allocator.destroy(sound);
            // return;
        }

        return .{
            .allocator = allocator,
            .engine = engine,
            .sound = sound,
        };
    }

    pub fn playSound(self: *const Self) void {
        a.ma_sound_set_volume(self.sound, 2.0);
        
        if (a.ma_sound_is_playing(self.sound) != 0) {
            _ = a.ma_sound_stop(self.sound);
            _ = a.ma_sound_seek_to_pcm_frame(self.sound, 0);
        }

        log.info("start sound", .{});
        if (a.ma_sound_start(self.sound) != a.MA_SUCCESS) {
            log.info("Could not start music", .{});
        }
    }
};

var sound_engine: SoundEngine = undefined;

pub fn main() !void {

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

    _ = window.setKeyCallback(key_handler);

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    sound_engine = try SoundEngine.init(allocator);

    while (!window.shouldClose()) {
        glfw.pollEvents();

        window.swapBuffers();
    }

    sound_engine.deinit();
    log.info("done.\n", .{});
}

fn key_handler (window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;
    _ = mods;
    switch (key) {
        .escape => { window.setShouldClose(true); },
        .t => {
            if (action == glfw.Action.press) {
                const time: f32 = @floatCast(glfw.getTime());
                log.info("time: {d}", .{time});
            }
        },
        .p => {
            sound_engine.playSound();
        },
        else => {}
    }
}
