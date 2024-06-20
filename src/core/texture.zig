const std = @import("std");
const zstbi = @import("zstbi");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;

const Allocator = std.mem.Allocator;

pub const TextureFilter = enum {
    Linear,
    Nearest,
};

pub const TextureWrap = enum {
    Clamp,
    Repeat,
};

pub const TextureType = enum(u32) {
    None = 0,
    Diffuse = 1,
    Specular = 2,
    Ambient = 3,
    Emissive = 4,
    Height = 5,
    Normals = 6,
    Shininess = 7,
    Opacity = 8,
    Displacement = 9,
    Lightmap = 10,
    Reflection = 11,
    BaseColor = 12,
    NormalCamera = 13,
    EmissionColor = 14,
    Metalness = 15,
    DiffuseRoughness = 16,
    AmbientOcclusion = 17,
    Unknown = 18,
    Sheen = 19,
    ClearCoat = 20,
    Transmission = 21,
    Force32bit = 2147483647,

    pub fn toString(self: *TextureType) []const u8 {
        const name = switch (self.*) {
            TextureType.Diffuse => "texture_diffuse",
            TextureType.Specular => "texture_specular",
            TextureType.Ambient => "texture_ambient",
            TextureType.Emissive => "texture_emissive",
            TextureType.Normals => "texture_normal",
            TextureType.Height => "texture_height",
            TextureType.Shininess => "texture_shininess",
            TextureType.Opacity => "texture_opacity",
            TextureType.Displacement => "texture_displacement",
            TextureType.Lightmap => "texture_lightmap",
            TextureType.Reflection => "texture_reflection",
            TextureType.BaseColor => "texture_basecolor",
            TextureType.Unknown => "texture_unknown",
            TextureType.None => "texture_none",
            TextureType.NormalCamera => "texture_normalcamera",
            TextureType.EmissionColor => "texture_emissioncolor",
            TextureType.Metalness => "texture_metalness",
            TextureType.DiffuseRoughness => "texture_roughness",
            TextureType.AmbientOcclusion => "texture_ambientocclusion",
            TextureType.Sheen => "texture_sheen",
            TextureType.ClearCoat => "texture_clearcoat",
            TextureType.Transmission => "texture_transmission",
            TextureType.Force32bit => "texture_force32bit",
        };
        return name;
    }
};

pub const TextureConfig = struct {
    texture_type: TextureType,
    filter: TextureFilter,
    wrap: TextureWrap,
    flip_v: bool,
    // flip_h: bool,
    gamma_correction: bool,

    const Self = @This();

    pub fn default() TextureConfig {
        return .{
            .texture_type = .Diffuse,
            .filter = .Linear,
            .wrap = .Clamp,
            .flip_v = true,
            .gamma_correction = false,
        };
    }

    pub fn new(texture_type: TextureType) TextureConfig {
        return .{
            .texture_type = texture_type,
            .filter = .Linear,
            .wrap = .Clamp,
            .flip_v = true,
            .gamma_correction = false,
        };
    }

    pub fn set_wrap(self: *Self, wrap_type: TextureWrap) void {
        self.wrap = wrap_type;
    }
};

pub const Texture = struct {
    id: u32,
    texture_path: []const u8,
    texture_type: TextureType,
    width: u32,
    height: u32,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn deinit(self: *const Texture) void {
        self.allocator.free(self.texture_path);
    }

    pub fn new(allocator: std.mem.Allocator, path: []const u8, texture_config: TextureConfig) !Texture {
        zstbi.init(allocator);
        defer zstbi.deinit();

        zstbi.setFlipVerticallyOnLoad(texture_config.flip_v);

        const c_path: [:0]const u8 = try allocator.dupeZ(u8, path);
        defer allocator.free(c_path);

        var image = zstbi.Image.loadFromFile(c_path, 0) catch |err| {
            std.debug.print("Texture loadFromFile error: {any}  filepath: {s}\n", .{err, path});
            @panic(@errorName(err));
        };
        defer image.deinit();

        const format: u32 = switch (image.num_components) {
            0 => gl.RED,
            3 => gl.RGB,
            4 => gl.RGBA,
            else => gl.RED,
        };

        var texture_id: gl.Uint = undefined;

        // std.debug.print("Texture: generating a texture\n", .{});
        gl.genTextures(1, &texture_id);

        // std.debug.print("Texture: binding a texture\n", .{});
        gl.bindTexture(gl.TEXTURE_2D, texture_id);

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

        const wrap_param: i32 = switch (texture_config.wrap) {
            TextureWrap.Clamp => gl.CLAMP_TO_EDGE,
            TextureWrap.Repeat => gl.REPEAT,
        };

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_param);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_param);

        if (texture_config.filter == TextureFilter.Linear) {
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        } else {
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
            gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
        }

        // std.debug.print("Texture: returning texture\n", .{});
        return Texture{
            .id = texture_id,
            .texture_path = try allocator.dupe(u8, path),
            .texture_type = texture_config.texture_type,
            .width = image.width,
            .height = image.height,
            .allocator = allocator,
        };
    }
};
