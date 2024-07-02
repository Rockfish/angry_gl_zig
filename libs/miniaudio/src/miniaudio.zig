const std = @import("std");

pub const MiniAudio = @cImport({
    @cInclude("miniaudio.h");
});
