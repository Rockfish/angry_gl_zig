const std = @import("std");
const math = @import("math");

const Allocator = std.mem.Allocator;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub const YAW: f32 = -90.0;
pub const PITCH: f32 = 0.0;
pub const SPEED: f32 = 100.5;
pub const SENSITIVITY: f32 = 0.1;
pub const FOV: f32 = 45.0;
pub const NEAR: f32 = 0.01;
pub const FAR: f32 = 2000.0;
pub const ORTHO_SCALE: f32 = 40.0;

pub const x_direction = vec3(-1.0, 0.0, 0.0);
pub const y_direction = vec3(0.0, 1.0, 0.0);
pub const z_direction = vec3(0.0, 0.0, -1.0);

pub const CameraMovement = enum {
    // panning movement in relation to up, front, right axes at camera position
    // Should move
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
    // rotation around camera position
    // Should change the forward vector
    RotateRight,
    RotateLeft,
    RotateUp,
    RotateDown,
    RollRight,
    RollLeft,
    // polar movement around the target
    RadiusIn,
    RadiusOut,
    OrbitUp,
    OrbitDown,
    OrbitLeft,
    OrbitRight,
};

pub const ViewType = enum {
    LookTo,
    LookAt,
};

pub const ProjectionType = enum {
    Perspective,
    Orthographic,
};

pub const Camera = struct {
    position: Vec3,
    target: Vec3,
    direction: CameraMovement = .Forward,
    velocity: f32 = 0.0,
    world_up: Vec3,
    yaw: f32,
    pitch: f32,
    forward: Vec3,
    up: Vec3,
    right: Vec3,
    zoom: f32,
    fovy: f32,
    projection_type: ProjectionType,
    view_type: ViewType,
    ortho_scale: f32,
    ortho_width: f32,
    ortho_height: f32,
    aspect: f32,
    camera_speed: f32,
    target_speed: f32,
    mouse_sensitivity: f32,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *const Self) void {
        self.allocator.destroy(self);
    }

    const Config = struct {
        position: Vec3,
        target: Vec3,
        scr_width: f32,
        scr_height: f32,
    };

    pub fn init(allocator: Allocator, config: Config) !*Camera {
        var forward = config.target.sub(&config.position);
        forward.y = 0.0;
        forward = forward.normalizeTo();
        var buf: [50]u8 = undefined;
        std.debug.print("Camera initial target: {s}\n", .{config.target.asString(&buf)});
        std.debug.print("Camera initial position: {s}\n", .{config.position.asString(&buf)});
        std.debug.print("Camera initial forward: {s}\n", .{forward.asString(&buf)});

        const camera = try allocator.create(Camera);
        camera.* = Camera{
            .world_up = vec3(0.0, 1.0, 0.0),
            .position = config.position,
            .target = config.target,
            .forward = forward,
            .up = vec3(0.0, 1.0, 0.0),
            .right = vec3(0.0, 0.0, 0.0),
            .yaw = YAW,
            .pitch = PITCH,
            .zoom = 45.0,
            .fovy = FOV,
            .ortho_scale = ORTHO_SCALE,
            .ortho_width = config.scr_width / ORTHO_SCALE,
            .ortho_height = config.scr_height / ORTHO_SCALE,
            .projection_type = ProjectionType.Perspective,
            .view_type = ViewType.LookTo,
            .aspect = config.scr_width / config.scr_height,
            .camera_speed = SPEED,
            .target_speed = SPEED,
            .mouse_sensitivity = SENSITIVITY,
            .allocator = allocator,
        };
        camera.updateCameraVectors();
        return camera;
    }

    pub fn setTarget(self: *Self, target: Vec3) void {
        self.target = target;
    }

    pub fn setAspect(self: *Self, aspect: f32) void {
        self.aspect = aspect;
    }

    pub fn setOrthoScale(self: *Self, ortho_scale: f32) void {
        self.ortho_scale = ortho_scale;
    }

    pub fn setOrthoDimensions(self: *Self, ortho_width: f32, ortho_height: f32) void {
        self.ortho_width = ortho_width;
        self.ortho_height = ortho_height;
    }

    pub fn setScreenDimensions(self: *Self, width: f32, height: f32) void {
        self.aspect = width / height;
        self.ortho_width = width / self.ortho_scale;
        self.ortho_height = height / self.ortho_scale;
    }

    pub fn setProjection(self: *Self, projection: ProjectionType) void {
        self.projection_type = projection;
    }

    pub fn setFromWorldUpYawPitch(self: *Self, world_up: Vec3, yaw: f32, pitch: f32) void {
        self.world_up = world_up;
        // calculate the new Front vector
        self.forward = vec3(
            std.math.cos(math.degreesToRadians(yaw)) * std.math.cos(math.degreesToRadians(pitch)),
            std.math.sin(math.degreesToRadians(pitch)),
            std.math.sin(math.degreesToRadians(yaw)) * std.math.cos(math.degreesToRadians(pitch)),
        ).normalizeTo();

        self.updateCameraVectors();
    }

    fn updateCameraVectors(self: *Self) void {
        // calculate the new Front vector
        // self.forward = vec3(
        //     std.math.cos(math.degreesToRadians(self.yaw)) * std.math.cos(to_rads(self.pitch)),
        //     std.math.sin(math.degreesToRadians(self.pitch)),
        //     std.math.sin(math.degreesToRadians(self.yaw)) * std.math.cos(to_rads(self.pitch)),
        // ).normalize();

        // re-calculate the Right and Up vector
        // normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
        self.right = self.forward.cross(&self.world_up).normalizeTo();
        self.up = self.right.cross(&self.forward).normalizeTo();
        // std.debug.print("front: {any}\nright: {any}\nup: {any}\n", .{self.front, self.right, self.up});
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

    pub fn getOrthoProjection(self: *Self) Mat4 {
        // const top = self.fovy / 2.0;
        // const right = top * self.aspect;
        return Mat4.orthographicRhGl(
            -self.ortho_width,
            self.ortho_width,
            -self.ortho_height,
            self.ortho_height,
            NEAR,
            FAR,
        );
    }

    pub fn getPerspectiveProjection(self: *Self) Mat4 {
        return Mat4.perspectiveRhGl(math.degreesToRadians(self.fovy), self.aspect, NEAR, FAR);
    }

    pub fn reset(self: *Self, position: Vec3, target: Vec3) void {
        self.position = position;
        self.target = target;
        var forward = target.sub(&position);
        forward.y = 0.0;
        forward = forward.normalizeTo();
        self.forward = forward;
        self.updateCameraVectors();
    }

    pub fn processMovement(self: *Self, direction: CameraMovement, delta_time: f32) void {
        const velocity: f32 = self.camera_speed * delta_time;

        switch (direction) {
            .Forward => {
                self.position = self.position.add(&self.forward.mulScalar(velocity * 0.2));
            },
            .Backward => {
                self.position = self.position.sub(&self.forward.mulScalar(velocity * 0.2));
            },
            .Left => {
                self.position = self.position.sub(&self.right.mulScalar(velocity));
            },
            .Right => {
                self.position = self.position.add(&self.right.mulScalar(velocity));
            },
            .Up => {
                self.position = self.position.add(&self.up.mulScalar(velocity));
            },
            .Down => {
                self.position = self.position.sub(&self.up.mulScalar(velocity));
            },
            .RotateRight => {
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.up, -angle);
                self.forward = rotation.rotateVec(&self.forward);
            },
            .RotateLeft => {
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.up, angle);
                self.forward = rotation.rotateVec(&self.forward);
            },
            .RotateUp => {
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.right, angle);
                self.forward = rotation.rotateVec(&self.forward);
            },
            .RotateDown => {
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.right, -angle);
                self.forward = rotation.rotateVec(&self.forward);
            },
            .RollRight => {},
            .RollLeft => {},
            // These are polar directions centered on the target
            .RadiusIn => { // Move in on the radius vector to target
                const dir = self.target.sub(&self.position).normalizeTo();
                self.position = self.position.add(&dir.mulScalar(velocity));
            },
            .RadiusOut => { // Move out on the radius vector from target
                const dir = self.target.sub(&self.position).normalizeTo();
                self.position = self.position.sub(&dir.mulScalar(velocity));
            },
            .OrbitRight => { // OrbitRight along latitude
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.up, angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);

                // revisit - maybe accumulates errors?
                self.forward = rotation.rotateVec(&self.forward);
                self.right = rotation.rotateVec(&self.right);
            },
            .OrbitLeft => { // OrbitLeft along latitude
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.up, -angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);

                // revisit - maybe accumulates errors?
                self.forward = rotation.rotateVec(&self.forward);
                self.right = rotation.rotateVec(&self.right);
            },
            .OrbitUp => { // OrbitUp along longitude
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.right, -angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);
            },
            .OrbitDown => { // OrbitDown along longitude
                const angle = math.degreesToRadians(velocity);
                const rotation = Quat.fromAxisAngle(&self.right, angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);
            },
        }

        self.direction = direction;
        self.velocity = velocity;

        self.updateCameraVectors();

        // var buf: [2024]u8 = undefined;
        // std.debug.print("{s}\n", .{ self.asString(&buf) });
    }

    pub fn asString(self: *const Self, buf: []u8) []u8 {
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
                self.direction,
                self.velocity,
                self.position.asString(&position),
                self.target.asString(&target),
                self.forward.asString(&forward),
                math.radiansToDegrees(Vec3.angle(&z_direction, &vec3(self.forward.x, 0.0, self.forward.z))),
                self.right.asString(&right),
                self.up.asString(&up),
            },
        ) catch |err| std.debug.panic("{any}", .{err});
    }

    // processes input received from a mouse input system. Expects the offset value in both the x and y direction.
    pub fn processMouseMovement(self: *Self, xoffset_in: f32, yoffset_in: f32, constrain_pitch: bool) void {
        const xoffset: f32 = xoffset_in * self.mouse_sensitivity;
        const yoffset: f32 = yoffset_in * self.mouse_sensitivity;

        self.yaw += xoffset;
        self.pitch += yoffset;

        // make sure that when pitch is out of bounds, screen doesn't get flipped
        if (constrain_pitch) {
            if (self.pitch > 89.0) {
                self.pitch = 89.0;
            }
            if (self.pitch < -89.0) {
                self.pitch = -89.0;
            }
        }

        // update Front, Right and Up Vectors using the updated Euler angles
        self.updateCameraVectors();

        // debug!("camera: {:#?}", self);
    }

    // processes input received from a mouse scroll-wheel event. Only requires input on the vertical wheel-axis
    pub fn processMouseScroll(self: *Self, yoffset: f32) void {
        self.zoom -= yoffset;
        if (self.zoom < 1.0) {
            self.zoom = 1.0;
        }
        if (self.zoom > 45.0) {
            self.zoom = 45.0;
        }
    }
};

