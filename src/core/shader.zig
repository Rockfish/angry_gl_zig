const std = @import("std");
const gl = @import("zopengl").bindings;
const zm = @import("zmath");
const math = @import("math.zig");

const Matrix = math.Matrix;

const Allocator = std.mem.Allocator;

pub const Shader = struct {
    id: u32,
    vert_file: []const u8,
    frag_file: []const u8,
    geom_file: ?[]const u8,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.vert_file);
        self.allocator.free(self.frag_file);
        if (self.geom_file != null) {
            self.allocator.free(self.geom_file.?);
        }
        gl.deleteShader(self.id);
        self.allocator.destroy(self);
    }

    pub fn new(allocator: Allocator, vert_file_path: []const u8, frag_file_path: []const u8) !*Shader {
        return new_with_geom(allocator, vert_file_path, frag_file_path, null);
    }

    pub fn new_with_geom(allocator: Allocator, vert_file_path: []const u8, frag_file_path: []const u8, optional_geom_file: ?[]const u8) !*Shader {

        const vert_file = try std.fs.cwd().openFile(vert_file_path, .{});
        defer vert_file.close();
        const vert_code = try vert_file.reader().readAllAlloc(allocator, 256 * 1024);
        defer allocator.free(vert_code);

        const frag_file = try std.fs.cwd().openFile(frag_file_path, .{});
        defer frag_file.close();
        const frag_code = try frag_file.reader().readAllAlloc(allocator, 256 * 1024);
        defer allocator.free(frag_code);

        var geom_code: ?[]u8 = null;
        if (optional_geom_file) |geom_file_path| {
            const geom_file = try std.fs.cwd().openFile(geom_file_path, .{});
            defer geom_file.close();
            geom_code = try geom_file.reader().readAllAlloc(allocator, 256 * 1024);
            defer allocator.free(geom_code.?);
        }

        const vertex_shader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertex_shader, 1, &vert_code.ptr, 0);
        gl.compileShader(vertex_shader);
        // check_for_compile_errors(vertex_shader, "VERTEX");

        const frag_shader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(frag_shader, 1, &frag_code.ptr, 0);
        gl.compileShader(frag_shader);
        // check_for_compile_errors(vertex_shader, "VERTEX");

        var geom_shader: ?u32 = null;
        if (geom_code != null) {
            geom_shader = gl.createShader(gl.GEOMETRY_SHADER);
            gl.shaderSource(geom_shader.?, 1, &geom_code.?.ptr, 0);
            gl.compileShader(geom_shader.?);
            // check_for_compile_errors(vertex_shader, "VERTEX");
        }

        const shader_id = gl.createProgram();
        // link the first program object
        gl.attachShader(shader_id, vertex_shader);
        gl.attachShader(shader_id, frag_shader);
        if (geom_shader != null) {
            gl.attachShader(shader_id, geom_shader.?);
        }
        gl.linkProgram(shader_id);

        // check_compile_errors(shader.id, "PROGRAM")?;

        // delete the shaders as they're linked into our program now and no longer necessary
        gl.deleteShader(vertex_shader);
        gl.deleteShader(frag_shader);
        if (geom_code != null) {
            gl.deleteShader(geom_shader.?);
        }

        const geom_file = if (optional_geom_file != null) blk: {
            break :blk try allocator.dupe(u8, optional_geom_file.?);
        } else null;

        const shader = try allocator.create(Shader);
        shader.* = Shader {
            .id = shader_id,
            .vert_file = try allocator.dupe(u8, vert_file_path),
            .frag_file = try allocator.dupe(u8, frag_file_path),
            .geom_file = geom_file,
            .allocator = allocator
        };

        return shader;
    }

    pub fn use_shader(self: *Shader) void {
        gl.useProgram(self.id);
    }

    pub fn use_shader_with(self: *Shader, projection: *zm.Mat4, view: *zm.Mat4) void {
        gl.useProgram(self.id);
        self.set_mat4("projection", projection);
        self.set_mat4("view", view);
    }

    pub fn get_uniform_location(self: *Shader, uniform: [:0]const u8) gl.Int {
        return gl.getUniformLocation(self.id, uniform);
    }

    // utility uniform functions
    // ------------------------------------------------------------------------
    pub fn set_bool(self: *const Shader, uniform: [:0]const u8, value: bool) void {
        var v: u8 = 0;
        if (value) { v = 1;}
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform1i(location, v);
    }

    // ------------------------------------------------------------------------
    pub fn set_int(self: *const Shader, uniform: [:0]const u8, value: i32) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform1i(location, value);
    }

    // ------------------------------------------------------------------------
    pub fn set_float(self: *const Shader, uniform: [:0]const u8, value: f32) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform1f(location, value);
    }

    // ------------------------------------------------------------------------
    pub fn set_vec2(self: *const Shader, uniform: [:0]const u8, value: *const zm.Vec2) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform2fv(location, 1, &value);
    }

    // ------------------------------------------------------------------------
    pub fn set_vec2_xy(self: *const Shader, uniform: [:0]const u8, x: f32, y: f32) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform2f(location, x, y);
    }

    // ------------------------------------------------------------------------
    pub fn set_vec3(self: *const Shader, uniform: [:0]const u8, value: *const zm.Vec3) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform3fv(location, 1, @as(*const [3]f32, @ptrCast(value))); //zm.arr3Ptr(value));
    }

    // ------------------------------------------------------------------------
    pub fn set_vec3_xyz(self: *const Shader, uniform: [:0]const u8, x: f32, y: f32, z: f32) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform3f(location, x, y, z);
    }

    // ------------------------------------------------------------------------
    pub fn set_vec4(self: *const Shader, uniform: [:0]const u8, value: *const zm.Vec4) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform4fv(location, 1, zm.arrNPtr(value));
    }

    // ------------------------------------------------------------------------
    pub fn set_vec4_xyzw(self: *const Shader, uniform: [:0]const u8, x: f32, y: f32, z: f32, w: f32) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniform4f(location, x, y, z, w);
    }

    // ------------------------------------------------------------------------
    pub fn set_mat2(self: *const Shader, uniform: [:0]const u8, mat: *const zm.Mat2) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniformMatrix2fv(location, 1, gl.FALSE, &mat);
    }

    // ------------------------------------------------------------------------
    pub fn set_mat3(self: *const Shader, uniform: [:0]const u8, mat: *const zm.Mat3) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniformMatrix3fv(location, 1, gl.FALSE, &mat);
    }

    // ------------------------------------------------------------------------
    pub fn set_mat4(self: *const Shader, uniform: [:0]const u8, mat4: *const zm.Mat4) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniformMatrix4fv(location, 1, gl.FALSE, zm.arrNPtr(mat4));
    }

    // ------------------------------------------------------------------------
    pub fn set_matrix(self: *const Shader, uniform: [:0]const u8, matrix: *const Matrix) void {
        const location = gl.getUniformLocation(self.id, uniform);
        gl.uniformMatrix4fv(location, 1, gl.FALSE, matrix.asPtr());
    }

    // ------------------------------------------------------------------------
    pub fn set_texture_unit(self: *const Shader, texture_unit: u32, texture_id: u32) void {
        _ = self;
        gl.activeTexture(gl.TEXTURE0 + texture_unit);
        gl.bindTexture(gl.TEXTURE_2D, texture_id);
    }
};
