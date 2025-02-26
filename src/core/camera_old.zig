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

const muzzlePointLightColor = vec3(1.0, 0.2, 0.0);

// Default camera values
pub const YAW: f32 = -90.0;
pub const PITCH: f32 = 0.0;
pub const SPEED: f32 = 100.5;
pub const SENSITIVITY: f32 = 0.1;
pub const ZOOM: f32 = 45.0;

// Defines several possible options for camera movement. Used as abstraction
// to stay away from window-system specific input methods
pub const CameraMovement = enum {
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
};

pub const Camera = struct {
    // camera Attributes
    position: Vec3,
    front: Vec3,
    world_up: Vec3,
    up: Vec3,
    right: Vec3,
    // euler Angles
    yaw: f32,
    pitch: f32,
    // camera options
    movement_speed: f32,
    mouse_sensitivity: f32,
    zoom: f32,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *const Self) void {
        self.allocator.destroy(self);
    }

    pub fn new(allocator: Allocator) !*Camera {
        const camera = try allocator.create(Camera);
        camera.* = Camera{
            .position = vec3(0.0, 0.0, 3.0),
            .front = vec3(0.0, 0.0, -1.0),
            .world_up = vec3(0.0, 1.0, 0.0),
            .up = vec3(0.0, 1.0, 0.0),
            .right = vec3(0.0, 0.0, 0.0),
            .yaw = YAW,
            .pitch = PITCH,
            .movement_speed = SPEED,
            .mouse_sensitivity = SENSITIVITY,
            .zoom = ZOOM,
            .allocator = allocator,
        };
        return camera;
    }

    pub fn camera_vec3(allocator: Allocator, position: Vec3) !*Camera {
        var camera = try Camera.new(allocator);
        camera.position = position;
        camera.update_camera_vectors();
        return camera;
    }

    pub fn camera_vec3_up_yaw_pitch(allocator: Allocator, position: Vec3, world_up: Vec3, yaw: f32, pitch: f32) !*Camera {
        var camera = try Camera.new(allocator);
        camera.position = position;
        camera.world_up = world_up;
        camera.yaw = yaw;
        camera.pitch = pitch;
        camera.update_camera_vectors();
        return camera;
    }

    pub fn camera_scalar(allocator: Allocator, pos_x: f32, pos_y: f32, pos_z: f32, up_x: f32, up_y: f32, up_z: f32, yaw: f32, pitch: f32) !*Camera {
        var camera = try Camera.new(allocator);
        camera.position = vec3(pos_x, pos_y, pos_z);
        camera.world_up = vec3(up_x, up_y, up_z);
        camera.yaw = yaw;
        camera.pitch = pitch;
        camera.update_camera_vectors();
        return camera;
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
        return Mat4.lookToRhGl(&self.position, &self.target, &self.up);
    }

    // processes input received from any keyboard-like input system. Accepts input parameter
    // in the form of camera defined ENUM (to abstract it from windowing systems)
    pub fn processMovement(self: *Self, direction: CameraMovement, delta_time: f32) void {
        const velocity: f32 = self.movement_speed * delta_time;

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

        // For FPS: make sure the user stays at the ground level
        // self.Position.y = 0.0; // <-- this one-liner keeps the user at the ground level (xz plane)
    }

    // processes input received from a mouse input system. Expects the offset value in both the x and y direction.
    pub fn processMouseMovement(self: *Self, xoffset_in: i32, yoffset_in: i32, constrain_pitch: bool) void {
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
