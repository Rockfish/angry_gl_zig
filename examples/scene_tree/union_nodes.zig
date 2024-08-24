const std = @import("std");
const math = @import("math");

const Allocator = std.mem.Allocator;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub const NodeType = union(enum) {
    base: *Node,
    node2D: *Node2D,
    node3D: *Node3D,

    pub fn getNode(self: NodeType) *Node {
        return switch (self) {
            .base => |n| n,
            .node2D => |n| &n.base,
            .node3D => |n| &n.base,
        };
    }
};

const Transform = struct {
    // Example transform struct, implement as needed
    position: Vec3,
    rotation: Quat,
    scale: Vec3,

    pub fn init() Transform {
        return Transform{
            .position = Vec3.zero(),
            .rotation = Quat.identity(),
            .scale = Vec3.one(),
        };
    }
};

pub const Node = struct {
    name: []const u8,
    parent: ?*Node,
    children: std.ArrayList(NodeType),
    transform: Transform,

    pub fn init(allocator: *std.mem.Allocator, name: []const u8) Node {
        return Node{
            .name = name,
            .parent = null,
            .children = std.ArrayList(NodeType).init(allocator),
            .transform = Transform.init(),
        };
    }

    pub fn addChild(self: *Node, child: NodeType) void {
        _ = self.children.append(child) catch unreachable;
        child.getNode().*.parent = self; // Set the parent for the child
    }

    pub fn updateTransform(self: *Node) void {
        if (self.parent) |parent| {
            self.transform = parent.transform * self.transform;
        }
        for (self.children.items) |*child| {
            child.getNode().*.updateTransform();
        }
    }
};

pub const Node2D = struct {
    base: Node,
    // Additional 2D-specific fields
};

pub const Node3D = struct {
    base: Node,
    // Additional 3D-specific fields
};

// pub fn main() void {
//     const allocator = std.heap.page_allocator;
//     var root = Node.init(allocator, "Root");
//     var child2D = std.heap.page_allocator.create(Node2D) catch unreachable;
//     child2D.* = Node2D{
//         .base = Node.init(allocator, "Child2D"),
//         // Initialize other Node2D-specific fields
//     };
//
//     root.addChild(NodeType{ .node2D = child2D });  // Adding Node2D as a child
//
//     // Update the scene tree
//     root.updateTransform();
// }
