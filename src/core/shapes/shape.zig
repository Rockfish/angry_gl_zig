const std = @import("std");
const gl = @import("zopengl").bindings;
const math = @import("math");

const Allocator = std.mem.Allocator;
const ModelVertex = @import("../model_mesh.zig").ModelVertex;

const AABB = @import("../aabb.zig").AABB;

const Vec2 = math.Vec2;
const vec2 = math.vec2;
const Vec3 = math.Vec3;
const vec3 = math.vec3;
const Vec4 = math.Vec4;
const vec4 = math.vec4;

const SIZE_OF_U32 = @sizeOf(u32);
const SIZE_OF_FLOAT = @sizeOf(f32);

pub const Vertex = extern struct {
    position: Vec3,
    normal: Vec3,
    texcoords: Vec2,
    //color: Vec4,
    //tangent: Vec4

    pub fn init(x: f32, y: f32, z: f32, nx: f32, ny: f32, nz: f32, tu: f32, tv: f32) Vertex {
        return .{
            .position = vec3(x, y, z),
            .normal = vec3(nx, ny, nz),
            .texcoords = vec2(tu, tv),
            // .color = c,
        };
    }

    pub fn clone(self: *Vertex) Vertex {
        return .{
            .position = self.position,
            .normal = self.normal,
            .texcoords = self.texcoords,
            //.color = self.color,
        };
    }
};

pub const ShapeBuilder = struct {
    shape_type: ShapeType,
    vertices: std.ArrayList(Vertex),
    indices: std.ArrayList(u32),
    aabb: AABB,

    pub fn init(allocator: Allocator, shape_type: ShapeType) ShapeBuilder {
        return .{
            .shape_type = shape_type,
            .vertices = std.ArrayList(Vertex).init(allocator),
            .indices = std.ArrayList(u32).init(allocator),
            .aabb = AABB.init(),
        };
    }

    pub fn deinit(self: *ShapeBuilder) void {
        self.indices.deinit();
        self.vertices.deinit();
    }
};

pub const ShapeType = enum {
    Cube,
    Cylinder,
    Sphere,
};

pub const Shape = struct {
    shape_type: ShapeType,
    vao: u32,
    vbo: u32,
    ebo: u32,
    num_indices: i32,
    aabb: AABB,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        gl.DeleteVertexArrays(1, &self.vao);
        gl.DeleteBuffers(1, &self.vbo);
    }

    pub fn render(self: *const Self) void {
        gl.bindVertexArray(self.vao);
        gl.drawElements(
            gl.TRIANGLES,
            self.num_indices,
            gl.UNSIGNED_INT,
            null,
        );
        gl.bindVertexArray(0);
    }
};

// Todo: consider changing this so that the buffers are per vertex component instead of per vertex itself.
// ie. per position, normal, texcoords, color, etc. That why the vertex can be more flexible.
// For example, that's what bevy does.
pub fn initGLBuffers(builder: *const ShapeBuilder) Shape {
    var vao: u32 = undefined;
    var vbo: u32 = undefined;
    var ebo: u32 = undefined;

    gl.genVertexArrays(1, &vao);
    gl.genBuffers(1, &vbo);
    gl.genBuffers(1, &ebo);

    gl.bindVertexArray(vao);

    // vertices
    gl.bindBuffer(gl.ARRAY_BUFFER, vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @intCast(builder.vertices.items.len * @sizeOf(Vertex)),
        builder.vertices.items.ptr,
        gl.STATIC_DRAW,
    );

    // indices
    gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, ebo);
    gl.bufferData(
        gl.ELEMENT_ARRAY_BUFFER,
        @intCast(builder.indices.items.len * @sizeOf(u32)),
        builder.indices.items.ptr,
        gl.STATIC_DRAW,
    );

    // position
    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        SIZE_OF_FLOAT * 8,
        @ptrFromInt(0),
    );
    gl.enableVertexAttribArray(0);

    // normal
    gl.vertexAttribPointer(
        1,
        3,
        gl.FLOAT,
        gl.FALSE,
        SIZE_OF_FLOAT * 8,
        @ptrFromInt(SIZE_OF_FLOAT * 3),
    );
    gl.enableVertexAttribArray(1);

    // texcoords
    gl.vertexAttribPointer(
        2,
        2,
        gl.FLOAT,
        gl.FALSE,
        SIZE_OF_FLOAT * 8,
        @ptrFromInt(SIZE_OF_FLOAT * 6),
    );
    gl.enableVertexAttribArray(2);

    return .{
        .shape_type = builder.shape_type,
        .vao = vao,
        .vbo = vbo,
        .ebo = ebo,
        .num_indices = @intCast(builder.indices.items.len),
        .aabb = builder.aabb,
    };
}
