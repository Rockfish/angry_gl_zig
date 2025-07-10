const std = @import("std");
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
    const epsilon = 1e-8;

    // Calculate edge vectors
    const edge1 = vert1.sub(vert0);
    const edge2 = vert2.sub(vert0);

    // Calculate cross product of direction and edge2
    const h = direction.cross(&edge2);
    const a = edge1.dot(&h);

    // Ray is parallel to triangle
    if (@abs(a) < epsilon) {
        return null;
    }

    const f = 1.0 / a;
    const s = origin.sub(vert0);
    const u = f * s.dot(&h);

    // Check if intersection point is outside triangle
    if (u < 0.0 or u > 1.0) {
        return null;
    }

    const q = s.cross(&edge1);
    const v = f * direction.dot(&q);

    // Check if intersection point is outside triangle
    if (v < 0.0 or u + v > 1.0) {
        return null;
    }

    // Calculate t (distance along ray)
    const t = f * edge2.dot(&q);

    // Check if intersection is in front of ray origin
    if (t > epsilon) {
        return t;
    }

    return null;
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
    // Extract sphere center and radius
    const center = Vec3.init(sphere.x, sphere.y, sphere.z);
    const radius = sphere.w;

    // Calculate vector from ray origin to sphere center
    const oc = origin.sub(&center);

    // Quadratic equation coefficients: a*t^2 + b*t + c = 0
    const a = direction.dot(direction);
    const b = 2.0 * oc.dot(direction);
    const c = oc.dot(&oc) - radius * radius;

    // Calculate discriminant
    const discriminant = b * b - 4.0 * a * c;

    // No intersection if discriminant is negative
    if (discriminant < 0.0) {
        return false;
    }

    // Calculate the two intersection points
    const sqrt_discriminant = std.math.sqrt(discriminant);
    const t_near = (-b - sqrt_discriminant) / (2.0 * a);
    const t_far = (-b + sqrt_discriminant) / (2.0 * a);

    // Check if intersections are within the specified range
    if ((t_near >= t1 and t_near <= t2) or (t_far >= t1 and t_far <= t2)) {
        return true;
    }

    // Check if the ray segment is entirely inside the sphere
    if (t_near < t1 and t_far > t2) {
        return true;
    }

    return false;
}
