const std = @import("std");
const math = @import("math");
const Transform = @import("core").Transform;
const Shader = @import("core").Shader;

const Allocator = std.mem.Allocator;

const Vec2 = math.Vec2;
const Vec3 = math.Vec3;
const Vec4 = math.Vec4;
const vec2 = math.vec2;
const vec3 = math.vec3;
const vec4 = math.vec4;
const Mat4 = math.Mat4;
const Quat = math.Quat;

pub const Node = struct {
    allocator: Allocator,
    name: []const u8,
    ptr: *anyopaque,
    parent: ?*Node,
    children: std.ArrayList(*Node),
    transform: Transform,
    global_transform: Transform,
    // interface
    updatefn: *const fn(ptr: *anyopaque, state: *anyopaque) anyerror!void,
    renderfn: *const fn(ptr: *anyopaque, shader: *Shader) void,
    hellofn: *const fn(ptr: *anyopaque) void,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.children.deinit();  // use depth first from root to delete children.
        self.allocator.destroy(self);
    }

    pub fn init(allocator: Allocator, name: []const u8, node_ptr: anytype, state_ptr: anytype) !*Node {
        // std.debug.print("TypeOf: {any}\n", .{T});
        // std.debug.print("typeInfo: {any}\n", .{ptr_info});

        const gen = struct {
            const TN = @TypeOf(node_ptr);
            const node_ptr_info = @typeInfo(TN);
            const TS = @TypeOf(state_ptr);

            pub fn update(node_pointer: *anyopaque, state_pointer: *anyopaque) anyerror!void {
                if (std.meta.hasFn(node_ptr_info.Pointer.child, "update")) {
                    const self: TN = @ptrCast(@alignCast(node_pointer));
                    const state: TS = @ptrCast(@alignCast(state_pointer));
                    return node_ptr_info.Pointer.child.update(self, state);
                }
            }

            pub fn render(pointer: *anyopaque, shader: *Shader) void {
                if (std.meta.hasFn(node_ptr_info.Pointer.child, "render")) {
                    const self: TN = @ptrCast(@alignCast(pointer));
                    return node_ptr_info.Pointer.child.render(self, shader);
                }
            }

            pub fn hello(pointer: *anyopaque) void {
                if (std.meta.hasFn(node_ptr_info.Pointer.child, "hello")) {
                     const self: TN = @ptrCast(@alignCast(pointer));
                     return node_ptr_info.Pointer.child.hello(self);
                 }
            }
        };

        // const TN = @TypeOf(node_ptr);
        // const node_ptr_info = @typeInfo(TN);
        // if (std.meta.hasFn(node_ptr_info.Pointer.child, "hello")) {
        //     std.debug.print("node_ptr_info has hello\n", .{});
        // } else {
        //     std.debug.print("node_ptr_info does not have hello\n", .{});
        // }
        //
        // const has_hello = std.meta.hasFn(node_ptr_info.Pointer.child, "hello");
        //
        // const gen2 = if (has_hello) 
        //     struct {
        //         pub fn hello(pointer: *anyopaque) void {
        //             const self: TN = @ptrCast(@alignCast(pointer));
        //             return node_ptr_info.Pointer.child.hello(self);
        //         }
        //     }
        //  else 
        //     struct {};

        const node = try allocator.create(Node);
        node.* = Node{
            .allocator = allocator,
            .ptr = node_ptr,
            .name = name,
            .parent = null,
            .children = std.ArrayList(*Node).init(allocator),
            .transform = Transform.init(),
            .global_transform = Transform.init(),
            .updatefn = gen.update,
            .renderfn = gen.render,
            .hellofn = gen.hello,
        };
        return node;
    }

    pub fn addChild(self: *Node, child: *Node) void {
        _ = self.children.append(child) catch unreachable;
        child.*.parent = self;
    }

    pub fn updateTransform(self: *Node, parent_transform: ?*Transform) void {
        if (parent_transform) |transform| {
            self.global_transform = transform.mul_transform(self.transform);
        } else {
            self.global_transform = self.transform;
        }

        for (self.children.items) |*child| {
            child.*.updateTransform(&self.global_transform);
        }
    }

    pub fn update(self: *Node, state: *anyopaque) anyerror!void {
        try self.updatefn(self.ptr, state);
    }

    pub fn render(self: *Node, shader: *Shader) void {
        const mat = self.global_transform.get_matrix();
        shader.set_mat4("model", &mat);
        self.renderfn(self.ptr, shader);
        for (self.children.items) |child| {
            child.render(shader);
        }
    }

    pub fn hello(self: *Node) void {
        self.hellofn(self.ptr);
    }
};


