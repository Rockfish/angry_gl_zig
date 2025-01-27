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
pub const ORTHO_SCALE: f32 = 10.0;

pub const CameraMovement = enum {
    // panning movement in relation to up, front, right axes at camera position
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
    // rotation of camera position, ie. yaw and pitch
    RotateRight,
    RotateLeft,
    RotateUp,
    RotateDown,
    RollRight,
    RollLeft,
    // polar movement around the target
    MoveIn,
    MoveOut,
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
    world_up: Vec3,
    yaw: f32,
    pitch: f32,
    front: Vec3, // store?
    up: Vec3, // store?
    right: Vec3, // store?
    zoom: f32, // hmm
    fovy: f32,
    projection_type: ProjectionType,
    ortho_scale: f32,
    ortho_width: f32,
    ortho_height: f32,
    aspect: f32,
    camera_speed: f32,
    target_speed: f32,
    mouse_sensitivity: f32,
    target_pans: bool,
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
        const camera = try allocator.create(Camera);
        camera.* = Camera{
            .world_up = vec3(0.0, 1.0, 0.0),
            .position = config.position,
            .target = config.target,
            .front = vec3(0.0, 0.0, -1.0),
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
            .aspect = config.scr_width / config.scr_height,
            .camera_speed = SPEED,
            .target_speed = SPEED,
            .mouse_sensitivity = SENSITIVITY,
            .target_pans = false,
            .allocator = allocator,
        };
        camera.updateCameraVectors();
        return camera;
    }

    pub fn set_target(self: *Self, target: Vec3) void {
        self.target = target;
    }

    pub fn set_aspect(self: *Self, aspect: f32) void {
        self.aspect = aspect;
    }

    pub fn set_ortho_dimensions(self: *Self, width: f32, height: f32) void {
        self.ortho_width = width;
        self.ortho_height = height;
    }

    pub fn set_projection(self: *Self, projection: ProjectionType) void {
        self.projection_type = projection;
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
        // const top = self.fovy / 2.0;
        // const right = top * self.aspect;
        return Mat4.orthographicRhGl(
            -self.ortho_width / self.ortho_scale,
            self.ortho_width / self.ortho_scale,
            -self.ortho_height / self.ortho_scale,
            self.ortho_height / self.ortho_scale,
            NEAR,
            FAR,
        );
    }

    pub fn get_perspective_projection(self: *Self) Mat4 {
        return Mat4.perspectiveRhGl(to_rads(self.fovy), self.aspect, NEAR, FAR);
    }

    // processes input received from any keyboard-like input system. Accepts input parameter
    // in the form of camera defined ENUM (to abstract it from windowing systems)
    pub fn processMovement(self: *Self, direction: CameraMovement, delta_time: f32) void {
        const velocity: f32 = self.camera_speed * delta_time;

        switch (direction) {
            .Forward => {
                self.position = self.position.add(&self.front.mulScalar(velocity * 0.2));
                if (self.target_pans) {
                    self.target = self.target.add(&self.front.mulScalar(velocity));
                }
            },
            .Backward => {
                self.position = self.position.sub(&self.front.mulScalar(velocity * 0.2));
                if (self.target_pans) {
                    self.target = self.target.sub(&self.front.mulScalar(velocity));
                }
            },
            .Left => {
                self.position = self.position.sub(&self.right.mulScalar(velocity));
                if (self.target_pans) {
                    self.target = self.target.sub(&self.right.mulScalar(velocity));
                }
            },
            .Right => {
                self.position = self.position.add(&self.right.mulScalar(velocity));
                if (self.target_pans) {
                    self.target = self.target.add(&self.right.mulScalar(velocity));
                }
            },
            .Up => {
                self.position = self.position.add(&self.up.mulScalar(velocity));
                if (self.target_pans) {
                    self.target = self.target.add(&self.up.mulScalar(velocity));
                }
            },
            .Down => {
                self.position = self.position.sub(&self.up.mulScalar(velocity));
                if (self.target_pans) {
                    self.target = self.target.sub(&self.up.mulScalar(velocity));
                }
            },
            .RotateRight => {},
            .RotateLeft => {},
            .RotateUp => {},
            .RotateDown => {},
            .RollRight => {},
            .RollLeft => {},
            // These directions are relative to the target
            .MoveIn => { // MoveIn on the vector to target
                const dir = self.target.sub(&self.position).normalize();
                self.position = self.position.add(&dir.mulScalar(velocity));
            },
            .MoveOut => { // MoveOut on vector from target
                const dir = self.target.sub(&self.position).normalize();
                self.position = self.position.sub(&dir.mulScalar(velocity));
            },
            .OrbitRight => { // OrbitRight along latitude
                const angle = to_rads(velocity);
                const rotation = Quat.fromAxisAngle(&self.up, angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);

                // revisit - maybe accumulates errors?
                self.front = rotation.rotateVec(&self.front);
                self.right = rotation.rotateVec(&self.right);
                //std.debug.print("position: {d}, {d}, {d}\n", .{ self.position.x, self.position.y, self.position.z });
            },
            .OrbitLeft => { // OrbitLeft along latitude
                const angle = to_rads(velocity);
                const rotation = Quat.fromAxisAngle(&self.up, -angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);

                // revisit - maybe accumulates errors?
                self.front = rotation.rotateVec(&self.front);
                self.right = rotation.rotateVec(&self.right);
                //std.debug.print("position: {d}, {d}, {d}\n", .{ self.position.x, self.position.y, self.position.z });
            },
            .OrbitUp => { // OrbitUp along longitude
                const angle = to_rads(velocity);
                const rotation = Quat.fromAxisAngle(&self.right, -angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);
            },
            .OrbitDown => { // OrbitDown along longitude
                const angle = to_rads(velocity);
                const rotation = Quat.fromAxisAngle(&self.right, angle);
                const radius_vec = self.position.sub(&self.target);
                const rotated_vec = rotation.rotateVec(&radius_vec);
                self.position = self.target.add(&rotated_vec);
            },
        }

        // For FPS: make sure the user stays at the ground level
        // self.Position.y = 0.0; // <-- this one-liner keeps the user at the ground level (xz plane)
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
        self.update_camera_vectors();

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

pub inline fn to_rads(degrees: f32) f32 {
    return degrees * std.math.rad_per_deg;
}
