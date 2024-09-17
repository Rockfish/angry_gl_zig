const std = @import("std");
const gl = @import("zopengl").bindings;
const math = @import("math");
const Texture = @import("texture.zig").Texture;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat3 = math.Mat3;
const Mat4 = math.Mat4;

const Allocator = std.mem.Allocator;
const StringHashMap = std.StringHashMap;

const ShaderError = error{
    CompileError,
    LinkError,
};

pub const Shader = struct {
    id: u32,
    vert_file: []const u8,
    frag_file: []const u8,
    geom_file: ?[]const u8,
    locations: *StringHashMap(c_int),
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.vert_file);
        self.allocator.free(self.frag_file);
        if (self.geom_file != null) {
            self.allocator.free(self.geom_file.?);
        }
        gl.deleteShader(self.id);
        var iterator = self.locations.keyIterator();
        while (iterator.next()) |key| {
            self.allocator.free(key.*);
        }
        self.locations.deinit();
        self.allocator.destroy(self.locations);
        self.allocator.destroy(self);
    }

    pub fn new(allocator: Allocator, vert_file_path: []const u8, frag_file_path: []const u8) !*Shader {
        return new_with_geom(allocator, vert_file_path, frag_file_path, null);
    }

    pub fn new_with_geom(allocator: Allocator, vert_file_path: []const u8, frag_file_path: []const u8, optional_geom_file: ?[]const u8) !*Shader {
        const vert_file = std.fs.cwd().openFile(vert_file_path, .{}) catch |err| {
            std.debug.panic("Shader error: {any} file: {s}", .{ err, vert_file_path });
        };

        const vert_code = try vert_file.readToEndAlloc(allocator, 256 * 1024);
        const c_vert_code: [:0]const u8 = try allocator.dupeZ(u8, vert_code);

        defer vert_file.close();
        defer allocator.free(vert_code);
        defer allocator.free(c_vert_code);

        // std.debug.print("vert_code: {s}\n", .{c_vert_code});

        const vertex_shader = gl.createShader(gl.VERTEX_SHADER);
        gl.shaderSource(vertex_shader, 1, &[_][*c]const u8{c_vert_code.ptr}, 0);
        gl.compileShader(vertex_shader);

        check_compile_errors(vertex_shader, "VERTEX");

        const frag_file = try std.fs.cwd().openFile(frag_file_path, .{});
        const frag_code = try frag_file.readToEndAlloc(allocator, 256 * 1024);
        const c_frag_code: [:0]const u8 = try allocator.dupeZ(u8, frag_code);

        defer frag_file.close();
        defer allocator.free(frag_code);
        defer allocator.free(c_frag_code);

        // std.debug.print("frag_code: {s}\n", .{c_frag_code});

        const frag_shader = gl.createShader(gl.FRAGMENT_SHADER);
        gl.shaderSource(frag_shader, 1, &[_][*c]const u8{c_frag_code.ptr}, 0);
        gl.compileShader(frag_shader);

        check_compile_errors(frag_shader, "FRAGMENT");

        var geom_shader: ?c_uint = null;
        if (optional_geom_file) |geom_file_path| {
            const geom_file = try std.fs.cwd().openFile(geom_file_path, .{});
            const geom_code = try geom_file.readToEndAlloc(allocator, 256 * 1024);
            const c_geom_code: [:0]const u8 = try allocator.dupeZ(u8, frag_code);

            defer geom_file.close();
            defer allocator.free(geom_code);
            defer allocator.free(c_geom_code);

            geom_shader = gl.createShader(gl.GEOMETRY_SHADER);
            gl.shaderSource(geom_shader.?, 1, &[_][*c]const u8{c_geom_code.ptr}, 0);
            gl.compileShader(geom_shader.?);

            check_compile_errors(geom_shader.?, "GEOM");
        }

        const shader_id = gl.createProgram();
        // link the first program object
        gl.attachShader(shader_id, vertex_shader);
        gl.attachShader(shader_id, frag_shader);
        if (geom_shader != null) {
            gl.attachShader(shader_id, geom_shader.?);
        }
        gl.linkProgram(shader_id);

        check_compile_errors(shader_id, "PROGRAM");

        // delete the shaders as they're linked into our program now and no longer necessary
        gl.deleteShader(vertex_shader);
        gl.deleteShader(frag_shader);
        if (geom_shader != null) {
            gl.deleteShader(geom_shader.?);
        }

        const geom_file = if (optional_geom_file != null) blk: {
            break :blk try allocator.dupe(u8, optional_geom_file.?);
        } else null;

        const shader = try allocator.create(Shader);

        const locations = try allocator.create(StringHashMap(c_int));
        locations.* = StringHashMap(c_int).init(allocator);

        shader.* = Shader{
            .id = shader_id,
            .vert_file = try allocator.dupe(u8, vert_file_path),
            .frag_file = try allocator.dupe(u8, frag_file_path),
            .geom_file = geom_file,
            .locations = locations,
            .allocator = allocator,
        };

        return shader;
    }

    pub fn use_shader(self: *const Shader) void {
        gl.useProgram(self.id);
    }

    pub fn use_shader_with(self: *const Shader, projection: *Mat4, view: *Mat4) void {
        gl.useProgram(self.id);
        self.set_mat4("projection", projection);
        self.set_mat4("view", view);
    }

    pub fn get_uniform_location(self: *const Shader, uniform: [:0]const u8) c_int {
        const result = self.locations.get(uniform);

        if (result != null) {
            return result.?;
        }

        const key = self.allocator.dupe(u8, uniform) catch unreachable;
        const val = gl.getUniformLocation(self.id, uniform);
        self.locations.put(key, val) catch unreachable;
        //std.debug.print("Shader: {s} saving location: {s} value: {d}\n", .{ self.vert_file, key, val });
        return val;
    }

    // utility uniform functions
    // ------------------------------------------------------------------------
    pub fn set_bool(self: *const Shader, uniform: [:0]const u8, value: bool) void {
        const v: u8 = if (value) 1 else 0;
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform1i(location, v);
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_int(self: *const Shader, uniform: [:0]const u8, value: i32) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform1i(location, value);
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_uint(self: *const Shader, uniform: [:0]const u8, value: u32) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform1ui(location, value);
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_float(self: *const Shader, uniform: [:0]const u8, value: f32) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform1f(location, value);
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_vec2(self: *const Shader, uniform: [:0]const u8, value: *const Vec2) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform2fv(location, 1, value.asArrayPtr());
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_vec2_xy(self: *const Shader, uniform: [:0]const u8, x: f32, y: f32) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform2f(location, x, y);
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_vec3(self: *const Shader, uniform: [:0]const u8, value: *const Vec3) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform3fv(location, 1, value.asArrayPtr());
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_vec3_xyz(self: *const Shader, uniform: [:0]const u8, x: f32, y: f32, z: f32) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform3f(location, x, y, z);
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_vec4(self: *const Shader, uniform: [:0]const u8, value: *const Vec4) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform4fv(location, 1, value.asArrayPtr());
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_vec4_xyzw(self: *const Shader, uniform: [:0]const u8, x: f32, y: f32, z: f32, w: f32) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniform4f(location, x, y, z, w);
        }
    }

    // ------------------------------------------------------------------------
    // pub fn set_mat2(self: *const Shader, uniform: [:0]const u8, mat: *const Mat2) void {
    //     const location = gl.getUniformLocation(self.id, uniform);
    //     gl.uniformMatrix2fv(location, 1, gl.FALSE, &mat);
    // }

    // ------------------------------------------------------------------------
    pub fn set_mat3(self: *const Shader, uniform: [:0]const u8, mat: *const Mat3) void {
        const location = gl.getUniformLocation(self.id, uniform);
        if (location != -1) {
            gl.uniformMatrix3fv(location, 1, gl.FALSE, &mat);
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_mat4(self: *const Shader, uniform: [:0]const u8, mat: *const Mat4) void {
        const location = self.get_uniform_location(uniform);
        if (location != -1) {
            gl.uniformMatrix4fv(location, 1, gl.FALSE, mat.toArrayPtr());
        }
    }

    // ------------------------------------------------------------------------
    pub fn set_texture_unit(self: *const Shader, texture_unit: u32, texture_id: u32) void {
        _ = self;
        gl.activeTexture(gl.TEXTURE0 + texture_unit);
        gl.bindTexture(gl.TEXTURE_2D, texture_id);
    }

    pub fn bind_texture(self: *const Shader, texture_unit: i32, uniform_name: [:0]const u8, texture: *const Texture) void {
        gl.activeTexture(gl.TEXTURE0 + @as(c_uint, @intCast(texture_unit)));
        gl.bindTexture(gl.TEXTURE_2D, texture.id);
        self.set_int(uniform_name, texture_unit);
    }
};

fn check_compile_errors(id: u32, check_type: []const u8) void {
    var infoLog: [2024]u8 = undefined;
    var successful: c_int = undefined;

    if (!std.mem.eql(u8, check_type, "PROGRAM")) {
        gl.getShaderiv(id, gl.COMPILE_STATUS, &successful);
        if (successful != gl.TRUE) {
            var len: c_int = 0;
            gl.getShaderiv(id, gl.INFO_LOG_LENGTH, &len);
            gl.getShaderInfoLog(id, 2024, null, &infoLog);
            std.debug.panic("shader compile error: {s}", .{infoLog[0..@intCast(len)]});
        }
    } else {
        gl.getProgramiv(id, gl.LINK_STATUS, &successful);
        if (successful != gl.TRUE) {
            var len: c_int = 0;
            gl.getProgramiv(id, gl.INFO_LOG_LENGTH, &len);
            gl.getProgramInfoLog(id, 2024, null, &infoLog);
            std.debug.panic("shader link error: {s}", .{infoLog[0..@intCast(len)]});
        }
    }
}
