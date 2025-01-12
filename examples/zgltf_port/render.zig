const std = @import("std");
const gl = @import("zopengl").bindings;
const core = @import("core");
const Shader = core.Shader;
const Texture = core.texture.Texture;
const utils = core.utils;
const math = @import("math");

const Gltf = @import("zgltf/src/main.zig");

pub fn setShaderUniforms(
    gltf: *Gltf,
    shader: Shader,
    material: Gltf.Material,
    modelMatrix: [16]f32,
    viewMatrix: [16]f32,
    projMatrix: [16]f32,
    lightPos: [3]f32,
    viewPos: [3]f32,
) !void {
    gl.UseProgram(shader);

    shader.set_vec3("lightPosition", &lightPos);
    shader.set_vec3("viewPosition", &viewPos);
    shader.set_mat4("viewMatrix", &viewMatrix);
    shader.set_mat4("projMatrix", &projMatrix);
    shader.set_mat4("modelMatrix", &modelMatrix);

    // Base Color
    if (material.baseColorFactor) |baseColorFactor| {
        shader.set_vec4("material.baseColorFactor", &baseColorFactor);
    } else {
        shader.set_4float("material.baseColorFactor", &[4]f32{ 1.0, 1.0, 1.0, 1.0 });
    }

    shader.set_float("material.metallicFactor", material.metallicFactor orelse 1.0);
    shader.set_float("material.roughnessFactor", material.roughnessFactor orelse 1.0);

    if (material.emissive_factor) |emissiveFactor| {
        shader.set_vec3("material.emissiveFactor", &emissiveFactor);
    } else {
        shader.set_3float("material.emissiveFactor", &[3]f32{ 0.0, 0.0, 0.0 });
    }

    if (material.pbr_metallic_roughness.base_color_texture) |baseColorTexture| {
        const texUnit = 0;
        const texture = gltf.loaded_textures.get(baseColorTexture.index) orelse std.debug.panic("texture not loaded.", .{});
        shader.bind_texture(texUnit, "baseColorTexture", texture);
    }

    if (material.pbr_metallic_roughness.metallic_roughness_texture) |metallicRoughnessTexture| {
        const texUnit = 1;
        const texture = gltf.loaded_textures.get(metallicRoughnessTexture.index) orelse std.debug.panic("texture not loaded.", .{});
        shader.bind_texture(texUnit, "metallicRoughnessTexture", texture);
    }

    if (material.normal_texture) |normalTexture| {
        const texUnit = 2;
        const texture = gltf.loaded_textures.get(normalTexture.index) orelse std.debug.panic("texture not loaded.", .{});
        shader.bind_texture(texUnit, "normalTexture", texture);
    }

    if (material.emissive_texture) |emissiveTexture| {
        const texUnit = 3;
        const texture = gltf.loaded_textures.get(emissiveTexture.index) orelse std.debug.panic("texture not loaded.", .{});
        shader.bind_texture(texUnit, "emissiveTexture", texture);
    }

    if (material.occlusion_texture) |occlusionTexture| {
        const texUnit = 4;
        const texture = gltf.loaded_textures.get(occlusionTexture.index) orelse std.debug.panic("texture not loaded.", .{});
        shader.bind_texture(texUnit, "occlusionTexture", texture);
    }
}
