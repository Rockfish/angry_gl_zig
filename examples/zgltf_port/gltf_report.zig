const std = @import("std");
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const gl = @import("zopengl").bindings;
const core = @import("core");
const math = @import("math");
const Gltf = @import("zgltf/src/main.zig");

const ArrayList = std.ArrayList;

const Node = Gltf.Node;
const Mesh = Gltf.Mesh;
const Accessor = Gltf.Accessor;

const print = std.debug.print;
const allocator = std.heap.page_allocator;


var space_count: u32 = 0;

pub fn gltfReport(model_path: []const u8) !void {
    print("\n", .{});

    const buf = std.fs.cwd().readFileAllocOptions(
        allocator,
        model_path,
        512_000,
        null,
        4,
        null,
    ) catch |err| std.debug.panic("error: {any}\n", .{err});

    defer allocator.free(buf);

    var gltf = Gltf.init(allocator);
    defer gltf.deinit();

    try gltf.parse(buf);

    const data = gltf.data;

    for (data.scenes.items) |scene| {
        var num: usize = 0;
        if (scene.nodes) |scene_nodes| {
            num = scene_nodes.items.len;
        }

        print("scene name: {s}  root count: {d}\n", .{ scene.name, num });

        if (scene.nodes) |scene_nodes| {
            // space_count += 4;
            for (scene_nodes.items) |root_node| {
                print("root_node id: {d}\n", .{root_node});
                printSpace(space_count);
                space_count += 4;
                walkNodes(data.nodes, root_node);
                space_count -= 4;
            }
        }
    }

    print("--- Meshes ---\n", .{});
    for (data.meshes.items, 0..) |mesh, i| {
        printMesh(i, mesh);
    }

    print("--- Accessors ---\n", .{});
    for (data.accessors.items, 0..) |accessor, i| {
        printAccessor(i, accessor);
    }

    print("\n------\n", .{});
    gltf.debugPrint();
}

fn printMesh(id: usize, mesh: Mesh) void {
    print(
        "mesh id: {d}\n   name: {s}\n",
        .{
            id,
            mesh.name,
        },
    );
    for (mesh.primitives.items) |primative| {
        print("   attributes:\n", .{});
        for (primative.attributes.items) |attribute| {
            print("      {any}\n", .{attribute});
        }
        print("   mode: {any}\n", .{primative.mode});
        print("   indices: {any}\n", .{primative.indices});
        print("   material: {any}\n", .{primative.material});
    }
}

fn walkNodes(nodes: ArrayList(Node), id: usize) void {
    printSpace(space_count);
    const node = nodes.items[id];
    print(
        "Node id: {d} name: '{s}'  mesh count: {any}  children count: {}  Has skin: {}\n",
        .{
            id,
            node.name,
            node.mesh,
            node.children.items.len,
            node.skin != null,
        },
    );

    space_count += 4;

    for (node.children.items) |node_id| {
        walkNodes(nodes, node_id);
    }

    space_count -= 4;
}

fn printAccessor(id: usize, accessor: Accessor) void {
    print("Accessor id: {d}\n", .{id});
    print("   type: {any}\n", .{accessor.type});
    print("   component type: {any}\n", .{accessor.component_type});
    print("   buffer_view: {any}\n", .{accessor.buffer_view});
    print("   count: {d}\n", .{accessor.count});
    print("   byte_offset: {d}\n", .{accessor.byte_offset});
    print("   stride: {d}\n", .{accessor.stride});
    print("   normalized: {any}\n", .{accessor.normalized});
}

fn printSpace(count: u32) void {
    for (0..@as(usize, @intCast(count))) |_| {
        std.debug.print(" ", .{});
    }
}
