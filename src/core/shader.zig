const gl = @import("zopengl").bindings;
const zm = @import("zmath");

pub const Shader = struct {
    id: u32,
    vert_file: []const u8,
    frag_file: []const u8,
    geom_file: ?[]const u8,
    // allocator: std.mem.Allocator,

    // pub fn new(vert_file: []const u8, frag_file: []const u8) !*Shader {}

    // pub fn new_with_geom(tor: std.mem.Allocator, vert_file: []const u8, frag_file: []const u8, geom_file: ?[]const u8) !*Shader {}

    pub fn use_shader(self: *Shader) void {
        gl.UseProgram(self.id);
    }

    pub fn use_shader_with(self: *Shader, projection: *zm.Mat4, view: *zm.Mat4) void {
        gl.UseProgram(self.id);
        self.set_mat4("projection", projection);
        self.set_mat4("view", view);
    }

    pub fn get_uniform_location(self: *Shader, uniform: [:0]const u8) gl.Int {
        return gl.GetUniformLocation(self.id, uniform);
    }

    // utility uniform functions
    // ------------------------------------------------------------------------
    pub fn set_bool(self: *Shader, uniform: [:0]const u8, value: bool) void {
        const v = if (value) 1 else 0;
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform1i(location, v);
    }

    // ------------------------------------------------------------------------
    pub fn set_int(self: *Shader, uniform: [:0]const u8, value: i32) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform1i(location, value);
    }

    // ------------------------------------------------------------------------
    pub fn set_float(self: *Shader, uniform: [:0]const u8, value: f32) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform1f(location, value);
    }

    // ------------------------------------------------------------------------
    pub fn set_vec2(self: *Shader, uniform: [:0]const u8, value: *zm.Vec2) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform2fv(location, 1, value.to_array().as_ptr());
    }

    // ------------------------------------------------------------------------
    pub fn set_vec2_xy(self: *Shader, uniform: [:0]const u8, x: f32, y: f32) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform2f(location, x, y);
    }

    // ------------------------------------------------------------------------
    pub fn set_vec3(self: *Shader, uniform: [:0]const u8, value: *zm.Vec3) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform3fv(location, 1, value.to_array().as_ptr());
    }

    // ------------------------------------------------------------------------
    pub fn set_vec3_xyz(self: *Shader, uniform: [:0]const u8, x: f32, y: f32, z: f32) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform3f(location, x, y, z);
    }

    // ------------------------------------------------------------------------
    pub fn set_vec4(self: *Shader, uniform: [:0]const u8, value: *zm.Vec4) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform4fv(location, 1, value.to_array().as_ptr());
    }

    // ------------------------------------------------------------------------
    pub fn set_vec4_xyzw(self: *Shader, uniform: [:0]const u8, x: f32, y: f32, z: f32, w: f32) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.Uniform4f(location, x, y, z, w);
    }

    // ------------------------------------------------------------------------
    pub fn set_mat2(self: *Shader, uniform: [:0]const u8, mat: *zm.Mat2) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.UniformMatrix2fv(location, 1, gl.FALSE, mat.to_cols_array().as_ptr());
    }

    // ------------------------------------------------------------------------
    pub fn set_mat3(self: *Shader, uniform: [:0]const u8, mat: *zm.Mat3) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.UniformMatrix3fv(location, 1, gl.FALSE, mat.to_cols_array().as_ptr());
    }

    // ------------------------------------------------------------------------
    pub fn set_mat4(self: *Shader, uniform: [:0]const u8, matrix: *zm.Mat4) void {
        const location = gl.GetUniformLocation(self.id, uniform);
        gl.UniformMatrix4fv(location, 1, gl.FALSE, matrix.to_cols_array().as_ptr());
    }

    // ------------------------------------------------------------------------
    pub fn set_texture_unit(self: *Shader, texture_unit: u32, texture_id: u32) void {
        _ = self;
        gl.ActiveTexture(gl.TEXTURE0 + texture_unit);
        gl.BindTexture(gl.TEXTURE_2D, texture_id);
    }
};
