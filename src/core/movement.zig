const std = @import("std");
const math = @import("math");

pub const Vec3 = math.Vec3;
pub const vec3 = math.vec3;
pub const Quat = math.Quat;

pub const MovementDirection = enum {
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
    RotateRight,
    RotateLeft,
    RotateUp,
    RotateDown,
    RollRight,
    RollLeft,
    RadiusIn,
    RadiusOut,
    OrbitUp,
    OrbitDown,
    OrbitLeft,
    OrbitRight,
    CircleRight,
    CircleLeft,
    CircleUp,  // always cross the pole
    CircleDown,
};

const world_up = Vec3.init(0.0, 1.0, 0.0);
const half_pi = math.pi / 2.0;

var buf: [1024]u8 = undefined;
var buf2: [1024]u8 = undefined;
var buf3: [1024]u8 = undefined;
var buf4: [1024]u8 = undefined;

pub const Movement = struct {
    position: Vec3,
    target: Vec3,
    up: Vec3,
    forward: Vec3,
    right: Vec3,
    world_up: Vec3 = world_up,
    translate_speed: f32 = 50.0,
    rotation_speed: f32 = 50.0,
    orbit_speed: f32 = 50.0,
    direction: MovementDirection = .Forward,
    frame_count: u32 = 0,
    period: u32 = 100,

    const Self = @This();

    pub fn init(position: Vec3, target: Vec3) Movement {
        const orientation = Quat.lookAtOrientation(position, target, world_up);
        const axes = orientation.toAxes();
        return Movement{
            .position = position,
            .target = target,
            .right = axes[0].xyz(),
            .up = axes[1].xyz(),
            .forward = axes[2].xyz(),
        };
    }

    pub fn reset(self: *Self, position: Vec3, target: Vec3) void {
        self.position = position;
        self.target = target;
        const orientation = Quat.lookAtOrientation(position, target, self.world_up);
        const axes = orientation.toAxes();
        self.right = axes[0].xyz();
        self.up = axes[1].xyz();
        self.forward = axes[2].xyz();
        self.frame_count = 0;
    }

    pub fn translate(self: *Self, offset: Vec3) void {
        self.position = self.position.add(&offset);
    }

    pub fn orthonormalizeUp(self: *Self) void {
        if (self.target.sub(&self.position).lengthSquared() < 0.0001) {
            return; // Skip if position == target
        }
        // std.debug.print("\northonormalize Up current state\n", .{});
        // self.printState();
        self.up.normalize();
        self.forward = self.target.sub(&self.position).normalizeTo();
        self.right = self.forward.crossNormalized(&self.up);
        // std.debug.print("\northonormalize Up new state\n", .{});
        // self.printState();
    }

    pub fn orthonormalizeRight(self: *Self) void {
        if (self.target.sub(&self.position).lengthSquared() < 0.0001) {
            return; // Skip if position == target
        }
        // std.debug.print("\northonormalize Right current state\n", .{});
        // self.printState();
        self.right.normalize();
        self.forward = self.target.sub(&self.position).normalizeTo();
        self.up = self.right.crossNormalized(&self.forward);
        // std.debug.print("\northonormalize Right new state\n", .{});
        // self.printState();
    }

    pub fn orthonormalizeUpPeriodic(self: *Self) void {
        if (@mod(self.frame_count, self.period) == 0) {
            self.orthonormalizeUp();
        }
    }

    pub fn orthonormalizeRightPeriodic(self: *Self) void {
        if (@mod(self.frame_count, self.period) == 0) {
            self.orthonormalizeRight();
        }
    }

    pub fn processMovement(
        self: *Self,
        direction: MovementDirection,
        delta_time: f32,
    ) void {
        self.frame_count += 1;
        // if (self.direction != direction) {
        //     std.debug.print("direction: {any}\n", .{direction});
        // }
        self.direction = direction;
        const translation_velocity = self.translate_speed * delta_time;
        const rot_angle = math.degreesToRadians(self.rotation_speed * delta_time);
        const orbit_angle = math.degreesToRadians(self.orbit_speed * delta_time);

        switch (direction) {
            .Forward => {
                self.position = self.position.add(&self.forward.mulScalar(translation_velocity));
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .Backward => {
                self.position = self.position.sub(&self.forward.mulScalar(translation_velocity));
            },
            .Left => {
                self.position = self.position.sub(&self.right.mulScalar(translation_velocity));
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .Right => {
                self.position = self.position.add(&self.right.mulScalar(translation_velocity));
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .Up => {
                self.position = self.position.add(&self.up.mulScalar(translation_velocity));
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .Down => {
                self.position = self.position.sub(&self.up.mulScalar(translation_velocity));
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .RotateRight => {
                const rot = Quat.fromAxisAngle(&self.up, -rot_angle);
                const translated_target = self.target.sub(&self.position);
                const rotated_target = rot.rotateVec(&translated_target);
                self.target = self.position.add(&rotated_target);
                self.right = rot.rotateVec(&self.right);
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .RotateLeft => {
                const rot = Quat.fromAxisAngle(&self.up, rot_angle);
                const translated_target = self.target.sub(&self.position);
                const rotated_target = rot.rotateVec(&translated_target);
                self.target = self.position.add(&rotated_target);
                self.right = rot.rotateVec(&self.right);
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .RotateUp => {
                const rot = Quat.fromAxisAngle(&self.right, rot_angle);
                const translated_target = self.target.sub(&self.position);
                const rotated_target = rot.rotateVec(&translated_target);
                self.target = self.position.add(&rotated_target);
                self.up = rot.rotateVec(&self.up);
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .RotateDown => {
                const rot = Quat.fromAxisAngle(&self.right, -rot_angle);
                const translated_target = self.target.sub(&self.position);
                const rotated_target = rot.rotateVec(&translated_target);
                self.target = self.position.add(&rotated_target);
                self.up = rot.rotateVec(&self.up);
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .RollRight => {
                const rot = Quat.fromAxisAngle(&self.forward, rot_angle);
                const translated_target = self.target.sub(&self.position);
                const rotated_target = rot.rotateVec(&translated_target);
                self.target = self.position.add(&rotated_target);
                self.up = rot.rotateVec(&self.up);
                self.right = rot.rotateVec(&self.right);
            },
            .RollLeft => {
                const rot = Quat.fromAxisAngle(&self.forward, -rot_angle);
                const translated_target = self.target.sub(&self.position);
                const rotated_target = rot.rotateVec(&translated_target);
                self.target = self.position.add(&rotated_target);
                self.up = rot.rotateVec(&self.up);
                self.right = rot.rotateVec(&self.right);
            },
            .RadiusIn => {
                const dir = self.target.sub(&self.position).normalizeTo();
                self.position = self.position.add(&dir.mulScalar(translation_velocity));
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .RadiusOut => {
                const dir = self.target.sub(&self.position).normalizeTo();
                self.position = self.position.sub(&dir.mulScalar(translation_velocity));
                self.forward = self.target.sub(&self.position).normalizeTo();
            },
            .OrbitRight => {
                const rot = Quat.fromAxisAngle(&self.up, -orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.right = rot.rotateVec(&self.right);
                self.orthonormalizeUpPeriodic();
            },
            .OrbitLeft => {
                const rot = Quat.fromAxisAngle(&self.up, orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.right = rot.rotateVec(&self.right);
                self.orthonormalizeUpPeriodic();
            },
            .OrbitUp => {
                const rot = Quat.fromAxisAngle(&self.right, -orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.up = rot.rotateVec(&self.up);
                self.orthonormalizeRightPeriodic();
            },
            .OrbitDown => {
                const rot = Quat.fromAxisAngle(&self.right, orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.up = rot.rotateVec(&self.up);
                self.orthonormalizeRightPeriodic();
            },
            .CircleRight => {
                const rot = Quat.fromAxisAngle(&self.world_up, -orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.up = rot.rotateVec(&self.up);
                self.right = self.forward.crossNormalized(&self.up);
            },
            .CircleLeft => {
                const rot = Quat.fromAxisAngle(&self.world_up, orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.up = rot.rotateVec(&self.up);
                self.right = self.forward.crossNormalized(&self.up);
            },
            .CircleUp => {
                const rot_90 = Quat.fromAxisAngle(&self.world_up, -half_pi);
                const forward_zx = vec3(self.forward.x, 0.0, self.forward.z);
                const target_right = rot_90.rotateVec(&forward_zx);
                const rot = Quat.fromAxisAngle(&target_right, orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.up = rot.rotateVec(&self.up);
                self.right = self.forward.crossNormalized(&self.up);
            },
            .CircleDown => {
                const rot_90 = Quat.fromAxisAngle(&self.world_up, -half_pi);
                const forward_zx = vec3(self.forward.x, 0.0, self.forward.z);
                const target_right = rot_90.rotateVec(&forward_zx);
                const rot = Quat.fromAxisAngle(&target_right, orbit_angle);
                const translated_position = self.position.sub(&self.target);
                const rotated_position = rot.rotateVec(&translated_position);
                self.position = self.target.add(&rotated_position);
                self.forward = self.target.sub(&self.position).normalizeTo();
                self.up = rot.rotateVec(&self.up);
                self.right = self.forward.crossNormalized(&self.up);
            },
        }
    }

    pub fn processMouseMovement(self: *Self, xoffset_in: f32, yoffset_in: f32, constrain_pitch: bool) void {
        _ = self;
        _ = xoffset_in;
        _ = yoffset_in;
        _ = constrain_pitch;
    }

    pub fn printState(self: *Self) void {
        std.debug.print("Position: {s}\n", .{self.position.asString(&buf)});
        std.debug.print("Target: {s}\n", .{self.target.asString(&buf)});
        std.debug.print("Forward: {s}\n", .{self.forward.asString(&buf4)});
        std.debug.print("Up: {s}\n", .{self.up.asString(&buf2)});
        std.debug.print("Right: {s}\n", .{self.right.asString(&buf3)});
    }

    pub fn update(self: *Self, angle: f32, direction: MovementDirection) void {
        const angle_degrees = math.radiansToDegrees(angle);
        const delta_time = angle_degrees / self.orbit_speed;
        self.processMovement(direction, delta_time);
    }
};

test "orbit right left motion" {
    const target = Vec3.init(0.0, 0.0, 0.0);
    const radius: f32 = 10.0;
    const tilt_angle = math.degreesToRadians(45.0);
    var position = Vec3.init(radius, 0.0, 0.0);
    const tilt_axis = Vec3.init(0.0, 0.0, 1.0);
    const tilt_quat = Quat.fromAxisAngle(&tilt_axis, tilt_angle);
    position = tilt_quat.rotateVec(&position);
    var movement = Movement.init(position, target);
    movement.up = tilt_quat.rotateVec(&Vec3.init(0.0, 1.0, 0.0));
    movement.right = movement.up.crossNormalized(&movement.forward);
    const start_pos = position.clone();
    const steps = 12;
    const step_angle = math.degreesToRadians(30.0);
    const epsilon = 0.001;
    for (0..steps) |i| {
        movement.update(step_angle, .OrbitRight);
        if (i % 3 == 0) {
            std.debug.print("\nStep {d}:\n", .{i});
            movement.printState();
            const current_radius = movement.position.sub(&target).length();
            try std.testing.expectApproxEqAbs(current_radius, radius, epsilon);
            const translated_position = movement.position.sub(&target);
            const translated_position_norm = translated_position.normalizeTo();
            const dot_with_up = translated_position_norm.dot(&movement.up);
            try std.testing.expectApproxEqAbs(dot_with_up, 0.0, epsilon);
        }
    }
    try std.testing.expectApproxEqAbs(movement.position.x, start_pos.x, epsilon);
    try std.testing.expectApproxEqAbs(movement.position.y, start_pos.y, epsilon);
    try std.testing.expectApproxEqAbs(movement.position.z, start_pos.z, epsilon);
}

test "rotate right motion" {
    const position = Vec3.init(10.0, 0.0, 0.0);
    const target = Vec3.init(0.0, 0.0, 0.0);
    var movement = Movement.init(position, target);
    const start_target = target.clone();
    const steps = 12;
    const step_angle = math.degreesToRadians(30.0);
    const epsilon = 0.001;
    for (0..steps) |_| {
        movement.update(step_angle, .RotateRight);
    }
    // After 360 degrees, target should return to start
    try std.testing.expectApproxEqAbs(movement.target.x, start_target.x, epsilon);
    try std.testing.expectApproxEqAbs(movement.target.y, start_target.y, epsilon);
    try std.testing.expectApproxEqAbs(movement.target.z, start_target.z, epsilon);
    // Position should remain unchanged
    try std.testing.expectApproxEqAbs(movement.position.x, position.x, epsilon);
    try std.testing.expectApproxEqAbs(movement.position.y, position.y, epsilon);
    try std.testing.expectApproxEqAbs(movement.position.z, position.z, epsilon);
}
