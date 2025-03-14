const std = @import("std");
const math = @import("math");

const Allocator = std.mem.Allocator;

const Movement = @import("movement.zig").Movement;
const MovementDirection = @import("movement.zig").MovementDirection;

const Vec3 = math.Vec3;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub const x_direction = math.vec3(-1.0, 0.0, 0.0);
pub const y_direction = math.vec3(0.0, 1.0, 0.0);
pub const z_direction = math.vec3(0.0, 0.0, -1.0);

pub const ProjectionType = enum {
    Perspective,
    Orthographic,
};

pub const ViewType = enum {
    LookTo,
    LookAt,
};

pub const Camera = struct {
    allocator: Allocator,
    movement: Movement,
    fovy: f32,
    aspect: f32,
    near: f32,
    far: f32,
    ortho_scale: f32,
    projection_type: ProjectionType,
    view_type: ViewType,
    translation_speed: f32 = 100.5,
    rotation_speed: f32 = 100.5,
    orbit_speed: f32 = 100.5,

    const Self = @This();

    const Config = struct {
        position: Vec3,
        target: Vec3,
        rotation: Quat,
        scr_width: f32,
        scr_height: f32,
    };

    pub fn deinit(self: *const Self) void {
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, config: Config) !*Camera {
        const rotation = Quat.identity();

        const camera = try allocator.create(Camera);
        camera.* = Camera{
            .allocator = allocator,
            .movement = Movement.init(config.position, rotation, config.target),
            .fovy = 45.0,
            .aspect = config.scr_width / config.scr_height,
            .near = 0.01,
            .far = 2000.0,
            .ortho_scale = 40.0,
            .projection_type = ProjectionType.Perspective,
            .view_type = ViewType.LookTo,
        };
        return camera;
    }

    pub fn getViewMatrix(self: *Camera) Mat4 {
        return switch (self.view_type) {
            .LookTo => Mat4.lookToRhGl(&self.movement.position, &self.movement.forward, &self.movement.up),
            .LookAt => Mat4.lookAtRhGl(&self.movement.position, &self.movement.target, &self.movement.up),
        };
    }

    pub fn getProjectionMatrix(self: *Camera) Mat4 {
        switch (self.projection_type) {
            .Perspective => {
                return Mat4.perspectiveRhGl(
                    math.degreesToRadians(self.fovy),
                    self.aspect,
                    self.near,
                    self.far,
                );
            },
            .Orthographic => {
                const ortho_width = self.aspect * self.ortho_scale;
                const ortho_height = self.ortho_scale;
                return Mat4.orthographicRhGl(
                    -ortho_width,
                    ortho_width,
                    -ortho_height,
                    ortho_height,
                    self.near,
                    self.far,
                );
            },
        }
    }

    pub fn getLookToView(self: *Self) Mat4 {
        return Mat4.lookToRhGl(&self.position, &self.forward, &self.up);
    }

    pub fn getLookAtView(self: *Self) Mat4 {
        return Mat4.lookAtRhGl(&self.position, &self.target, &self.up);
    }

    pub fn setLookAt(self: *Self) void {
        self.view_type = .LookAt;
    }

    pub fn setLookTo(self: *Self) void {
        self.view_type = .LookTo;
    }

    pub fn getViewByType(self: *Self) Mat4 {
        return switch (self.view_type) {
            .LookTo => self.getLookToView(),
            .LookAt => self.getLookAtView(),
        };
    }
    /// Pass through the movement command to the Movement component.
    pub fn processMovement(self: *Camera, direction: MovementDirection, delta_time: f32) void {
        // Use the same speed values or make these configurable.
        self.movement.processMovement(
            direction,
            delta_time,
            self.translation_speed,
            self.rotation_speed,
            self.ortho_speed,
        );
    }

    pub fn reset(self: *Self, position: Vec3, target: Vec3) void {
        self.movement.position = position;
        self.movement.target = target;
        var forward = target.sub(&position);
        forward.y = 0.0;
        forward = forward.normalizeTo();
        self.forward = forward;
        self.movement.
    }

    pub fn asString(self: *const Camera, buf: []u8) []u8 {
        var position: [100]u8 = undefined;
        var target: [100]u8 = undefined;
        var forward: [100]u8 = undefined;
        var right: [100]u8 = undefined;
        var up: [100]u8 = undefined;
        return std.fmt.bufPrint(
            buf,
            "Camera:\n   view_type: {any}\n   direction: {any}\n   velocity: {d}\n   position: {s}\n   target: {s}\n   forward: {s}  angle: {d}\n   right: {s}\n   up: {s}\n",
            .{
                self.view_type,
                self.movement.direction,
                self.translation_speed,
                self.movement.position.asString(&position),
                self.movement.target.asString(&target),
                self.movement.forward.asString(&forward),
                math.radiansToDegrees(Vec3.angle(&z_direction, &math.vec3(self.forward.x, 0.0, self.forward.z))),
                self.movement.right.asString(&right),
                self.movement.up.asString(&up),
            },
        ) catch |err| std.debug.panic("{any}", .{err});
    }
};
