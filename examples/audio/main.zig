const std = @import("std");
const glfw = @import("zglfw");
const a = @import("miniaudio").MiniAudio;

const Allocator = std.mem.Allocator;
const EnumMap = std.EnumMap;

const log = std.log.scoped(.SoundEngine);

pub const ClipName = enum {
    GunFire,
    Explosion,
};

const ClipData = struct {
    clip: ClipName,
    file: [:0]const u8,
};

const clips: [2]ClipData = .{
    .{
        .clip = .Explosion,
        .file = "angrybots_assets/Audio/Enemy_SFX/enemy_Spider_DestroyedExplosion.wav",
    },
    .{
        .clip = .GunFire,
        .file = "angrybots_assets/Audio/Player_SFX/player_shooting.wav",
    },
};

pub fn SoundEngine(comptime clipNameType: type, comptime clipDataType: type) type {
    return struct {
        allocator: Allocator,
        engine: *a.ma_engine,
        clipsData: EnumMap(clipNameType, *a.ma_sound),

        const Self = @This();

        pub fn deinit(self: *Self) void {
            var iter = self.clipsData.iterator();
            while (iter.next()) |item| {
                a.ma_sound_uninit(item.value.*);
                self.allocator.destroy(item.value.*);
            }
            _ = a.ma_engine_stop(self.engine);
            a.ma_engine_uninit(self.engine);
            self.allocator.destroy(self.engine);
        }

        pub fn init(allocator: Allocator, data: []const clipDataType) !Self {
            const engine = try allocator.create(a.ma_engine);

            if (a.ma_engine_init(null, engine) != a.MA_SUCCESS) {
                log.info("error.AudioInitError", .{});
                return error.AudioInitError;
            }

            var soundEngine: Self = .{
                .allocator = allocator,
                .engine = engine,
                .clipsData = EnumMap(clipNameType, *a.ma_sound).init(.{}),
            };

            for (data) |item| {
                const sound = try allocator.create(a.ma_sound);

                const result = a.ma_sound_init_from_file(
                    engine,
                    item.file,
                    a.MA_SOUND_FLAG_ASYNC | a.MA_SOUND_FLAG_NO_PITCH | a.MA_SOUND_FLAG_NO_SPATIALIZATION | a.MA_SOUND_FLAG_STREAM,
                    null,
                    null,
                    sound,
                );

                if (result != a.MA_SUCCESS) {
                    log.info("error: {any}", .{result});
                    std.log.scoped(.audio).warn("Could not load music '{s}'", .{item.file});
                    soundEngine.deinit();
                    return error.AudioInitError;
                }

                soundEngine.clipsData.put(item.clip, sound);
            }
            return soundEngine;
        }

        pub fn playSound(self: *const Self, clip: clipNameType) void {
            const sound = self.clipsData.get(clip);

            a.ma_sound_set_volume(sound, 2.0);

            if (a.ma_sound_is_playing(sound) != 0) {
                _ = a.ma_sound_stop(sound);
                _ = a.ma_sound_seek_to_pcm_frame(sound, 0);
            }

            log.info("start sound", .{});
            if (a.ma_sound_start(sound) != a.MA_SUCCESS) {
                log.info("Could not start music", .{});
            }
        }

        pub fn print(self: *Self) void {
            var iter = self.clipsData.iterator();
            while (iter.next()) |item| {
                std.debug.print("self = {any}\n", .{item});
            }
        }
    };
}

pub fn createSounds(allocator: Allocator) void {
    var s = SoundEngine(ClipName, ClipData).init(allocator, &clips) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        return;
    };

    s.print();

    s.deinit();
}

var sound_engine: SoundEngine(ClipName, ClipData) = undefined;

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

    sound_engine = SoundEngine(ClipName, ClipData).init(allocator, &clips) catch |err| {
        std.debug.print("Error: {any}\n", .{err});
        return;
    };

    while (!window.shouldClose()) {
        glfw.pollEvents();

        window.swapBuffers();
    }

    sound_engine.deinit();
    log.info("done.\n", .{});
}

fn key_handler(window: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.C) void {
    _ = scancode;
    _ = mods;
    if (action == glfw.Action.press) {
        switch (key) {
            .escape => {
                window.setShouldClose(true);
            },
            .t => {
                const time: f32 = @floatCast(glfw.getTime());
                log.info("time: {d}", .{time});
            },
            .f => {
                sound_engine.playSound(.GunFire);
            },
            .e => {
                sound_engine.playSound(.Explosion);
            },
            else => {},
        }
    }
}
