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

pub fn screen_to_model_glam(
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
    const ndc = Vec4.new(ndc_x, ndc_y, ndc_z, 1.0);

    // debug!("ndc: {:?}", ndc);

    // Convert NDC to clip space (inverse projection matrix)
    const clip_space = projection_matrix.inverse() * ndc;

    // Convert clip space to eye space (w-divide)
    const eye_space = Vec4.new(clip_space.x / clip_space.w, clip_space.y / clip_space.w, -1.0, 0.0);
    // const eye_space = clip_space / clip_space.w;

    // Convert eye space to world space (inverse view matrix)
    const world_space = view_matrix.inverse() * eye_space;

    return Vec3.new(world_space.x, world_space.y, world_space.z);
}

pub fn get_world_ray_from_mouse(
    mouse_x: f32,
    mouse_y: f32,
    viewport_width: f32,
    viewport_height: f32,
    view_matrix: *Mat4,
    projection: *Mat4,
) Vec3 {
    // normalize device coordinates
    const ndc_x = (2.0 * mouse_x) / viewport_width - 1.0;
    const ndc_y = 1.0 - (2.0 * mouse_y) / viewport_height;
    const ndc_z = -1.0; // face the same direction as the opengl camera
    const ndc = Vec4.new(ndc_x, ndc_y, ndc_z, 1.0);

    const projection_inverse = projection.inverse();
    const view_inverse = view_matrix.inverse();

    // eye space
    var ray_eye = projection_inverse * ndc;
    ray_eye = vec4(ray_eye.x, ray_eye.y, -1.0, 0.0);

    // world space
    const ray_world = (view_inverse * ray_eye).xyz();

    // ray from camera
    return ray_world.normalize_or_zero();
}

pub fn ray_plane_intersection(ray_origin: Vec3, ray_direction: Vec3, plane_point: Vec3, plane_normal: Vec3) ?Vec3 {
    const denom = plane_normal.dot(ray_direction);
    if (denom.abs() > epsilon) {
        const p0l0 = plane_point - ray_origin;
        const t = p0l0.dot(plane_normal) / denom;
        if (t >= 0.0) {
            return ray_origin + t * ray_direction;
        }
    }
    return null;
}
