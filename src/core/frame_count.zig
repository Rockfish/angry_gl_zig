const std = @import("std");

const log = std.log.scoped(.FrameCount);

pub const FrameCount = struct {
    last_printed_instant: i64,
    frame_count: f32,

    const Self = @This();

    pub fn new() Self {
        return .{
            .last_printed_instant = std.time.milliTimestamp(),
            .frame_count = 0.0,
        };
    }

    pub fn update(self: *Self) void {
        self.frame_count += 1.0;

        const new_instant = std.time.milliTimestamp();
        const diff: f32 = @floatFromInt(new_instant - self.last_printed_instant);
        const elapsed_secs: f32 = diff / 1000.0;

        if (elapsed_secs > 1.0) {
            const elapsed_ms = elapsed_secs * 1000.0;
            const frame_time: f32 = elapsed_ms / self.frame_count;
            const fps: f32 = self.frame_count / elapsed_secs;
            // std.debug.print("Frame count: {d} elapsed_secs: {d:.4} Frame time {d:.2}ms ({d:.4} FPS)\n", .{self.frame_count, elapsed_secs, frame_time, fps});
            // log.info("FPS: {d:.4}  Frame time {d:.2}ms", .{fps, frame_time});
            std.debug.print("FPS: {d:.4}  Frame time {d:.2}ms\n", .{fps, frame_time});

            self.last_printed_instant = new_instant;
            self.frame_count = 0.0;
        }
    }
};
