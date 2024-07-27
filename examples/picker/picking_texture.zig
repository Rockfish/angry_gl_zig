const std = @import("std");
const gl = @import("zopengl").bindings;
const core = @import("core");

// const Shader = core.Shader;
// const Texture = core.texture.Texture;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

pub const PixelInfo = struct {
    object_id: f32 = 0.0,
    draw_id: f32 = 0.0,
    primative_id: f32 = 0.0,
};

pub const PickingTexture = struct {
    fbo: u32,
    picking_texture_id: u32,
    depth_texture_id: u32,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        gl.deleteFramebuffers(1, &self.fbo);
        gl.deleteTextures(1, &self.picking_texture_id);
        gl.deleteTextures(1, &self.depth_texture_id);
    }

    pub fn init(width: u32, height: u32) Self { // Create the FBO
        var fbo: u32 = undefined;
        var picking_texture_id: u32 = undefined;
        var depth_texture_id: u32 = undefined;

        gl.genFramebuffers(1, &fbo);
        gl.bindFramebuffer(gl.FRAMEBUFFER, fbo);

        // Create the texture object for the primitive information buffer
        gl.genTextures(1, &picking_texture_id);
        gl.bindTexture(gl.TEXTURE_2D, picking_texture_id);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.RGB32F,
            width,
            height,
            0,
            gl.RGB,
            gl.FLOAT,
            null,
        );
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.framebufferTexture2D(
            gl.FRAMEBUFFER,
            gl.COLOR_ATTACHMENT0,
            gl.TEXTURE_2D,
            picking_texture_id,
            0,
        );

        // Create the texture object for the depth buffer
        gl.genTextures(1, &depth_texture_id);
        gl.bindTexture(gl.TEXTURE_2D, depth_texture_id);
        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            gl.DEPTH_COMPONENT,
            width,
            height,
            0,
            gl.DEPTH_COMPONENT,
            gl.FLOAT,
            null,
        );
        gl.framebufferTexture2D(
            gl.FRAMEBUFFER,
            gl.DEPTH_ATTACHMENT,
            gl.TEXTURE_2D,
            depth_texture_id,
            0,
        );

        gl.readBuffer(gl.NONE);
        gl.drawBuffer(gl.COLOR_ATTACHMENT0);

        // Verify that the FBO is correct
        const status = gl.checkFramebufferStatus(gl.FRAMEBUFFER);

        if (status != gl.FRAMEBUFFER_COMPLETE) {
            std.debug.panic("FB error, status: 0x{x}\n", .{status});
        }

        // Restore the default framebuffer
        gl.bindTexture(gl.TEXTURE_2D, 0);
        gl.bindFramebuffer(gl.FRAMEBUFFER, 0);

        // return GLCheckError();
        return .{
            .fbo = fbo,
            .picking_texture_id = picking_texture_id,
            .depth_texture_id = depth_texture_id,
        };
    }
    pub fn enableWriting(self: *Self) void {
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, self.fbo);
    }

    pub fn disableWriting(self: *Self) void {
        _ = self;
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);
    }

    pub fn readPixel(self: *Self, x: u32, y: u32) PixelInfo {
        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self.fbo);
        gl.readBuffer(gl.COLOR_ATTACHMENT0);

        var pixel: PixelInfo = undefined;

        gl.readPixels(x, y, 1, 1, gl.RGB, gl.FLOAT, &pixel);
        gl.rReadBuffer(gl.NONE);

        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, 0);

        return pixel;
    }
};
