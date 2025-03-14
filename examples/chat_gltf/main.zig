const std = @import("std");
const json = std.json;

// Import the GLTF definitions (assumed to be defined in gltf.zig)
const gltf = @import("gltf.zig").GLTF;

// Define our own error set for parsing errors.
const ParseGltfError = error{
    ExpectedObject,
    MissingField,
    InvalidField,
};

/// Helper to get a required string field from a JSON object.
/// Returns an error if the field is missing or is not a string.
fn getStringField(object: *std.json.Object, field: []const u8) ![]const u8 {
    const maybeValue = object.get(field) orelse return ParseGltfError.MissingField;
    if (maybeValue.getType() != .String) return ParseGltfError.InvalidField;
    return maybeValue.String() orelse return ParseGltfError.InvalidField;
}

/// Helper to get an optional string field from a JSON object.
/// Returns null if the field is missing.
fn getOptionalStringField(object: *std.json.Object, field: []const u8) !?[]const u8 {
    const maybeValue = object.get(field);
    if (maybeValue == null) return null;
    if (maybeValue.getType() != .String) return ParseGltfError.InvalidField;
    return maybeValue.String() orelse return ParseGltfError.InvalidField;
}

/// Parse the "asset" object from the glTF JSON and initialize a gltf.Asset struct.
fn parseAsset(value: *json.Value) !gltf.Asset {
    const obj = value.Object() orelse return ParseGltfError.ExpectedObject;
    var asset: gltf.Asset = undefined;
    asset.version = try getStringField(obj, "version");
    asset.generator = try getOptionalStringField(obj, "generator");
    asset.copyright = try getOptionalStringField(obj, "copyright");
    asset.min_version = try getOptionalStringField(obj, "minVersion");
    return asset;
}

/// Parse the glTF JSON (provided as a byte slice) and initialize a gltf struct.
///
/// For brevity, only the required "asset" field is parsed here. You would add similar code
/// for other fields (scenes, nodes, meshes, etc.) to fully populate the glTF struct.
pub fn parseGltfJson(gltfJson: []const u8) !gltf {
    const allocator = std.heap.page_allocator;
    var parser = json.Parser.init(gltfJson, allocator);
    const value = try parser.parse();
    const root = value.Object() orelse return ParseGltfError.ExpectedObject;

    var result: gltf = undefined;
    // Parse the required "asset" field.
    const assetValue = root.get("asset") orelse return ParseGltfError.MissingField;
    result.asset = try parseAsset(assetValue);

    // You would continue parsing optional fields such as "scenes", "nodes", etc. here.
    return result;
}

/// Main entry point: reads the glTF JSON file from the command-line and parses it.
pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const args = std.process.args();
    if (args.len < 2) {
        try stdout.print("Usage: {s} <gltf_file>\n", .{args[0]});
        return;
    }
    const filePath = args[1];
    const fileData = try std.fs.cwd().readFile(filePath);
    const gltfData = try parseGltfJson(fileData);
    try stdout.print("Parsed glTF asset version: {s}\n", .{gltfData.asset.version});
}
