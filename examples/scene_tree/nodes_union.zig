const std = @import("std");
const assert = std.debug.assert;
const math = @import("math");
const core = @import("core");
const Transform = @import("core").Transform;
const Shader = @import("core").Shader;
const State = @import("main.zig").State;
const Model = @import("core").Model;

const Allocator = std.mem.Allocator;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub const BasicObj = struct {
    name: []const u8,
    transform: Transform,
    global_transform: Transform,

    pub fn init(name: []const u8) BasicObj {
        return .{
            .name = name,
            .transform = Transform.default(),
            .global_transform = Transform.default(),
        };
    }
};

pub const CubeObj = struct {
    name: []const u8,
    cube: *core.shapes.Cubeboid,
    texture: *core.texture.Texture,
    transform: Transform,
    global_transform: Transform,
    // texture
 
    pub fn init(cube: *core.shapes.Cubeboid, name: []const u8, texture: *core.texture.Texture) CubeObj {
        return .{
            .name = name,
            .cube = cube,
            .texture = texture,
            .transform = Transform.default(),
            .global_transform = Transform.default(),
        };
    }

    pub fn render(self: *CubeObj, shader: *Shader) void {
        shader.bind_texture(0, "texture_diffuse", self.texture);
        self.cube.render();
    }
};

pub const CylinderObj = struct {
    name: []const u8,
    cylinder: *core.shapes.Cylinder,
    texture: *core.texture.Texture,
    transform: Transform,
    global_transform: Transform,
    // texture
 
    pub fn init(cylinder: *core.shapes.Cylinder, name: []const u8, texture: *core.texture.Texture) CylinderObj {
        return .{
            .name = name,
            .cylinder = cylinder,
            .texture = texture,
            .transform = Transform.default(),
            .global_transform = Transform.default(),
        };
    }
    pub fn render(self: *CylinderObj, shader: *Shader) void {
        shader.bind_texture(0, "texture_diffuse", self.texture);
        self.cylinder.render();
    }
};

pub const ModelObj = struct {
    name: []const u8,
    model: *Model,
    transform: Transform,
    global_transform: Transform,

    pub fn init(model: *Model, name: []const u8) ModelObj {
        return .{
            .name = name,
            .model = model,
            .transform = Transform.default(),
            .global_transform = Transform.default(),
        };
    }

    pub fn render(self: *ModelObj, shader: *Shader) void {
        self.model.render(shader);
    }
};

pub const Object = union(enum) {
    basic: *BasicObj,
    cube: *CubeObj,
    cylinder: *CylinderObj,
    model: *ModelObj,

    inline fn calcTransform(actor: Object, transform: Transform) Transform {
        // return switch(actor) {
        //     .basic => |obj| obj.transform.mul_transform(transform),
        //     .cube => |obj| obj.transform.mul_transform(transform),
        //     .cylinder => |obj| obj.transform.mul_transform(transform),
        //     .model => |obj| obj.transform.mul_transform(transform),
        // };
        return switch(actor) {
            inline else => |obj| obj.transform.mul_transform(transform),
        };
    } 

    inline fn setTransform(actor: Object, transform: Transform) void {
        // return switch(actor) {
        //     .basic => |obj| obj.transform = transform,
        //     .cube => |obj| obj.transform = transform,
        //     .cylinder => |obj| obj.transform = transform,
        //     .model => |obj| obj.transform = transform,
        // };
        return switch(actor) {
            inline else => |obj| obj.transform = transform,
        };
    }

    inline fn getTransform(actor: Object) Transform {
        // return switch(actor) {
        //     .basic => |obj| obj.transform,
        //     .cube => |obj| obj.transform,
        //     .cylinder => |obj| obj.transform,
        //     .model => |obj| obj.transform,
        // };
        return switch(actor) {
            inline else => |obj| obj.transform,
        };
    }

    inline fn render(actor: Object, shader: *Shader) void {
        // return switch(actor) {
        //     .basic => {},
        //     .cube => |obj| obj.render(shader),
        //     .cylinder => |obj| obj.render(shader),
        //     .model => |obj| obj.render(shader),
        // };
        return switch(actor) {
            .basic => {},
            inline else => |obj| obj.render(shader),
        };
    }

    inline fn updateAnimation(actor: Object, delta_time: f32) void {
        switch (actor) {
            .model => |obj| obj.updateAnimation(delta_time),
            else => {},
        }
    }
};

pub const NodeObj = struct {
    allocator: Allocator,
    name: []const u8,
    object: Object,
    transform: Transform,
    global_transform: Transform,
    parent: ?*NodeObj,
    children: std.ArrayList(*NodeObj),

    pub fn init(allocator: Allocator, name: []const u8, object: Object) !*NodeObj {
        const node_obj = try allocator.create(NodeObj);
        node_obj.* = .{
            .allocator = allocator,
            .name = name,
            .object = object,
            .transform = object.getTransform(),
            .global_transform = Transform.default(),
            .parent = null,
            .children = std.ArrayList(*NodeObj).init(allocator),
        };
        return node_obj;
    }

    pub fn deinit(self: NodeObj) void {
        _ = self;
    }

    /// Add child
    pub fn addChild(self: *NodeObj, child: *NodeObj) !void {
        assert(self != child);
        if (child.parent) |p| {
            if (p == self) return;

            // Leave old parent
            for (p.children.items, 0..) |_c, idx| {
                if (_c == child) {
                    _ = p.children.swapRemove(idx);
                    break;
                }
            } else unreachable;
        }

        child.parent = self;
        try self.children.append(child);
        //child.updateTransforms();
    }

    /// Remove child
    pub fn removeChild(self: *NodeObj, child: *NodeObj) void {
        if (child.parent) |p| {
            if (p != self) return;

            for (self.children.items, 0..) |_c, idx| {
                if (_c == child) {
                    _ = self.children.swapRemove(idx);
                    break;
                }
            } else unreachable;

            child.parent = null;
        }
    }

    /// Remove itself from scene
    pub fn removeSelf(self: *NodeObj) void {
        if (self.parent) |p| {
            // Leave old parent
            for (p.children.items, 0..) |c, idx| {
                if (self == c) {
                    _ = p.children.swapRemove(idx);
                    break;
                }
            } else unreachable;

            self.parent = null;
        }
    }

    /// Update all objects' transform matrix in tree
    pub fn updateTransforms(self: *NodeObj, parent_transform: ?*Transform) void {
        if (parent_transform) |transform| {
            self.global_transform = transform.mul_transform(self.transform);
        } else {
            self.global_transform = self.transform;
        }

        for (self.children.items) |child| {
            child.updateTransforms(&self.global_transform);
        }
    }

    /// Change object's transform matrix, and update it's children accordingly
    pub fn setTransform(self: *NodeObj, transform: Transform) void {
        self.transform = transform;
        self.updateTransforms(null);
    }

    pub fn render(self: *NodeObj, shader: *Shader) void {
        const mat = self.global_transform.get_matrix();
        shader.set_mat4("model", &mat);
        self.object.render(shader);
        for (self.children.items) |child| {
            child.render(shader);
        }
    }

    pub fn updateAnimation(self: *NodeObj, delta_time: f32) void {
        self.object.updateAnimation(delta_time);
        for (self.children.items) |child| {
            child.updateAnimation(delta_time);
        }
    }

    // example of how to get the type from a union(enum)
    pub fn getModel(self: *NodeObj) !Model {
        if (self.object != .model) return error.TypeMismatch;
        return self.object.model;
    }
};


