const std = @import("std");
const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const SIZE_OF_FLOAT = @sizeOf(f32);

const BLUR_SCALE: i32 = 2;
pub const SHADOW_WIDTH: i32 = 6 * 1024;
pub const SHADOW_HEIGHT: i32 = 6 * 1024;

pub const FrameBuffer = struct {
    framebuffer_id: u32, // framebuffer object
    texture_id: u32,     // texture object
};

pub fn createDepthMapFbo() FrameBuffer {
    var depth_map_fbo: gl.Uint = 0;
    var depth_map_texture: gl.Uint = 0;

    const border_color: [4]f32 = .{1.0, 1.0, 1.0, 1.0};

    gl.genFramebuffers(1, &depth_map_fbo);
    gl.genTextures(1, &depth_map_texture);

    gl.bindTexture(gl.TEXTURE_2D, depth_map_texture);

    gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.DEPTH_COMPONENT,
        SHADOW_WIDTH,
        SHADOW_HEIGHT,
        0,
        gl.DEPTH_COMPONENT,
        gl.FLOAT,
        null
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER); // gl.REPEAT in book
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER); // gl.REPEAT in book

    gl.texParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, &border_color);

    gl.bindFramebuffer(gl.FRAMEBUFFER, depth_map_fbo);
    gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.TEXTURE_2D, depth_map_texture, 0);

    gl.drawBuffer(gl.NONE); // specifies no color data
    gl.readBuffer(gl.NONE); // specifies no color data
    gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = depth_map_fbo,
        .texture_id = depth_map_texture,
    };
}

pub fn createEmissionFbo(viewport_width: f32, viewport_height: f32) FrameBuffer {
    const width: i32 = @intFromFloat(viewport_width);
    const height: i32 = @intFromFloat(viewport_height);
    var emission_fbo: gl.Uint = 0;
    var emission_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &emission_fbo);
        gl.genTextures(1, &emission_texture);

        gl.bindFramebuffer(gl.FRAMEBUFFER, emission_fbo);
        gl.bindTexture(gl.TEXTURE_2D, emission_texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            width,
            height,
            0,
            gl.RGB,
            gl.FLOAT,
            null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
        const border_color2: [4]f32 = .{0.0, 0.0, 0.0, 0.0};
        gl.texParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, &border_color2);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, emission_texture, 0);

        var rbo: gl.Uint = 0;
        gl.genRenderbuffers(1, &rbo);
        gl.bindRenderbuffer(gl.RENDERBUFFER, rbo);
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH_COMPONENT16, width, height);
        gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_ATTACHMENT, gl.RENDERBUFFER, rbo);

        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = emission_fbo,
        .texture_id = emission_texture,
    };
}

pub fn createSceneFbo(viewport_width: f32, viewport_height: f32) FrameBuffer {
    const width: i32 = @intFromFloat(viewport_width);
    const height: i32 = @intFromFloat(viewport_height);
    var scene_fbo: gl.Uint = 0;
    var scene_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &scene_fbo);
        gl.genTextures(1, &scene_texture);

        gl.bindFramebuffer(gl.FRAMEBUFFER, scene_fbo);
        gl.bindTexture(gl.TEXTURE_2D, scene_texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            width,
            height,
            0,
            gl.RGB,
            gl.FLOAT,
            null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, scene_texture, 0);

        var rbo: gl.Uint = 0;

        gl.genRenderbuffers(1, &rbo);
        gl.bindRenderbuffer(gl.RENDERBUFFER, rbo);
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, width, height);
        gl.framebufferRenderbuffer(gl.FRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            std.debug.panic("Frame buffer not complete!", .{});
        }

        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = scene_fbo,
        .texture_id = scene_texture,
    };
}

pub fn createHorizontalBlurFbo(viewport_width: f32, viewport_height: f32) FrameBuffer {
    const width: i32 = @intFromFloat(viewport_width / BLUR_SCALE);
    const height: i32 = @intFromFloat(viewport_height / BLUR_SCALE);
    var horizontal_blur_fbo: gl.Uint = 0;
    var horizontal_blur_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &horizontal_blur_fbo);
        gl.genTextures(1, &horizontal_blur_texture);

        gl.bindFramebuffer(gl.FRAMEBUFFER, horizontal_blur_fbo);
        gl.bindTexture(gl.TEXTURE_2D, horizontal_blur_texture);

        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            width,
            height,
            0,
            gl.RGB,
            gl.FLOAT,
            null,
        );

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, horizontal_blur_texture, 0);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            std.debug.panic("Frame buffer not complete!", .{});
        }

        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = horizontal_blur_fbo,
        .texture_id = horizontal_blur_texture,
    };
}

pub fn createVerticalBlurFbo(viewport_width: f32, viewport_height: f32) FrameBuffer {
    const width: i32 = @intFromFloat(viewport_width / BLUR_SCALE);
    const height: i32 = @intFromFloat(viewport_height / BLUR_SCALE);
    var vertical_blur_fbo: gl.Uint = 0;
    var vertical_blur_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &vertical_blur_fbo);
        gl.genTextures(1, &vertical_blur_texture);

        gl.bindFramebuffer(gl.FRAMEBUFFER, vertical_blur_fbo);
        gl.bindTexture(gl.TEXTURE_2D, vertical_blur_texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            width,
            height,
            0,
            gl.RGB,
            gl.FLOAT,
            null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, vertical_blur_texture, 0);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            std.debug.panic("Frame buffer not complete!", .{});
        }

        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = vertical_blur_fbo,
        .texture_id = vertical_blur_texture,
    };
}
