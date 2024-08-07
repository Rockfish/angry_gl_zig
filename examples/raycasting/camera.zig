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
pub const FAR: f32 = 1000.0;

pub const CameraMovement = enum {
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
};

pub const MovementMode = enum {
    Planar,
    Polar,
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
    world_up: Vec3,
    yaw: f32,
    pitch: f32,
    front: Vec3, // store?
    up: Vec3, // store?
    right: Vec3, // store?
    zoom: f32, // hmm
    fovy: f32,
    projection: ProjectionType,
    aspect: f32,
    camera_speed: f32,
    target_speed: f32,
    mouse_sensitivity: f32,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *const Self) void {
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, position: Vec3, target: Vec3, aspect: f32) !*Camera {
        const camera = try allocator.create(Camera);
        camera.* = Camera{
            .world_up = vec3(0.0, 1.0, 0.0),
            .position = position,
            .target = target,
            // front, up, and right are used for panning
            .front = vec3(0.0, 0.0, -1.0),
            .up = vec3(0.0, 1.0, 0.0),
            .right = vec3(0.0, 0.0, 0.0),
            .yaw = YAW,
            .pitch = PITCH,
            .zoom = 0.0,
            .fovy = FOV,
            .projection = ProjectionType.Perspective,
            .aspect = aspect, //.front = vec3(0.0, 0.0, -1.0),
            // .world_up = vec3(0.0, 1.0, 0.0),
            .camera_speed = SPEED,
            .target_speed = SPEED,
            .mouse_sensitivity = SENSITIVITY,
            .allocator = allocator,
        };
        camera.update_camera_vectors();
        return camera;
    }

    pub fn set_target(self: *Self, target: Vec3) void {
        self.target = target;
    }

    pub fn set_aspect(self: *Self, aspect: f32) void {
        self.aspect = aspect;
    }

    pub fn set_projection(self: *Self, projection: ProjectionType) void {
        self.projection = projection;
    }

    fn update_camera_vectors(self: *Self) void {
        // calculate the new Front vector
        self.front = vec3(
            std.math.cos(to_rads(self.yaw)) * std.math.cos(to_rads(self.pitch)),
            std.math.sin(to_rads(self.pitch)),
            std.math.sin(to_rads(self.yaw)) * std.math.cos(to_rads(self.pitch)),
        ).normalize();

        // re-calculate the Right and Up vector
        // normalize the vectors, because their length gets closer to 0 the more you look up or down which results in slower movement.
        self.right = self.front.cross(&self.world_up).normalize();
        self.up = self.right.cross(&self.front).normalize();
        // std.debug.print("front: {any}\nright: {any}\nup: {any}\n", .{self.front, self.right, self.up});
    }

    pub fn get_lookto_view(self: *Self) Mat4 {
        return Mat4.lookToRhGl(&self.position, &self.front, &self.up);
    }

    pub fn get_lookat_view(self: *Self) Mat4 {
        return Mat4.lookAtRhGl(&self.position, &self.target, &self.up);
    }

    pub fn get_ortho_projection(self: *Self) Mat4 {
        const top = self.fovy / 2.0;
        const right = top * self.aspect;
        return Mat4.orthographicRhGl(-right, right, -top, top, NEAR, FAR);
    }

    pub fn get_perspective_projection(self: *Self) Mat4 {
        return Mat4.perspectiveRhGl(to_rads(self.fovy), self.aspect, NEAR, FAR);
    }

    // CameraMovement.Right => {
    //     const angle = to_rads(90.0);
    //     const turn_rotation = Quat.fromAxisAngle(&self.up, angle);
    //     const right = turn_rotation.rotateVec(&self.front);
    //     self.position = self.position.sub(&right.mulScalar(velocity));
    // },
    // CameraMovement.Left => {
    //     const angle = to_rads(90.0);
    //     const turn_rotation = Quat.fromAxisAngle(&self.up, angle);
    //     const right = turn_rotation.rotateVec(&self.front);
    //     self.position = self.position.add(&right.mulScalar(velocity));
    // },
    // processes input received from any keyboard-like input system. Accepts input parameter
    // in the form of camera defined ENUM (to abstract it from windowing systems)
    pub fn process_keyboard(self: *Self, direction: CameraMovement, mode: MovementMode, delta_time: f32) void {
        const velocity: f32 = self.camera_speed * delta_time;

        switch (mode) {
            .Planar => {
                switch (direction) {
                    CameraMovement.Forward => {
                        self.position = self.position.add(&self.front.mulScalar(velocity));
                    },
                    CameraMovement.Backward => {
                        self.position = self.position.sub(&self.front.mulScalar(velocity));
                    },
                    CameraMovement.Left => {
                        self.position = self.position.sub(&self.right.mulScalar(velocity));
                    },
                    CameraMovement.Right => {
                        self.position = self.position.add(&self.right.mulScalar(velocity));
                    },
                    CameraMovement.Up => {
                        self.position = self.position.add(&self.up.mulScalar(velocity));
                    },
                    CameraMovement.Down => {
                        self.position = self.position.sub(&self.up.mulScalar(velocity));
                    },
                }
            },
            .Polar => {
                switch (direction) {
                    CameraMovement.Right => {
                        const angle = to_rads(velocity);
                        const turn_rotation = Quat.fromAxisAngle(&self.up, angle);
                        const radius_vec = self.position.sub(&self.target);
                        const rotated_vec = turn_rotation.rotateVec(&radius_vec);
                        self.position = self.target.add(&rotated_vec);
                        //std.debug.print("position: {d}, {d}, {d}\n", .{ self.position.x, self.position.y, self.position.z });
                    },
                    CameraMovement.Left => {
                        const angle = to_rads(velocity);
                        const turn_rotation = Quat.fromAxisAngle(&self.up, -angle);
                        const radius_vec = self.position.sub(&self.target);
                        const rotated_vec = turn_rotation.rotateVec(&radius_vec);
                        self.position = self.target.add(&rotated_vec);
                        //std.debug.print("position: {d}, {d}, {d}\n", .{ self.position.x, self.position.y, self.position.z });
                    },
                    else => {},
                }
            },
        }

        // For FPS: make sure the user stays at the ground level
        // self.Position.y = 0.0; // <-- this one-liner keeps the user at the ground level (xz plane)
    }

    // processes input received from a mouse input system. Expects the offset value in both the x and y direction.
    pub fn process_mouse_movement(self: *Self, xoffset_in: i32, yoffset_in: i32, constrain_pitch: bool) void {
        const xoffset: f32 = @as(f32, @floatFromInt(xoffset_in)) * self.mouse_sensitivity;
        const yoffset: f32 = @as(f32, @floatFromInt(yoffset_in)) * self.mouse_sensitivity;

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
        self.update_camera_vectors();

        // debug!("camera: {:#?}", self);
    }

    // processes input received from a mouse scroll-wheel event. Only requires input on the vertical wheel-axis
    pub fn process_mouse_scroll(self: *Self, yoffset: f32) void {
        self.zoom -= yoffset;
        if (self.zoom < 1.0) {
            self.zoom = 1.0;
        }
        if (self.zoom > 45.0) {
            self.zoom = 45.0;
        }
    }
};

pub inline fn to_rads(degrees: f32) f32 {
    return degrees * std.math.rad_per_deg;
}
