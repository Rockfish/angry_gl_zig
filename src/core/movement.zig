const std = @import("std");
const math = @import("math");

pub const Vec3 = math.Vec3;
pub const Quat = math.Quat;

pub const MovementDirection = enum {
    // Translation relative to the current axes.
    Forward,
    Backward,
    Left,
    Right,
    Up,
    Down,
    // Rotation about the movement’s own axes.
    RotateRight,
    RotateLeft,
    RotateUp,
    RotateDown,
    RollRight,
    RollLeft,
    // Movements that depend on a target.
    RadiusIn,
    RadiusOut,
    OrbitUp,
    OrbitDown,
    OrbitLeft,
    OrbitRight,
};

/// - `moveSpeed` is in world-units per second.
/// - `rotationSpeed` is in degrees per second for in-place rotations.
/// - `orbitSpeed` is in degrees per second for orbit movements.
pub const Movement = struct {
    /// World position.
    position: Vec3,
    /// Orientation as a quaternion.
    rotation: Quat,
    /// The target point used for orbit and radial movements.
    target: Vec3,
    /// Cached axes derived from the current rotation.
    forward: Vec3,
    up: Vec3,
    right: Vec3,
    direction: MovementDirection = .Forward,
    move_speed: f32 = 10.0,
    rotation_speed: f32 = 10.0,
    orbit_speed: f32 = 10.0,

    const Self = @This();

    /// Initialize with a starting position, rotation, and target.
    /// The target can default to the origin.
    pub fn init(position: Vec3, rotation: Quat, target: Vec3) Movement {
        var m = Movement{
            .position = position,
            .rotation = rotation,
            .target = target,
            .forward = Vec3.init(0, 0, -1),
            .up = Vec3.init(0, 1, 0),
            .right = Vec3.init(1, 0, 0),
        };
        m.updateAxes();
        return m;
    }

    pub fn reset(self: *Self, position: Vec3, rotation: Quat, target: Vec3) void {
        self.position = position;
        self.rotation = rotation;
        self.target = target;
        self.updateAxes();
    }

    /// Recalculate the forward/up/right axes from the current rotation.
    pub fn updateAxes(self: *Movement) void {
        // Assume Quat.toAxes() returns an array of three Vec4 values:
        // axes[0]: right, axes[1]: up, axes[2]: forward.
        // Use a helper method (xyz()) to convert a Vec4 to Vec3.
        const axes = self.rotation.toAxes();
        self.right = axes[0].xyz();
        self.up = axes[1].xyz();
        self.forward = axes[2].xyz();
    }

    /// Translate the position by an offset.
    pub fn translate(self: *Movement, offset: Vec3) void {
        self.position = self.position.add(&offset);
    }

    /// Rotate the movement by a quaternion delta.
    pub fn rotate(self: *Movement, delta: Quat) void {
        // Multiply delta on the left. (Check your convention!)
        self.rotation = Quat.mulQuat(&delta, &self.rotation);
        self.rotation.normalize();
        self.updateAxes();
    }

    /// Process a movement command that covers translation, rotation,
    /// and target-based (orbit and radial) movements.
    pub fn processMovement(
        self: *Movement,
        direction: MovementDirection,
        delta_time: f32,
    ) void {
        self.direction = direction;
        const translationVelocity = self.move_speed * delta_time;
        // For in-place rotations:
        const rotAngle = math.degreesToRadians(self.rotation_speed * delta_time);
        // For orbit rotations:
        const orbitAngle = math.degreesToRadians(self.orbit_speed * delta_time);
        switch (direction) {
            // Translation along the current axes.
            .Forward => {
                // Optionally use a scaling factor (0.2) if desired.
                self.position = self.position.add(&self.forward.mulScalar(translationVelocity * 0.2));
            },
            .Backward => {
                self.position = self.position.sub(&self.forward.mulScalar(translationVelocity * 0.2));
            },
            .Left => {
                self.position = self.position.sub(&self.right.mulScalar(translationVelocity));
            },
            .Right => {
                self.position = self.position.add(&self.right.mulScalar(translationVelocity));
            },
            .Up => {
                self.position = self.position.add(&self.up.mulScalar(translationVelocity));
            },
            .Down => {
                self.position = self.position.sub(&self.up.mulScalar(translationVelocity));
            },
            // In-place rotations.
            .RotateRight => {
                const rot = Quat.fromAxisAngle(&self.up, -rotAngle);
                self.rotate(rot);
            },
            .RotateLeft => {
                const rot = Quat.fromAxisAngle(&self.up, rotAngle);
                self.rotate(rot);
            },
            .RotateUp => {
                const rot = Quat.fromAxisAngle(&self.right, rotAngle);
                self.rotate(rot);
            },
            .RotateDown => {
                const rot = Quat.fromAxisAngle(&self.right, -rotAngle);
                self.rotate(rot);
            },
            .RollRight => {
                const rot = Quat.fromAxisAngle(&self.forward, rotAngle);
                self.rotate(rot);
            },
            .RollLeft => {
                const rot = Quat.fromAxisAngle(&self.forward, -rotAngle);
                self.rotate(rot);
            },
            // Target-based movements.
            // Radial movement: move in/out along the vector from the position to the target.
            .RadiusIn => {
                const dir = self.target.sub(&self.position).normalize();
                self.position = self.position.add(&dir.mulScalar(translationVelocity));
            },
            .RadiusOut => {
                const dir = self.target.sub(&self.position).normalize();
                self.position = self.position.sub(&dir.mulScalar(translationVelocity));
            },
            // Orbit movements: rotate the position around the target.
            .OrbitRight => {
                const rot = Quat.fromAxisAngle(&self.up, orbitAngle);
                const offset = self.position.sub(&self.target);
                const rotated_offset = rot.rotateVec(&offset);
                self.position = self.target.add(&rotated_offset);
                // Optionally update the rotation to face the target.
                self.updateAxes();
            },
            .OrbitLeft => {
                const rot = Quat.fromAxisAngle(&self.up, -orbitAngle);
                const offset = self.position.sub(&self.target);
                const rotated_offset = rot.rotateVec(&offset);
                self.position = self.target.add(&rotated_offset);
                self.updateAxes();
            },
            .OrbitUp => {
                const rot = Quat.fromAxisAngle(&self.right, -orbitAngle);
                const offset = self.position.sub(&self.target);
                const rotated_offset = rot.rotateVec(&offset);
                self.position = self.target.add(&rotated_offset);
                self.updateAxes();
            },
            .OrbitDown => {
                const rot = Quat.fromAxisAngle(&self.right, orbitAngle);
                const offset = self.position.sub(&self.target);
                const rotated_offset = rot.rotateVec(&offset);
                self.position = self.target.add(&rotated_offset);
                self.updateAxes();
            },
        }
    }
};
