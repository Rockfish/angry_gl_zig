const std = @import("std");
const vec = @import("vec.zig");
const mat4_ = @import("mat4.zig");
const quat_ = @import("quat.zig");

pub const Vec2 = vec.Vec2;
pub const Vec3 = vec.Vec3;
pub const Vec4 = vec.Vec4;

pub const vec2 = vec.vec2;
pub const vec3 = vec.vec3;
pub const vec4 = vec.vec4;

pub const Mat4 = mat4_.Mat4;
pub const Quat = quat_.Quat;

pub const epsilon: f32 = 1.19209290e-07;

pub fn screenToModelGlam(
    mouse_x: f32,
    mouse_y: f32,
    viewport_width: f32,
    viewport_height: f32,
    view_matrix: *Mat4,
    projection_matrix: *Mat4,
) Vec3 {
    // Convert screen coordinates to normalized device coordinates

    const ndc_x = (2.0 * mouse_x) / viewport_width - 1.0;
    const ndc_y = 1.0 - (2.0 * mouse_y) / viewport_height;
    const ndc_z = 0.7345023; // 1.0; // Assuming the point is on the near plane
    const ndc = Vec4.init(ndc_x, ndc_y, ndc_z, 1.0);

    // debug!("ndc: {:?}", ndc);

    // Convert NDC to clip space (inverse projection matrix)
    const clip_space = projection_matrix.inverse() * ndc;

    // Convert clip space to eye space (w-divide)
    const eye_space = Vec4.init(clip_space.x / clip_space.w, clip_space.y / clip_space.w, -1.0, 0.0);
    // const eye_space = clip_space / clip_space.w;

    // Convert eye space to world space (inverse view matrix)
    const world_space = view_matrix.inverse() * eye_space;

    return Vec3.init(world_space.x, world_space.y, world_space.z);
}

pub fn getWorldRayFromMouse(
    viewport_width: f32,
    viewport_height: f32,
    projection: *const Mat4,
    view_matrix: *const Mat4,
    mouse_x: f32,
    mouse_y: f32,
) Vec3 {

    // normalize device coordinates
    const ndc_x = (2.0 * mouse_x) / viewport_width - 1.0;
    const ndc_y = 1.0 - (2.0 * mouse_y) / viewport_height;
    const ndc_z = -1.0; // face the same direction as the opengl camera
    const ndc = Vec4.init(ndc_x, ndc_y, ndc_z, 1.0);

    const projection_inverse = projection.getInverse();
    const view_inverse = view_matrix.getInverse();

    // eye space
    var ray_eye = projection_inverse.mulVec4(&ndc);
    ray_eye = vec4(ray_eye.x, ray_eye.y, -1.0, 0.0);

    // world space
    const ray_world = (view_inverse.mulVec4(&ray_eye)).xyz();

    // ray from camera
    const ray_normalized = ray_world.normalizeTo();

    return ray_normalized;
}

pub fn getRayPlaneIntersection(
    ray_origin: *const Vec3,
    ray_direction: *const Vec3,
    plane_point: *const Vec3,
    plane_normal: *const Vec3,
) ?Vec3 {
    const denom = plane_normal.dot(ray_direction);
    if (@abs(denom) > epsilon) {
        const p0l0 = plane_point.sub(ray_origin);
        const t = p0l0.dot(plane_normal) / denom;
        if (t >= 0.0) {
            return ray_origin.add(&ray_direction.mulScalar(t));
        }
    }
    return null;
}

pub fn calculateNormal(a: Vec3, b: Vec3, c: Vec3) Vec3 {
    // Calculate vectors AB and AC
    const ab = Vec3{
        .x = b.x - a.x,
        .y = b.y - a.y,
        .z = b.z - a.z,
    };
    const ac = Vec3{
        .x = c.x - a.x,
        .y = c.y - a.y,
        .z = c.z - a.z,
    };

    // Compute the cross product of AB and AC to get the normal
    const normal = ab.cross(&ac);

    // Normalize the resulting normal vector
    return normal.normalizeTo();
}

test "utils.get_world_ray_from_mouse" {
    const mouse_x = 1117.3203;
    const mouse_y = 323.6797;
    const width = 1500.0;
    const height = 1000.0;

    const view_matrix = Mat4.fromColumns(
        vec4(0.345086, 0.64576554, -0.68110394, 0.0),
        vec4(0.3210102, 0.6007121, 0.7321868, 0.0),
        vec4(0.8819683, -0.47130874, -0.0, 0.0),
        vec4(1.1920929e-7, -0.0, -5.872819, 1.0),
    );

    const projection = Mat4.fromColumns(
        vec4(1.6094756, 0.0, 0.0, 0.0),
        vec4(0.0, 2.4142134, 0.0, 0.0),
        vec4(0.0, 0.0, -1.002002, -1.0),
        vec4(0.0, 0.0, -0.2002002, 0.0),
    );

    const ray = getWorldRayFromMouse(
        width,
        height,
        &projection,
        &view_matrix,
        mouse_x,
        mouse_y,
    );

    std.debug.print("ray = {any}", .{ray});
}
