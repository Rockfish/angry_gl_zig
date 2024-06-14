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

pub fn create_depth_map_fbo() FrameBuffer {
    var depth_map_fbo: gl.Uint = 0;
    var depth_map_texture: gl.Uint = 0;

    const border_color: []f32 = .{1.0, 1.0, 1.0, 1.0};

    gl.genFramebuffers(1, &depth_map_fbo);
    gl.genTextures(1, &depth_map_texture);

    gl.bindTexture(gl.TEXTURE_2D, depth_map_texture);

    gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.dEPTH_COMPONENT,
        SHADOW_WIDTH,
        SHADOW_HEIGHT,
        0,
        gl.dEPTH_COMPONENT,
        gl.fLOAT,
        null
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER); // gl.REPEAT in book
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER); // gl.REPEAT in book

    gl.texParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, border_color.as_ptr()); // ?

    gl.bindFramebuffer(gl.fRAMEBUFFER, depth_map_fbo);
    gl.framebufferTexture2D(gl.fRAMEBUFFER, gl.dEPTH_ATTACHMENT, gl.TEXTURE_2D, depth_map_texture, 0);

    gl.drawBuffer(gl.NONE); // specifies no color data
    gl.readBuffer(gl.NONE); // specifies no color data
    gl.bindFramebuffer(gl.fRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = depth_map_fbo,
        .texture_id = depth_map_texture,
    };
}

pub fn create_emission_fbo(viewport_width: i32, viewport_height: i32) FrameBuffer {
    var emission_fbo: gl.Uint = 0;
    var emission_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &emission_fbo);
        gl.genTextures(1, &emission_texture);

        gl.bindFramebuffer(gl.fRAMEBUFFER, emission_fbo);
        gl.bindTexture(gl.TEXTURE_2D, emission_texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            viewport_width,
            viewport_height,
            0,
            gl.RGB,
            gl.fLOAT,
            null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_BORDER);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_BORDER);
        const border_color2: []f32 = .{0.0, 0.0, 0.0, 0.0};
        gl.texParameterfv(gl.TEXTURE_2D, gl.TEXTURE_BORDER_COLOR, border_color2.as_ptr());
        gl.framebufferTexture2D(gl.fRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, emission_texture, 0);

        var rbo: gl.Uint = 0;
        gl.genRenderbuffers(1, &rbo);
        gl.bindRenderbuffer(gl.RENDERBUFFER, rbo);
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.dEPTH_COMPONENT16, viewport_width, viewport_height);
        gl.framebufferRenderbuffer(gl.fRAMEBUFFER, gl.dEPTH_ATTACHMENT, gl.RENDERBUFFER, rbo);

        gl.bindFramebuffer(gl.fRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = emission_fbo,
        .texture_id = emission_texture,
    };
}

pub fn create_scene_fbo(viewport_width: i32, viewport_height: i32) FrameBuffer {
    var scene_fbo: gl.Uint = 0;
    var scene_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &scene_fbo);
        gl.genTextures(1, &scene_texture);

        gl.bindFramebuffer(gl.fRAMEBUFFER, scene_fbo);
        gl.bindTexture(gl.TEXTURE_2D, scene_texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            viewport_width,
            viewport_height,
            0,
            gl.RGB,
            gl.fLOAT,
            null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.framebufferTexture2D(gl.fRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, scene_texture, 0);

        var rbo: gl.Uint = 0;

        gl.genRenderbuffers(1, &rbo);
        gl.bindRenderbuffer(gl.RENDERBUFFER, rbo);
        gl.renderbufferStorage(gl.RENDERBUFFER, gl.DEPTH24_STENCIL8, viewport_width, viewport_height);
        gl.framebufferRenderbuffer(gl.fRAMEBUFFER, gl.DEPTH_STENCIL_ATTACHMENT, gl.RENDERBUFFER, rbo);

        if (gl.CheckFramebufferStatus(gl.fRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            std.debug.panic("Frame buffer not complete!");
        }

        gl.bindFramebuffer(gl.fRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = scene_fbo,
        .texture_id = scene_texture,
    };
}

pub fn create_horizontal_blur_fbo(viewport_width: i32, viewport_height: i32) FrameBuffer {
    var horizontal_blur_fbo: gl.Uint = 0;
    var horizontal_blur_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &horizontal_blur_fbo);
        gl.genTextures(1, &horizontal_blur_texture);

        gl.bindFramebuffer(gl.fRAMEBUFFER, horizontal_blur_fbo);
        gl.bindTexture(gl.TEXTURE_2D, horizontal_blur_texture);

        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            viewport_width / BLUR_SCALE,
            viewport_height / BLUR_SCALE,
            0,
            gl.RGB,
            gl.fLOAT,
            null,
        );

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);

        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, horizontal_blur_texture, 0);

        if (gl.checkFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            std.debug.panic("Frame buffer not complete!");
        }

        gl.bindFramebuffer(gl.fRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = horizontal_blur_fbo,
        .texture_id = horizontal_blur_texture,
    };
}

pub fn create_vertical_blur_fbo(viewport_width: i32, viewport_height: i32) FrameBuffer {
    var vertical_blur_fbo: gl.Uint = 0;
    var vertical_blur_texture: gl.Uint = 0;

        gl.genFramebuffers(1, &vertical_blur_fbo);
        gl.genTextures(1, &vertical_blur_texture);

        gl.bindFramebuffer(gl.fRAMEBUFFER, vertical_blur_fbo);
        gl.bindTexture(gl.TEXTURE_2D, vertical_blur_texture);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB,
            viewport_width / BLUR_SCALE,
            viewport_height / BLUR_SCALE,
            0,
            gl.RGB,
            gl.fLOAT,
            null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
        gl.framebufferTexture2D(gl.FRAMEBUFFER, gl.COLOR_ATTACHMENT0, gl.TEXTURE_2D, vertical_blur_texture, 0);

        if (gl.CheckFramebufferStatus(gl.FRAMEBUFFER) != gl.FRAMEBUFFER_COMPLETE) {
            std.debug.panic("Frame buffer not complete!");
        }

        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

    return FrameBuffer {
        .framebuffer_id = vertical_blur_fbo,
        .texture_id = vertical_blur_texture,
    };
}
