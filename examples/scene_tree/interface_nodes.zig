const std = @import("std");
const math = @import("math");
const State = @import("main.zig").State;
const Transform = @import("core").Transform;

const Allocator = std.mem.Allocator;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

// pub const NodeInferface = struct { 
//     ptr: *anyopaque,
//     updatefn: *const fn(ptr: *anyopaque, state: *State) anyerror!void,
//     renderfn: *const fn(ptr: *anyopaque, state: *State) anyerror!void,
//
//     pub fn from(ptr: *anyopaque, comptime T: type) NodeInferface {
//         const self: *T = @ptrCast(@alignCast(ptr));
//         return .{
//             .ptr = self,
//             .updatefn = T.update,
//             .renderfn = T.render,
//         };
//     }
// };

pub const Node = struct {
    allocator: Allocator,
    name: []const u8,
    ptr: *anyopaque,
    parent: ?*Node,
    children: std.ArrayList(*Node),
    node_transform: Transform,
    global_transform: Transform,
    updatefn: *const fn(ptr: *anyopaque, state: *State) anyerror!void,
    renderfn: *const fn(ptr: *anyopaque, state: *State, transform: Transform) anyerror!void,

    pub fn init(allocator: Allocator, comptime T: type, name: []const u8, ptr: *anyopaque) !*Node {
        const node = try allocator.create(Node);
        node.* = Node{
            .allocator = allocator,
            .ptr = ptr,
            .name = name,
            .parent = null,
            .children = std.ArrayList(*Node).init(allocator),
            .node_transform = Transform.init(),
            .global_transform = Transform.init(),
            .updatefn = T.update,
            .renderfn = T.render,
        };
        return node;
    }

    pub fn addChild(self: *Node, child: Node) void {
        _ = self.children.append(child) catch unreachable;
        child.*.parent = self;
    }

    pub fn updateTransform(self: *Node, parent_transform: ?*Transform) void {
        if (parent_transform) |transform| {
            self.global_transform = transform.mul_transform(self.node_transform);
        } else {
            self.global_transform = self.node_transform;
        }

        for (self.children.items) |*child| {
            child.*.updateTransform(self.global_transform);
        }
    }
};


