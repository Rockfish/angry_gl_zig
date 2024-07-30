const std = @import("std");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");

const Allocator = std.mem.Allocator;
const Shader = core.Shader;
const Mat4 = math.Mat4;
// const Texture = core.texture.Texture;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);
const INVALID_UNIFORM_LOCATION = 0xffffffff;

pub const PickingTechnique = struct {
    pv_location: c_int,
    model_location: c_int,
    draw_index_location: c_int,
    object_index_location: c_int,
    shader: *Shader,

    const Self = @This();

    pub fn deinit(self: *const Self) void {
        self.shader.deinit();
    }

    pub fn init(allocator: Allocator) !Self {
        const shader = try Shader.new(
            allocator,
            "examples/picker/picking.vert",
            "examples/picker/picking.frag",
        );
        shader.use_shader();

        //const pv_location = shader.get_uniform_location("gWVP");
        const pv_location = shader.get_uniform_location("projectionView");
        const model_location = shader.get_uniform_location("model_transform");

        const draw_index_location = shader.get_uniform_location("gObjectIndex");
        const object_index_location = shader.get_uniform_location("gDrawIndex");

        if (pv_location == INVALID_UNIFORM_LOCATION or
            draw_index_location == INVALID_UNIFORM_LOCATION or
            object_index_location == INVALID_UNIFORM_LOCATION)
        {
            std.debug.panic("get_uniform_location error", .{});
        }

        return .{
            .pv_location = pv_location,
            .model_location = model_location,
            .draw_index_location = draw_index_location,
            .object_index_location = object_index_location,
            .shader = shader,
        };
    }

    pub fn enable(self: *Self) void {
        self.shader.use_shader();
    }

    pub fn setProjectionView(self: *Self, projection: *const Mat4, view: *const Mat4) void {
        const pv = projection.mulMat4(view);
        gl.uniformMatrix4fv(self.pv_location, 1, gl.FALSE, pv.toArrayPtr());
    }

    pub fn setModel(self: *Self, model_transform: *const Mat4) void {
        gl.uniformMatrix4fv(self.model_location, 1, gl.FALSE, model_transform.toArrayPtr());
    }

    pub fn setProjectionViewModel(self: *Self, pv: *const Mat4) void {
        // const pvm = projection.mulMat4(view).mulMat4(model_transform);
        gl.uniformMatrix4fv(self.pv_location, 1, gl.FALSE, pv.toArrayPtr());
    }

    // ah, call back
    // no wonder this was confusing, Mesh is actually Meshes, and the drawIndex is the mesh number.
    pub fn setDrawIndex(self: *Self, draw_index: u32) void {
        gl.uniform1ui(self.draw_index_location, draw_index);
    }

    pub fn setObjectIndex(self: *Self, object_index: u32) void {
        gl.uniform1ui(self.object_index_location, object_index);
    }
};