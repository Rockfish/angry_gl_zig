const std = @import("std");
const core = @import("core");
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const utils = core.utils;
const Gltf = @import("zgltf/src/main.zig");

const Allocator = std.mem.Allocator;

// pub const TextureFilter = enum {
//     Linear,
//     Nearest,
// };
//
// pub const TextureWrap = enum {
//     Clamp,
//     Repeat,
// };
//
// pub const TextureConfig = struct {
//     // texture_type: TextureType,
//     filter: TextureFilter,
//     wrap: TextureWrap,
//     flip_v: bool,
//     // flip_h: bool,
//     gamma_correction: bool,
//
//     const Self = @This();
//
//     pub fn default() TextureConfig {
//         return .{
//             .texture_type = .Diffuse,
//             .filter = .Linear,
//             .wrap = .Clamp,
//             .flip_v = true,
//             .gamma_correction = false,
//         };
//     }
//
//     pub fn init(flip_v: bool) TextureConfig {
//         return .{
//             // .texture_type = texture_type,
//             .filter = .Linear,
//             .wrap = .Clamp,
//             .flip_v = flip_v,
//             .gamma_correction = false,
//         };
//     }
//
//     pub fn set_wrap(self: *Self, wrap_type: TextureWrap) void {
//         self.wrap = wrap_type;
//     }
// };

pub const Texture = struct {
    id: u32,
    texture_path: [:0]const u8,
    // texture_type: TextureType,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *const Texture) void {
        // todo: delete texture from gpu
        self.allocator.free(self.texture_path);
        self.allocator.destroy(self);
    }

    pub fn init(allocator: std.mem.Allocator, gltf: *Gltf, texture_index: usize, directory: []const u8) !*Texture {
        zstbi.init(allocator);
        defer zstbi.deinit();

        // GLTF defines UV coordinates with a top-left origin
        // OpenGL assumes texture coordinates have a bottom-left origin
        zstbi.setFlipVerticallyOnLoad(true);

        const gltf_texture = gltf.data.textures.items[texture_index];
        const source_id = gltf_texture.source orelse std.debug.panic("texture.source null not supported yet.", .{});
        const image_id = gltf.data.images.items[source_id];
        const uri = image_id.uri orelse std.debug.panic("image.uri null not supported yet.", .{});

        const c_path = try std.fs.path.joinZ(allocator, &[_][]const u8{ directory, uri });

        // var buf: [256]u8 = undefined;
        // const c_path = utils.bufCopyZ(&buf, path);

        std.debug.print("Loading texture: {s}\n", .{c_path});

        var image = zstbi.Image.loadFromFile(c_path, 0) catch |err| {
            std.debug.print("Texture loadFromFile error: {any}  filepath: {s}\n", .{ err, c_path });
            @panic(@errorName(err));
        };
        defer image.deinit();

        const format: u32 = switch (image.num_components) {
            0 => gl.RED,
            3 => gl.RGB,
            4 => gl.RGBA,
            else => gl.RED,
        };

        var gl_texture_id: gl.Uint = undefined;

        gl.genTextures(1, &gl_texture_id);
        gl.bindTexture(gl.TEXTURE_2D, gl_texture_id);

        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            format,
            @intCast(image.width),
            @intCast(image.height),
            0,
            format,
            gl.UNSIGNED_BYTE,
            image.data.ptr,
        );

        gl.generateMipmap(gl.TEXTURE_2D);

        const sampler = blk: {
            if (gltf_texture.sampler) |sampler_id| {
                break :blk gltf.data.samplers.items[sampler_id];
            } else {
                break :blk Gltf.TextureSampler{};
            }
        };

        std.debug.print("texture sampler: {any}\n", .{sampler});

        const wrap_s: i32 = switch (sampler.wrap_s) {
            Gltf.WrapMode.clamp_to_edge => gl.CLAMP_TO_EDGE,
            Gltf.WrapMode.repeat => gl.REPEAT,
            Gltf.WrapMode.mirrored_repeat => gl.MIRRORED_REPEAT,
        };

        const wrap_t: i32 = switch (sampler.wrap_t) {
            Gltf.WrapMode.clamp_to_edge => gl.CLAMP_TO_EDGE,
            Gltf.WrapMode.repeat => gl.REPEAT,
            Gltf.WrapMode.mirrored_repeat => gl.MIRRORED_REPEAT,
        };

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_s);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_t);

        const min_filter: gl.Int = blk: {
            if (sampler.min_filter) |filter| {
                break :blk switch (filter) {
                    Gltf.MinFilter.nearest => gl.NEAREST,
                    Gltf.MinFilter.linear => gl.LINEAR,
                    Gltf.MinFilter.nearest_mipmap_nearest => gl.NEAREST_MIPMAP_NEAREST,
                    Gltf.MinFilter.nearest_mipmap_linear => gl.NEAREST_MIPMAP_LINEAR,
                    Gltf.MinFilter.linear_mipmap_nearest => gl.LINEAR_MIPMAP_NEAREST,
                    Gltf.MinFilter.linear_mipmap_linear => gl.LINEAR_MIPMAP_LINEAR,
                };
            } else {
                break :blk gl.LINEAR;
            }
        };

        const mag_filter: gl.Int = blk: {
            if (sampler.mag_filter) |filter| {
                break :blk switch (filter) {
                    Gltf.MagFilter.nearest => gl.NEAREST,
                    Gltf.MagFilter.linear => gl.LINEAR,
                };
            } else {
                break :blk gl.LINEAR;
            }
        };

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, min_filter);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, mag_filter);

        const texture = try allocator.create(Texture);
        texture.* = Texture{
            .id = @intCast(gl_texture_id),
            .texture_path = c_path,
            // .texture_type = texture_config.texture_type,
            .width = image.width,
            .height = image.height,
            .allocator = allocator,
        };
        return texture;
    }

    pub fn clone(self: *const Self) !*Texture {
        const texture = try self.allocator.create(Texture);
        texture.* = Texture{
            .id = self.id,
            .texture_path = try self.allocator.dupe(u8, self.texture_path),
            .texture_type = self.texture_type,
            .width = self.width,
            .height = self.height,
            .allocator = self.allocator,
        };
        return texture;
    }
};
