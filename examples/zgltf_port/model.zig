const std = @import("std");
const core = @import("core");
const math = @import("math");
const Gltf = @import("zgltf/src/main.zig");

const Transform = core.Transform;
const Mat4 = math.Mat4;
const mat4 = math.mat4;
const Vec3 = math.Vec3;
const vec3 = math.vec3;
const Quat = math.Quat;

const Shader = @import("shader.zig").Shader;
const Mesh = @import("gltf_mesh.zig").Mesh;
const MeshPrimitive = @import("gltf_mesh.zig").MeshPrimitive;
const Animator = @import("animator.zig").Animator;

// const animation = @import("animator.zig");
// const AnimationClip = @import("animator.zig").AnimationClip;

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

// const Animator = animation.Animator;
// const WeightedAnimation = animation.WeightedAnimation;

const MAX_BONES = 4;
const MAX_NODES = 200;

pub const Model = struct {
    allocator: Allocator,
    name: []const u8,
    scene: usize,
    meshes: *ArrayList(*Mesh),
    animator: *Animator,
    single_mesh_select: i32 = -1,
    gltf: Gltf,

    const Self = @This();

    pub fn init(allocator: Allocator, name: []const u8, meshes: *ArrayList(*MeshPrimitive), animator: *Animator, gltf: *Gltf,) !Self {
        const model = try allocator.create(Model);
        model.* = Model{
            .allocator = allocator,
            .scene = 0,
            .name = try allocator.dupe(u8, name),
            .meshes = meshes,
            .animator = animator,
            .gltf = gltf,
        };

        return model;
    }

    pub fn deinit(self: *Self) void {
        for (self.meshes.items) |mesh| {
            mesh.deinit();
        }
        self.meshes.deinit();
        self.allocator.destroy(self.meshes);
        self.allocator.free(self.name);
        self.animator.deinit();
        self.gltf.deinit();
        self.allocator.destroy(self);
    }

    // pub fn playClip(self: *Self, clip: AnimationClip) !void {
    //     try self.animator.playClip(clip);
    // }

    pub fn playTick(self: *Self, tick: f32) !void {
        try self.animator.playTick(tick);
    }

    // pub fn play_clip_with_transition(self: *Self, clip: AnimationClip, transition_duration: f32) !void {
    //     try self.animator.play_clip_with_transition(clip, transition_duration);
    // }

    // pub fn play_weight_animations(self: *Self, weighted_animation: []const WeightedAnimation, frame_time: f32) !void {
    //     try self.animator.play_weight_animations(weighted_animation, frame_time);
    // }

    pub fn render(self: *Self, shader: *const Shader) void {
        // var buf: [256:0]u8 = undefined;
        // for (0..MAX_BONES) |i| {
        //     const bone_transform = self.animator.final_bone_matrices[i];
        //     const uniform = std.fmt.bufPrintZ(&buf, "finalBonesMatrices[{d}]", .{i}) catch unreachable;
        //     shader.set_mat4(uniform, &bone_transform);
        // }

        const scene = self.gltf.data.scenes.items[self.scene];

        for (scene.nodes.?.items) |node_index| {
            const node = self.gltf.data.nodes.items[node_index];
            self.renderNodes(shader, node, Mat4.identity());
        }
    }

    fn renderNodes(self: *Self, shader: *const Shader, node: Gltf.Node, parent_transform: Mat4) void {
        const transform = Transform {
            .translation = Vec3.fromArray(node.translation),
            .rotation = Quat.fromArray(node.rotation),
            .scale = Vec3.fromArray(node.scale),
        };
        const local_matrix = transform.get_matrix();
        const global_matrix = parent_transform.mulMat4(&local_matrix);

        shader.set_mat4("nodeTransform", &global_matrix);

        if (node.mesh) |mesh_index| { 
            const mesh = self.meshes.items[mesh_index]; 
            mesh.render(&self.gltf, shader);
        }

        for (node.children.items) |node_index| {
            const child = self.gltf.data.nodes.items[node_index];
            self.renderNodes(shader, child, global_matrix);
        }
    }

    pub fn set_shader_bones_for_mesh(self: *Self, shader: *const Shader, mesh: *MeshPrimitive) !void {
        var buf: [256:0]u8 = undefined;

        for (0..MAX_BONES) |i| {
            const bone_transform = self.animator.final_bone_matrices[i];
            const uniform = try std.fmt.bufPrintZ(&buf, "finalBonesMatrices[{d}]", .{i});
            shader.set_mat4(uniform, &bone_transform);
        }
        shader.set_mat4("nodeTransform", &self.animator.final_node_matrices[@intCast(mesh.id)]);
    }

    pub fn update_animation(self: *Self, delta_time: f32) !void {
        try self.animator.update_animation(delta_time);
    }
};

pub fn dumpModelNodes(model: *Model) !void {
    std.debug.print("\n--- Dumping nodes ---\n", .{});
    var buf: [1024:0]u8 = undefined;

    var node_iterator = model.animator.node_transform_map.iterator();
    while (node_iterator.next()) |entry| { // |node_name, node_transform| {
        const name = entry.key_ptr.*;
        const transform = entry.value_ptr.*;
        const str = transform.transform.asString(&buf);
        std.debug.print("node_name: {s} : {s}\n", .{name, str});
    }
    std.debug.print("\n", .{});

    var bone_iterator = model.animator.bone_map.iterator();
    while (bone_iterator.next()) |entry| { // |node_name, node_transform| {
        const name = entry.key_ptr.*;
        const transform = entry.value_ptr.*;
        const str = transform.offset_transform.asString(&buf);
        std.debug.print("bone_name: {s} : {s}\n", .{name, str});
    }
}
