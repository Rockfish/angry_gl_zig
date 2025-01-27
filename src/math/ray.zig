const std = @import("std");
const cglm = @import("cglm.zig").CGLM;
const _vec = @import("vec.zig");
const _quat = @import("quat.zig");

const Vec3 = _vec.Vec3;
const Vec4 = _vec.Vec4;
const Quat = _quat.Quat;

/// Möller–Trumbore ray-triangle intersection algorithm
/// @param[in] origin         origin of ray
/// @param[in] direction      direction of ray
/// @param[in] v0             first vertex of triangle
/// @param[in] v1             second vertex of triangle
/// @param[in] v2             third vertex of triangle
/// @param[return] ?d         distance to intersection if there is intersection
pub fn getRayTriangleIntersection(origin: *const Vec3, direction: *const Vec3, vert0: *const Vec3, vert1: *const Vec3, vert2: *const Vec3) ?f32 {
    var distance: f32 = undefined;
    const found = cglm.glmc_ray_triangle(
        @as([*c]f32, @ptrCast(@constCast(origin))),
        @as([*c]f32, @ptrCast(@constCast(direction))),
        @as([*c]f32, @ptrCast(@constCast(vert0))),
        @as([*c]f32, @ptrCast(@constCast(vert1))),
        @as([*c]f32, @ptrCast(@constCast(vert2))),
        &distance,
    );
    return if (found) distance else null;
}

/// @brief ray sphere intersection
///
/// returns false if there is no intersection if true:
///
/// - t1 > 0, t2 > 0: ray intersects the sphere at t1 and t2 both ahead of the origin
/// - t1 < 0, t2 > 0: ray starts inside the sphere, exits at t2
/// - t1 < 0, t2 < 0: no intersection ahead of the ray ( returns false )
/// - the caller can check if the intersection points (t1 and t2) fall within a
///   specific range (for example, tmin < t1, t2 < tmax) to determine if the
///   intersections are within a desired segment of the ray
///
/// @param[in]  origin ray origin
/// @param[out] dir    normalized ray direction
/// @param[in]  s      sphere  [center.x, center.y, center.z, radii]
/// @param[in]  t1     near point1 (closer to origin)
/// @param[in]  t2     far point2 (farther from origin)
///
/// @returns whether there is intersection
///
pub fn getRaySphereIntersection(origin: *const Vec3, direction: *const Vec3, sphere: Vec4, t1: f32, t2: f32) bool {
    // hmm, don't
    const found = cglm.glmc_ray_sphere(
        @as([*c]f32, @ptrCast(@constCast(origin))),
        @as([*c]f32, @ptrCast(@constCast(direction))),
        @as([*c]f32, @ptrCast(@constCast(sphere))),
        t1,
        t2,
    );
    return found;
}
