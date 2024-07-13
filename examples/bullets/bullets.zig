const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const zstbi = @import("core").zstbi;
const core = @import("core");
const math = @import("math");

const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

const Allocator = std.mem.Allocator;

const Shader = core.Shader;
const Texture = core.texture.Texture;
const TextureType = core.texture.TextureType;
const TextureConfig = core.texture.TextureConfig;
const TextureFilter = core.texture.TextureFilter;
const TextureWrap = core.texture.TextureWrap;

const SCR_WIDTH: f32 = 1000.0;
const SCR_HEIGHT: f32 = 1000.0;

const SIZE_OF_I32 = @sizeOf(i32);
const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);
const SIZE_OF_VEC3 = @sizeOf(Vec3);
const SIZE_OF_VEC4 = @sizeOf(Vec4);
const SIZE_OF_QUAT = @sizeOf(Quat);

// const BULLET_SCALE: f32 = 0.3;
const BULLET_SCALE: f32 = 2.0; //0.3;
const BULLET_LIFETIME: f32 = 1.0;
// seconds
const BULLET_SPEED: f32 = 15.0;
// const BULLET_SPEED: f32 = 1.0;
// Game units per second
const ROTATION_PER_BULLET: f32 = 3.0 * math.pi / 180.0;

const SCALE_VEC: Vec3 = vec3(BULLET_SCALE, BULLET_SCALE, BULLET_SCALE);
const BULLET_NORMAL: Vec3 = vec3(0.0, 1.0, 0.0);
const CANONICAL_DIR: Vec3 = vec3(0.0, 0.0, 1.0);

// Trim off margin around the bullet image
// const TEXTURE_MARGIN: f32 = 0.0625;
// const TEXTURE_MARGIN: f32 = 0.2;
const TEXTURE_MARGIN: f32 = 0.1;

const BULLET_VERTICES_H: [20]f32 = .{
    // Positions                                        // Tex Coords
    BULLET_SCALE * (-0.243), 0.0, BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * (-0.243), 0.0, BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0, BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0, BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
};

// vertical surface to see the bullets from the side

const BULLET_VERTICES_V: [20]f32 = .{
    0.0, BULLET_SCALE * (-0.243), BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0, BULLET_SCALE * (-0.243), BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0, BULLET_SCALE * 0.243,    BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    0.0, BULLET_SCALE * 0.243,    BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
};

const BULLET_VERTICES_H_V: [40]f32 = .{
    // Positions                                                              // Tex Coords
    BULLET_SCALE * (-0.243), 0.0,                     BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * (-0.243), 0.0,                     BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0,                     BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    BULLET_SCALE * 0.243,    0.0,                     BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    0.0,                     BULLET_SCALE * (-0.243), BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0,                     BULLET_SCALE * (-0.243), BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 0.0 + TEXTURE_MARGIN,
    0.0,                     BULLET_SCALE * 0.243,    BULLET_SCALE * 0.0,    0.0 + TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
    0.0,                     BULLET_SCALE * 0.243,    BULLET_SCALE * (-1.0), 1.0 - TEXTURE_MARGIN, 1.0 - TEXTURE_MARGIN,
};

const BULLET_INDICES: [6]i32 = .{ 0, 1, 2, 0, 2, 3 };

const BULLET_INDICES_H_V: [12]u32 = .{
    0, 1, 2,
    0, 2, 3,
    4, 5, 6,
    4, 6, 7,
};

const test_vertices: [20]f32 = .{
    // positions       // texture coordinates
    0.5, 0.5, 0.0, 1.0, 1.0, // top right
    0.5, -0.5, 0.0, 1.0, 0.0, // bottom right
    -0.5, -0.5, 0.0, 0.0, 0.0, // bottom left
    -0.5, 0.5, 0.0, 0.0, 1.0, // top left
};

const test_indices: [6]u32 = .{
    0, 1, 3, // first triangle
    1, 2, 3, // second triangle
};

// const vertices = BULLET_VERTICES_H_V;
// const indices = BULLET_INDICES_H_V;
const vertices = test_vertices;
const indices = test_indices;

pub const Bullets = struct {
    bullet_vao: gl.Uint,
    rotation_vbo: gl.Uint,
    position_vbo: gl.Uint,
    unit_square_vao: c_uint,
    bullet_texture: *Texture,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.bullet_texture.deinit();
    }

    pub fn new(allocator: Allocator) !Self {
        const texture_config = TextureConfig{
            .flip_v = false,
            // .flip_h = true,
            .gamma_correction = false,
            .filter = TextureFilter.Nearest,
            .texture_type = TextureType.None,
            .wrap = TextureWrap.Repeat,
        };

        const bullet_texture = try Texture.new(
            allocator,
            // "angrygl_assets/bullet/bullet_texture_transparent.png",
            "assets/bullet/red_and_green_bullet_transparent.png",
            texture_config,
        );

        var bullets: Bullets = .{
            .bullet_vao = undefined,
            .rotation_vbo = undefined,
            .position_vbo = undefined,
            .unit_square_vao = undefined,
            .bullet_texture = bullet_texture,
        };

        bullets.create_shader_buffers();

        return bullets;
    }

    fn create_shader_buffers(self: *Self) void {
        var bullet_vao: gl.Uint = 0;
        var bullet_vertices_vbo: gl.Uint = 0;
        var bullet_indices_ebo: gl.Uint = 0;
        var rotation_vbo: gl.Uint = 0;
        var position_vbo: gl.Uint = 0;

        gl.genVertexArrays(1, &bullet_vao);
        gl.genBuffers(1, &bullet_vertices_vbo);
        gl.genBuffers(1, &bullet_indices_ebo);

        gl.bindVertexArray(bullet_vao);

        // vertices data
        gl.bindBuffer(gl.ARRAY_BUFFER, bullet_vertices_vbo);
        gl.bufferData(
            gl.ARRAY_BUFFER,
            @as(isize, @intCast(vertices.len * SIZE_OF_FLOAT)),
            &vertices,
            gl.STATIC_DRAW,
        );

        // indices data
        gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, bullet_indices_ebo);
        gl.bufferData(
            gl.ELEMENT_ARRAY_BUFFER,
            @as(isize, @intCast(indices.len * SIZE_OF_U32)),
            &indices,
            gl.STATIC_DRAW,
        );

        // vertex positions
        gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 5,
            null,
        );
        gl.enableVertexAttribArray(0);

        // location 1: texture coordinates
        gl.vertexAttribPointer(
            1,
            2,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_FLOAT * 5,
            // @ptrFromInt(3 * SIZE_OF_FLOAT),
            @ptrFromInt(3 * @sizeOf(f32)),
        );
        gl.enableVertexAttribArray(1);

        // // -------------------------------------------------
        // // Per instance data
        //
        // // per instance rotation vbo
        gl.genBuffers(1, &rotation_vbo);
        gl.bindBuffer(gl.ARRAY_BUFFER, rotation_vbo);

        // location: 2: bullet rotations
        gl.enableVertexAttribArray(2);
        gl.vertexAttribPointer(
            2,
            4,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_QUAT,
            null,
        );
        gl.vertexAttribDivisor(2, 1); // one rotation per bullet instance

        // per instance position offset vbo
        gl.genBuffers(1, &position_vbo);
        gl.bindBuffer(gl.ARRAY_BUFFER, position_vbo);

        // location: 3: bullet position offsets
        gl.enableVertexAttribArray(3);
        gl.vertexAttribPointer(
            3,
            3,
            gl.FLOAT,
            gl.FALSE,
            SIZE_OF_VEC3,
            null,
        );
        gl.vertexAttribDivisor(3, 1); // one offset per bullet instance

        self.bullet_vao = bullet_vao;
        self.rotation_vbo = rotation_vbo;
        self.position_vbo = position_vbo;
    }

    pub fn render(self: *const Self, shader: *const Shader) void {
        shader.use_shader();

        gl.clearColor(0.2, 0.3, 0.3, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT); // | gl.DEPTH_BUFFER_BIT);

        gl.bindTexture(gl.TEXTURE_2D, self.bullet_texture.id);

        gl.bindVertexArray(self.bullet_vao);

        gl.drawElements(
            gl.TRIANGLES,
            @as(c_int, @intCast(indices.len)),
            gl.UNSIGNED_INT,
            null,
        );
    }

    pub fn render_bullet_sprites(self: *Self) void {
        const test_bullet_rotations: [4]Vec4 = .{ vec4(0.4691308, -0.017338134, 0.8829104, 0.009212547), vec4(0.46921122, -0.0057797083, 0.8830617, 0.0030710243), vec4(0.45753372, -0.017457237, 0.8889755, 0.008984809), vec4(0.45761213, -0.005819412, 0.8891279, 0.0029951073) };

        const test_bullet_positions: [4]Vec3 = .{ vec3(-0.37858108, 0.48462552, -0.43320495), vec3(-0.37866658, 0.48068565, -0.43326268), vec3(-0.37633452, 0.48462552, -0.43643945), vec3(-0.37641847, 0.48068565, -0.43649942) };

        gl.bindVertexArray(self.bullet_vao);

        gl.bindBuffer(gl.ARRAY_BUFFER, self.rotation_vbo);

        // gl.bufferData(
        //     gl.ARRAY_BUFFER,
        //     @intCast(self.all_bullet_rotations.items.len * SIZE_OF_QUAT),
        //     self.all_bullet_rotations.items.ptr,
        //     gl.STREAM_DRAW,
        // );

        gl.bufferData(
            gl.ARRAY_BUFFER,
            @intCast(test_bullet_rotations.len * SIZE_OF_VEC4),
            &test_bullet_rotations,
            gl.STREAM_DRAW,
        );

        gl.bindBuffer(gl.ARRAY_BUFFER, self.position_vbo);

        // gl.bufferData(
        //     gl.ARRAY_BUFFER,
        //     @intCast(self.all_bullet_positions.items.len * SIZE_OF_VEC3),
        //     self.all_bullet_positions.items.ptr,
        //     gl.STREAM_DRAW,
        // );

        gl.bufferData(
            gl.ARRAY_BUFFER,
            @intCast(test_bullet_positions.len * SIZE_OF_VEC3),
            &test_bullet_positions,
            gl.STREAM_DRAW,
        );

        gl.drawElementsInstanced(
            gl.TRIANGLES,
            12, // 6,
            gl.UNSIGNED_INT,
            null,
            @intCast(self.all_bullet_positions.items.len),
        );

        std.debug.print("self.all_bullet_rotations = {any}\nself.all_bullet_positions = {any}\n", .{ self.all_bullet_rotations.items, self.all_bullet_positions.items });
        std.debug.print("\n", .{});
    }
};
