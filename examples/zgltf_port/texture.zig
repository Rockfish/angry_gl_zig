const std = @import("std");
const core = @import("core");
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const utils = @import("utils.zig");
const Gltf = @import("zgltf/src/main.zig");

const Allocator = std.mem.Allocator;

pub const Texture = struct {
    gltf_texture_id: usize,
    gl_texture_id: u32,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *const Texture) void {
        // todo: delete texture from gpu
        // self.allocator.free(self.texture_path);
        self.allocator.destroy(self);
    }

    pub fn init(
        allocator: std.mem.Allocator,
        gltf: *Gltf,
        directory: []const u8,
        texture_index: usize,
    ) !*Texture {
        const gltf_texture = gltf.data.textures.items[texture_index];
        const source_id = gltf_texture.source orelse std.debug.panic("texture.source null not supported.", .{});
        const gltf_image = gltf.data.images.items[source_id];

        zstbi.init(allocator);
        defer zstbi.deinit();

        // GLTF defines UV coordinates with a top-left origin
        // OpenGL assumes texture coordinates have a bottom-left origin
        // So always flip vertical
        // zstbi.setFlipVerticallyOnLoad(true);  // hmm, except not for CesiumMan

        var image = loadImage(allocator, gltf, gltf_image, directory);
        defer image.deinit();

        const sampler = blk: {
            if (gltf_texture.sampler) |sampler_id| {
                break :blk gltf.data.samplers.items[sampler_id];
            } else {
                break :blk Gltf.TextureSampler{};
            }
        };

        const gl_texture_id = createGlTexture(image, sampler);

        const texture = try allocator.create(Texture);
        texture.* = Texture{
            .gltf_texture_id = texture_index,
            .gl_texture_id = @intCast(gl_texture_id),
            .width = image.width,
            .height = image.height,
            .allocator = allocator,
        };
        return texture;
    }

    pub fn clone(self: *const Self) !*Texture {
        const texture = try self.allocator.create(Texture);
        texture.* = Texture{
            .gltf_texture_id = self.gltf_texture_id,
            .gl_texture_id = self.gl_texture_id,
            .width = self.width,
            .height = self.height,
            .allocator = self.allocator,
        };
        return texture;
    }
};

pub fn loadImage(allocator: Allocator, gltf: *Gltf, gltf_image: Gltf.Image, directory: []const u8) zstbi.Image {
    if (gltf_image.uri) |uri| {
        if (std.mem.eql(u8, uri[0..5], "data:")) {
            const comma = utils.strchr(uri, ',');
            if (comma) |idx| {
                const decoder = std.base64.standard.Decoder;
                const decoded_length = decoder.calcSizeForSlice(uri[idx..uri.len]) catch |err| {
                    std.debug.panic("Texture base64 decoder error: {any}\n", .{ err });
                };
                const data_buffer: []align(4) u8 = allocator.allocWithOptions(u8, decoded_length, 4, null) catch |err| {
                    std.debug.panic("Texture allocator error: {any}\n", .{ err });
                };
                decoder.decode(data_buffer, uri[idx..uri.len]) catch |err| {
                    std.debug.panic("Texture base64 decoder error: {any}\n", .{ err });
                };
                const image = zstbi.Image.loadFromMemory(data_buffer, 0) catch |err| {
                    std.debug.print("Texture loadFromMemory error: {any}  using uri: {any}\n", .{ err, uri[0..5] });
                    @panic(@errorName(err));
                };
                return image;
            }
            std.debug.panic("Texture uri malformed. uri: {any}", .{uri});
        } else {
            const c_path = std.fs.path.joinZ(allocator, &[_][]const u8{ directory, uri }) catch |err| {
                    std.debug.panic("Texture allocator error: {any}\n", .{ err });
                };
            defer allocator.free(c_path);
            std.debug.print("Loading texture: {s}\n", .{c_path});
            const image = zstbi.Image.loadFromFile(c_path, 0) catch |err| {
                std.debug.print("Texture loadFromFile error: {any}  filepath: {s}\n", .{ err, c_path });
                @panic(@errorName(err));
            };
            return image;
        }

    } else if (gltf_image.buffer_view) |buffer_view_id| {
        const buffer_view = gltf.data.buffer_views.items[buffer_view_id];
        const data = gltf.buffer_data.items[buffer_view.buffer][buffer_view.byte_offset..buffer_view.byte_length];
        const image = zstbi.Image.loadFromMemory(data, 0) catch |err| {
            std.debug.print("Texture loadFromMemory error: {any}  bufferview: {any}\n", .{ err, buffer_view });
            @panic(@errorName(err));
        };
        return image;

    } else {
        std.debug.panic("Gltf Image needs either a uri or a bufferview.", .{});
    }
}

pub fn createGlTexture( image: zstbi.Image, sampler: Gltf.TextureSampler) c_uint {

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

    return gl_texture_id;
}
