const std = @import("std");
const core = @import("core");
const math = @import("math");
const gl = @import("zopengl").bindings;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const Mat4 = math.Mat4;

const Texture = core.texture.Texture;
const TextureConfig = core.texture.TextureConfig;
const TextureWrap = core.texture.TextureWrap;
const Shader = core.Shader;

const BURN_MARK_TIME: f32 = 5.0;

pub const BurnMark = struct {
    position: Vec3,
    time_left: f32,
    allocator: Allocator,

    pub fn deinit(self: *BurnMark) void {
        self.allocator.destroy(self);
    }
};

pub const BurnMarks = struct {
    unit_square_vao: c_uint,
    mark_texture: Texture,
    marks: ArrayList(?*BurnMark),
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.mark_texture.deinit();
        self.marks.deinit();
        self.allocator.destroy(self);
    }

    pub fn new(allocator: Allocator, unit_square_vao: c_uint) !*Self {
        var texture_config = TextureConfig.default();
        texture_config.set_wrap(TextureWrap.Repeat);

        const mark_texture = try Texture.new(allocator, "angrygl_assets/bullet/burn_mark.png", texture_config);

        const burn_marks = try allocator.create(BurnMarks);
        burn_marks.* = .{
            .unit_square_vao = unit_square_vao,
            .mark_texture = mark_texture,
            .marks = ArrayList(?*BurnMark).init(allocator),
            .allocator = allocator,
        };
        return burn_marks;
    }

    pub fn add_mark(self: *Self, position: Vec3) !void {
        const burn_mark = try self.allocator.create(BurnMark);
        burn_mark.* = BurnMark {
            .position = position,
            .time_left = BURN_MARK_TIME,
            .allocator = self.allocator,
        };
        try self.marks.append(burn_mark);
    }

    pub fn draw_marks(self: *Self, shader: *Shader, projection_view: *const Mat4, delta_time: f32) void {
        if (self.marks.items.len == 0) {
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

        for (self.marks.items) |*mark| {
            const scale: f32 = 0.5 * mark.*.?.time_left;
            mark.*.?.time_left -= delta_time;

            // model *= Mat4.from_translation(vec3(mark.x, 0.01, mark.z));
            var model = Mat4.fromTranslation(&mark.*.?.position);

            model = model.mulMat4(&Mat4.fromRotationX(math.degreesToRadians(-90.0)));
            model = model.mulMat4(&Mat4.fromScale(&vec3(scale, scale, scale)));

            shader.set_mat4("model", &model);

            gl.drawArrays(gl.TRIANGLES, 0, 6);
        }

        const predicate = Tester {};

        try core.utils.retain(BurnMark, Tester, &self.marks, predicate, self.allocator);

        gl.disable(gl.BLEND);
        gl.depthMask(gl.TRUE);
        gl.enable(gl.CULL_FACE);
    }

    const Tester = struct {
        pub fn predicate(self: *const Tester, m: *BurnMark) bool {
            _ = self;
            return m.time_left > 0.0;
        }
    };
};
