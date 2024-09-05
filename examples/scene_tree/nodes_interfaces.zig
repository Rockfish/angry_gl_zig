const std = @import("std");
const math = @import("math");
const Transform = @import("core").Transform;
const Shader = @import("core").Shader;
const State = @import("main.zig").State;

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
    impl: Interface,
    // interface
    // updatefn: *const fn(ptr: *anyopaque, state: *anyopaque) anyerror!void,
    // renderfn: *const fn(ptr: *anyopaque, shader: *Shader) void,
    // hellofn: *const fn(ptr: *anyopaque) void,

    const Self = @This();

    const Interface = struct {
        updatefn: *const fn(ptr: *anyopaque, state: *anyopaque) anyerror!void,
        renderfn: *const fn(ptr: *anyopaque, shader: *Shader) void,
        hellofn: *const fn(ptr: *anyopaque) void,
    };

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
                } else {
                    std.log.warn("Function 'update' is not implemented by type: {any}", .{node_ptr_info.Pointer.child});
                }
            }

            // Maybe this will work 
            pub fn update_maybe(comptime node: anytype, comptime state: anytype) anyerror!void {
                const T = @TypeOf(node);
                //if (std.meta.hasFn(node_ptr_info.Pointer.child, "update")) {
                if (std.meta.hasMethod(T, "update")) {
                    // hmm, there code in the zig sources that suggest something along this line...
                    // see src/link/tapi/yaml.zig
                    return node.update(state);
                }
            }

            pub fn render(pointer: *anyopaque, shader: *Shader) void {
                if (std.meta.hasFn(node_ptr_info.Pointer.child, "render")) {
                    const self: TN = @ptrCast(@alignCast(pointer));
                    return node_ptr_info.Pointer.child.render(self, shader);
                } else {
                    const state = struct { var has_warned: bool = false; };
                    if (!state.has_warned) {
                        std.log.warn("Function 'render' is not implemented by type: {any}", .{node_ptr_info.Pointer.child});
                        state.has_warned = true;
                    }
                }
            }

            pub fn hello(pointer: *anyopaque) void {
                if (std.meta.hasFn(node_ptr_info.Pointer.child, "hello")) {
                    const self: TN = @ptrCast(@alignCast(pointer));
                    return node_ptr_info.Pointer.child.hello(self);
                } else {
                    std.log.warn("Function 'hello' is not implemented by type: {any}", .{node_ptr_info.Pointer.child});
                }
            }
        };

        std.debug.print("gen type: {any}\n", .{@TypeOf(gen)});

        const node = try allocator.create(Node);
        node.* = Node{
            .allocator = allocator,
            .ptr = node_ptr,
            .name = name,
            .parent = null,
            .children = std.ArrayList(*Node).init(allocator),
            .transform = Transform.init(),
            .global_transform = Transform.init(),
            .impl = .{
                .updatefn = gen.update,
                .renderfn = gen.render,
                .hellofn = gen.hello,
            }, 
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
        try self.impl.updatefn(self.ptr, state);
    }

    pub fn render(self: *Node, shader: *Shader) void {
        const mat = self.global_transform.get_matrix();
        shader.set_mat4("model", &mat);
        self.impl.renderfn(self.ptr, shader);
        for (self.children.items) |child| {
            child.render(shader);
        }
    }

    pub fn hello(self: *Node) void {
        self.impl.hellofn(self.ptr);
    }
};

pub const BasicNode = struct {
    const Self = @This();

    pub fn init() Self {
        return .{
        };
    }

    pub fn hello(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        std.debug.print("BasicNode. self: {any}\n", .{self});
    }
};

pub const ShapeNode = struct {
    ptr: *anyopaque,
    renderfn: *const fn(ptr: *anyopaque) void,
    name: []const u8,

    const Self = @This();

    pub fn init(ptr: anytype, name: []const u8) Self {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn render(pointer: *anyopaque) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.render(self);
            }
        };

        return .{
            .ptr = ptr,
            .renderfn = gen.render,
            .name = name,
        };
    }

    pub fn update(ptr: *anyopaque, st: *State) anyerror!void {
        _ = ptr;
        _ = st;
    }

    pub fn render(ptr: *anyopaque, shader: *Shader) void {
        _ = shader; 
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.renderfn(self.ptr);
    }

    pub fn hello(self: *Self) void {
        std.debug.print("hello from self: {s}\n", .{self.name});
    }

    pub fn hellox(ptr: *anyopaque) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        std.debug.print("hello from ShapeNode. self: {any}\n", .{self});
    }
};

pub const SceneModelNode = struct {
    ptr: *anyopaque,
    renderfn: *const fn(ptr: *anyopaque, shader: *Shader) void,

    const Self = @This();

    pub fn init(ptr: anytype) Self {
        const T = @TypeOf(ptr);
        const ptr_info = @typeInfo(T);

        const gen = struct {
            pub fn render(pointer: *anyopaque, shader: *Shader) void {
                const self: T = @ptrCast(@alignCast(pointer));
                return ptr_info.Pointer.child.render(self, shader);
            }
        };

        return .{
            .ptr = ptr,
            .renderfn = gen.render,
        };
    }

    pub fn update(ptr: *anyopaque, st: *State) anyerror!void {
        _ = ptr;
        _ = st;
    }

    pub fn render(ptr: *anyopaque, shader: *Shader) void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        self.renderfn(self.ptr, shader);
    }
};


