const std = @import("std");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");

const Allocator = std.mem.Allocator;
const Shader = core.Shader;
const Mat4 = math.Mat4;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

const INVALID_UNIFORM_LOCATION = 0xffffffff;

pub const PixelInfo = struct {
    object_id: f32 = 0.0,
    draw_id: f32 = 0.0,
    primative_id: f32 = 0.0,
};

pub const Picker = struct {
    fbo: u32 = 0,
    picking_texture_id: u32 = 0,
    depth_texture_id: u32 = 0,
    pv_location: c_int,
    model_location: c_int,
    mesh_id_location: c_int,
    object_id_location: c_int,
    shader: *Shader,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        gl.deleteFramebuffers(1, &self.fbo);
        gl.deleteTextures(1, &self.picking_texture_id);
        gl.deleteTextures(1, &self.depth_texture_id);
        self.shader.deinit();
    }

    pub fn init(allocator: Allocator, width: u32, height: u32) !Self { // Create the FBO
        const shader = try Shader.new(
            allocator,
            "examples/picker/picking.vert",
            "examples/picker/picking.frag",
        );
        shader.use_shader();

        const pv_location = shader.get_uniform_location("projection_view");
        const model_location = shader.get_uniform_location("model_transform");

        const mesh_id_location = shader.get_uniform_location("object_id");
        const object_id_location = shader.get_uniform_location("mesh_id");

        if (pv_location == INVALID_UNIFORM_LOCATION or
            mesh_id_location == INVALID_UNIFORM_LOCATION or
            object_id_location == INVALID_UNIFORM_LOCATION)
        {
            std.debug.panic("get_uniform_location error", .{});
        }

        var picker = Picker{
            .pv_location = pv_location,
            .model_location = model_location,
            .mesh_id_location = mesh_id_location,
            .object_id_location = object_id_location,
            .shader = shader,
        };

        picker.create_framebuffer(width, height);

        return picker;
    }

    pub fn create_framebuffer(self: *Self, width: u32, height: u32) void {
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
            @intCast(width),
            @intCast(height),
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
            @intCast(width),
            @intCast(height),
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

        self.fbo = fbo;
        self.picking_texture_id = picking_texture_id;
        self.depth_texture_id = depth_texture_id;
    }

    pub fn enable(self: *const Self) void {
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, self.fbo);
        self.shader.use_shader();
        gl.clearColor(0.0, 0.0, 0.0, 0.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);
    }

    pub fn disable(self: *const Self) void {
        _ = self;
        gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);
    }

    pub fn set_projection_view(self: *const Self, projection: *const Mat4, view: *const Mat4) void {
        const pv = projection.mulMat4(view);
        gl.uniformMatrix4fv(self.pv_location, 1, gl.FALSE, pv.toArrayPtr());
    }

    pub fn set_model_transform(self: *const Self, model_transform: *const Mat4) void {
        gl.uniformMatrix4fv(self.model_location, 1, gl.FALSE, model_transform.toArrayPtr());
    }

    pub fn set_projection_view_model(self: *const Self, pv: *const Mat4) void {
        // const pvm = projection.mulMat4(view).mulMat4(model_transform);
        gl.uniformMatrix4fv(self.pv_location, 1, gl.FALSE, pv.toArrayPtr());
    }

    pub fn set_mesh_id(self: *const Self, mesh_id: u32) void {
        gl.uniform1ui(self.mesh_id_location, mesh_id);
    }

    pub fn set_object_id(self: *const Self, object_index: u32) void {
        gl.uniform1ui(self.object_id_location, object_index);
    }

    pub fn read_pixel_info(self: *const Self, x: i32, y: i32) PixelInfo {
        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self.fbo);
        gl.readBuffer(gl.COLOR_ATTACHMENT0);

        var pixel: PixelInfo = undefined;

        gl.readPixels(x, y, 1, 1, gl.RGB, gl.FLOAT, &pixel);
        gl.readBuffer(gl.NONE);

        gl.bindFramebuffer(gl.READ_FRAMEBUFFER, 0);

        return pixel;
    }
};
