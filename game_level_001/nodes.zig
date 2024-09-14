const std = @import("std");
const assert = std.debug.assert;
const math = @import("math");
const core = @import("core");
const Transform = @import("core").Transform;
const Shader = @import("core").Shader;
const State = @import("main.zig").State;
const Model = @import("core").Model;
const AABB = @import("core").AABB;

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
    // transform: Transform,
    // global_transform: Transform,

    pub fn init(name: []const u8) BasicObj {
        return .{
            .name = name,
            // .transform = Transform.default(),
            // .global_transform = Transform.default(),
        };
    }
};

pub const ShapeObj = struct {
    name: []const u8,
    shape: *core.shapes.Shape,
    texture: *core.texture.Texture,
    // transform: Transform,
    // global_transform: Transform,
 
    pub fn init(shape: *core.shapes.Shape, name: []const u8, texture: *core.texture.Texture) ShapeObj {
        return .{
            .name = name,
            .shape = shape,
            .texture = texture,
            // .transform = Transform.default(),
            // .global_transform = Transform.default(),
        };
    }

    pub fn getBoundingBox(self: *ShapeObj) AABB {
        return self.shape.aabb;
    }

    pub fn render(self: *ShapeObj, shader: *Shader) void {
        shader.bind_texture(0, "texture_diffuse", self.texture);
        self.shape.render();
    }
};

pub const ModelObj = struct {
    name: []const u8,
    model: *Model,
    // transform: Transform,
    // global_transform: Transform,

    pub fn init(model: *Model, name: []const u8) ModelObj {
        return .{
            .name = name,
            .model = model,
            // .transform = Transform.default(),
            // .global_transform = Transform.default(),
        };
    }

    // pub fn getBoundingBox(self: *ModelObj) AABB {
    //     return self.model.aabb;
    // }

    pub fn render(self: *ModelObj, shader: *Shader) void {
        self.model.render(shader);
    }
};

pub const Object = union(enum) {
    basic: *BasicObj,
    shape: *ShapeObj,
    model: *ModelObj,

    pub inline fn calcTransform(actor: Object, transform: Transform) Transform {
        return switch(actor) {
            inline else => |obj| obj.transform.mul_transform(transform),
        };
    } 

    pub inline fn setTransform(actor: Object, transform: Transform) void {
        return switch(actor) {
            inline else => |obj| obj.transform = transform,
        };
    }

    pub inline fn getTransform(actor: Object) Transform {
        return switch(actor) {
            inline else => |obj| obj.transform,
        };
    }

    pub inline fn getBoundingBox(actor: Object) ?AABB {
        return switch(actor) {
            .basic => null,
            .model => null,
            inline else => |obj| obj.getBoundingBox(),
        };
    }

    pub inline fn render(actor: Object, shader: *Shader) void {
        return switch(actor) {
            .basic => {},
            inline else => |obj| obj.render(shader),
        };
    }

    pub inline fn updateAnimation(actor: Object, delta_time: f32) void {
        switch (actor) {
            .model => |obj| obj.updateAnimation(delta_time),
            else => {},
        }
    }
};

pub const Node = struct {
    allocator: Allocator,
    name: []const u8,
    object: Object,
    transform: Transform,
    global_transform: Transform,
    parent: ?*Node,
    children: std.ArrayList(*Node),

    pub fn init(allocator: Allocator, name: []const u8, object: Object) !*Node {
        const node = try allocator.create(Node);
        node.* = .{
            .allocator = allocator,
            .name = name,
            .object = object,
            .transform = Transform.default(), // object.getTransform(),
            .global_transform = Transform.default(),
            .parent = null,
            .children = std.ArrayList(*Node).init(allocator),
        };
        return node;
    }

    pub fn deinit(self: *Node) void {
        self.children.deinit();
        self.allocator.destroy(self);
    }

    /// Add child
    pub fn addChild(self: *Node, child: *Node) !void {
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
    pub fn removeChild(self: *Node, child: *Node) void {
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
    pub fn removeSelf(self: *Node) void {
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
    pub fn updateTransforms(self: *Node, parent_transform: ?*Transform) void {
        if (parent_transform) |transform| {
            self.global_transform = transform.mul_transform(self.transform);
        } else {
            self.global_transform = self.transform;
        }

        for (self.children.items) |child| {
            child.updateTransforms(&self.global_transform);
        }
    }

    pub fn setTransform(self: *Node, transform: Transform) void {
        self.transform = transform;
        self.updateTransforms(null);
    }

    pub fn setTranslation(self: *Node, translation: Vec3) void {
        self.transform.translation = translation;
        self.updateTransforms(null);
    }

    pub fn setRotation(self: *Node, rotation: Quat) void {
        self.transform.rotation = rotation;
        self.updateTransforms(null);
    }

    pub fn setScale(self: *Node, scale: Vec3) void {
        self.transform.scale = scale;
        self.updateTransforms(null);
    }

    pub fn render(self: *Node, shader: *Shader) void {
        const model_mat = self.global_transform.get_matrix();
        shader.set_mat4("matModel", &model_mat);
        self.object.render(shader);
        // for (self.children.items) |child| {
        //     child.render(shader);
        // }
    }

    pub fn updateAnimation(self: *Node, delta_time: f32) void {
        self.object.updateAnimation(delta_time);
        for (self.children.items) |child| {
            child.updateAnimation(delta_time);
        }
    }

    // example of how to get the type from a union(enum)
    pub fn getModel(self: *Node) !Model {
        if (self.object != .model) return error.TypeMismatch;
        return self.object.model;
    }
};

pub const NodeManager = struct {
    allocator: Allocator,
    node_list: std.ArrayList(*Node),

    const Self = @This();

    pub fn init(allocator: Allocator) !*Self {
        const manager = try allocator.create(Self);
        manager.* = .{
            .allocator = allocator,
            .node_list = std.ArrayList(*Node).init(allocator),
        };
        return manager;
    }

    pub fn deinit(self: *Self) void {
        for (self.node_list.items) |node| {
            node.deinit();
        }
        self.node_list.deinit();
        self.allocator.destroy(self);
    }

    pub fn create(self: *Self, name: []const u8, object: Object) !*Node { 
        const node = try Node.init(self.allocator, name, object);
        try self.node_list.append(node);
        return node;
    }
};
