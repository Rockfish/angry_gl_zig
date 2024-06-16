const std = @import("std");
const core = @import("core");
const math = @import("math");
const gl = @import("zopengl").bindings;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Texture = core.Texture;
const Shader = core.Shader;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

const BURN_MARK_TIME: f32 = 5.0;

pub const BurnMark = struct {
    position: Vec3,
    time_left: f32,
};

pub const BurnMarks = struct {
    unit_square_vao: i32,
    mark_texture: Texture,
    marks: ArrayList(BurnMark),
    allocator: Allocator,

    const Self = @This();

    pub fn new(allocator: Allocator, unit_square_vao: i32) Self {
        const texture_config = Texture.TextureConfig.new().set_wrap(Texture.TextureWrap.Repeat);
        const mark_texture = Texture.new("angrygl_assets/bullet/burn_mark.png", &texture_config);

        return .{
            .unit_square_vao = unit_square_vao,
            .mark_texture = mark_texture,
            .marks = ArrayList(BurnMark).init(allocator),
        };
    }

    pub fn add_mark(self: *Self, position: Vec3) void {
        self.marks.push(BurnMark {
            .position = position,
            .time_left = BURN_MARK_TIME,
        });
    }

    pub fn draw_marks(self: *Self, shader: *Shader, projection_view: *Mat4, delta_time: f32) void {
        if (self.marks.len == 0) {
            return;
        }

        shader.use_shader();
        shader.set_mat4("PV", projection_view);

        shader.bind_texture(0, "texture_diffuse", &self.mark_texture);
        shader.bind_texture(1, "texture_normal", &self.mark_texture);

        gl.enable(gl.BLEND);
        gl.depthMask(gl.FALSE);
        gl.disable(gl.CULL_FACE);

        gl.bindVertexArray(self.unit_square_vao);

        for (self.marks.items) |mark| {
            const scale: f32 = 0.5 * mark.time_left;
            mark.time_left -= delta_time;

            // model *= Mat4.from_translation(vec3(mark.x, 0.01, mark.z));
            var model = Mat4.from_translation(mark.position);

            model *= Mat4.from_rotation_x(math.degreesToRadians(-90.0));
            model *= Mat4.from_scale(vec3(scale, scale, scale));

            shader.set_mat4("model", &model);

            gl.drawArrays(gl.TRIANGLES, 0, 6);
        }

        const predicate = struct {
           pub fn func(m: *BurnMark) bool {
              return m.time_left > 0.0;
           }
        };

        self.marks.retain(predicate.func);

        gl.disable(gl.BLEND);
        gl.depthMask(gl.TRUE);
        gl.enable(gl.CULL_FACE);
    }
};
