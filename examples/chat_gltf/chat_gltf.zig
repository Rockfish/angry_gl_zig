const std = @import("std");

///////////////////////////////////////////////////////////////////////////////
// Enum Definitions
///////////////////////////////////////////////////////////////////////////////

/// Defines the alpha blending mode for a material.
/// Variants:
/// - `opaque`: No transparency.
/// - `mask`: Uses a cutoff threshold.
/// - `blend`: Standard alpha blending.
pub const AlphaMode = enum {
    opaque_mode,
    mask,
    blend,
};

/// Texture wrapping mode. Underlying type is u32 so that it can hold the
/// OpenGL constants.
/// Variants:
/// - `repeat` (10497)
/// - `clamp_to_edge` (33071)
/// - `mirrored_repeat` (33648)
pub const WrapMode = enum(u32) {
    repeat = 10497,
    clamp_to_edge = 33071,
    mirrored_repeat = 33648,
};

/// Texture minification filter.
/// Variants (with their corresponding GL constant values):
/// - `nearest` (9728)
/// - `linear` (9729)
/// - `nearest_mipmap_nearest` (9984)
/// - `linear_mipmap_nearest` (9985)
/// - `nearest_mipmap_linear` (9986)
/// - `linear_mipmap_linear` (9987)
pub const MinFilter = enum(u32) {
    nearest = 9728,
    linear = 9729,
    nearest_mipmap_nearest = 9984,
    linear_mipmap_nearest = 9985,
    nearest_mipmap_linear = 9986,
    linear_mipmap_linear = 9987,
};

/// Texture magnification filter.
/// Variants:
/// - `nearest` (9728)
/// - `linear` (9729)
pub const MagFilter = enum(u32) {
    nearest = 9728,
    linear = 9729,
};

/// The type of data stored in an accessor. In glTF, this is specified as a string,
/// but here we use an enum for type safety.
/// Variants:
/// - `scalar`
/// - `vec2`
/// - `vec3`
/// - `vec4`
/// - `mat2`
/// - `mat3`
/// - `mat4`
pub const AccessorType = enum {
    scalar,
    vec2,
    vec3,
    vec4,
    mat2,
    mat3,
    mat4,
};

/// Intended GPU buffer type for a bufferView.
/// Variants:
/// - `array_buffer` (34962)
/// - `element_array_buffer` (34963)
pub const Target = enum(u32) {
    array_buffer = 34962,
    element_array_buffer = 34963,
};

/// Data type of accessor components. Variants correspond to the GL constants:
/// - `byte` (5120)
/// - `unsigned_byte` (5121)
/// - `short` (5122)
/// - `unsigned_short` (5123)
/// - `unsigned_int` (5125)
/// - `float` (5126)
pub const ComponentType = enum(u32) {
    byte = 5120,
    unsigned_byte = 5121,
    short = 5122,
    unsigned_short = 5123,
    unsigned_int = 5125,
    float = 5126,
};

/// Primitive drawing mode for a mesh primitive.
/// Variants:
/// - `points` (0)
/// - `lines` (1)
/// - `line_loop` (2)
/// - `line_strip` (3)
/// - `triangles` (4)
/// - `triangle_strip` (5)
/// - `triangle_fan` (6)
pub const Mode = enum(u32) {
    points = 0,
    lines = 1,
    line_loop = 2,
    line_strip = 3,
    triangles = 4,
    triangle_strip = 5,
    triangle_fan = 6,
};

/// Property of a node that can be animated.
/// Variants:
/// - `translation`
/// - `rotation`
/// - `scale`
/// - `weights`
pub const TargetProperty = enum {
    translation,
    rotation,
    scale,
    weights,
};

/// Interpolation algorithm for animation keyframes.
/// Variants:
/// - `linear`
/// - `step`
/// - `cubic_spline`
pub const Interpolation = enum {
    linear,
    step,
    cubic_spline,
};

/// Light type (typically used with glTF extensions such as KHR_lights_punctual).
/// Variants:
/// - `directional`
/// - `point`
/// - `spot`
pub const LightType = enum {
    directional,
    point,
    spot,
};

///////////////////////////////////////////////////////////////////////////////
// GLTF Data Structures
///////////////////////////////////////////////////////////////////////////////

/// glTF 2.0 Type Definitions in Zig
///
/// This file defines the data structures corresponding to the glTF 2.0 specification.
///
/// ### Design Note
/// Arrays of glTF objects (e.g. nodes, meshes, etc.) are represented as slices (pointer+length)
/// rather than using `std.ArrayList` because:
/// - The arrays are read-only after being loaded.
/// - Their size is fixed once parsed.
///
/// Similarly, binary blob data (e.g. buffer data, image data) is stored as a slice of `u8` since
/// it is allocated once at load time and remains unchanged.
pub const GLTF = struct {
    /// Required. Metadata for the glTF asset.
    asset: Asset,

    /// Optional. Array of scene objects.
    scenes: ?[]Scene,

    /// Optional. Index of the default scene.
    scene: ?u32,

    /// Optional. Array of node objects.
    nodes: ?[]Node,

    /// Optional. Array of mesh objects.
    meshes: ?[]Mesh,

    /// Optional. Array of accessor objects.
    accessors: ?[]Accessor,

    /// Optional. Array of bufferView objects.
    buffer_views: ?[]BufferView,

    /// Optional. Array of buffer objects.
    buffers: ?[]Buffer,

    /// Optional. Array of material objects.
    materials: ?[]Material,

    /// Optional. Array of sampler objects.
    samplers: ?[]Sampler,

    /// Optional. Array of texture objects.
    textures: ?[]Texture,

    /// Optional. Array of image objects.
    images: ?[]Image,

    /// Optional. Array of animation objects.
    animations: ?[]Animation,

    /// Optional. Array of skin objects.
    skins: ?[]Skin,

    /// Optional. Array of camera objects.
    cameras: ?[]Camera,
};

/// Provides metadata about the glTF asset.
pub const Asset = struct {
    /// Required. The glTF version. Must be "2.0".
    version: []const u8,

    /// Optional. Application or tool that generated the asset.
    generator: ?[]const u8,

    /// Optional. Copyright information.
    copyright: ?[]const u8,

    /// Optional. Minimum glTF version required to view the asset.
    min_version: ?[]const u8,
};

/// A scene is a collection of nodes to be rendered.
pub const Scene = struct {
    /// Optional. Array of node indices that form the root nodes.
    nodes: ?[]u32,

    /// Optional. Name of the scene.
    name: ?[]const u8,
};

/// A node represents an object in the glTF scene graph.
pub const Node = struct {
    /// Optional. Array of indices to child nodes.
    children: ?[]u32,

    /// Optional. Index of the mesh to be rendered at this node.
    mesh: ?u32,

    /// Optional. Index of the skin used for skeletal animation.
    skin: ?u32,

    /// Optional. Index of the camera referenced by this node.
    camera: ?u32,

    /// Optional. 4x4 transformation matrix (column-major).
    /// If provided, it overrides the separate translation, rotation, and scale.
    matrix: ?[16]f32,

    /// Optional. Translation vector.
    translation: ?[3]f32,

    /// Optional. Rotation quaternion (x, y, z, w).
    rotation: ?[4]f32,

    /// Optional. Scale vector.
    scale: ?[3]f32,

    /// Optional. Name of the node.
    name: ?[]const u8,
};

/// A mesh is composed of one or more primitives that define geometry.
pub const Mesh = struct {
    /// Array of mesh primitives that contain geometry and material info.
    primitives: []MeshPrimitive,

    /// Optional. Array of weights for morph targets.
    weights: ?[]f32,

    /// Optional. Name of the mesh.
    name: ?[]const u8,
};

/// A mesh primitive defines a subset of a mesh to be rendered with a material.
pub const MeshPrimitive = struct {
    /// Mapping from vertex attribute semantics to accessor indices.
    attributes: Attributes,

    /// Optional. Accessor index containing indices. Undefined if non-indexed.
    indices: ?u32,

    /// Optional. Index of the material to apply.
    material: ?u32,

    /// Rendering mode. Default is TRIANGLES.
    mode: Mode,

    /// Optional. Array of morph target attribute changes.
    targets: ?[]MorphTarget,
};

/// Defines the vertex attribute mappings for a mesh primitive.
///
/// Note: While glTF allows arbitrary attribute names, here we define common ones.
pub const Attributes = struct {
    /// Optional. Accessor index for vertex positions.
    position: ?u32,

    /// Optional. Accessor index for vertex normals.
    normal: ?u32,

    /// Optional. Accessor index for vertex tangents.
    tangent: ?u32,

    /// Optional. Accessor index for the first set of texture coordinates.
    tex_coord_0: ?u32,

    /// Optional. Accessor index for the second set of texture coordinates.
    tex_coord_1: ?u32,

    /// Optional. Accessor index for vertex colors.
    color_0: ?u32,

    /// Optional. Accessor index for joint indices used in skinning.
    joints_0: ?u32,

    /// Optional. Accessor index for joint weights used in skinning.
    weights_0: ?u32,
};

/// A morph target provides alternative vertex data for mesh deformations.
pub const MorphTarget = struct {
    /// Optional. Accessor index for position deltas.
    position: ?u32,

    /// Optional. Accessor index for normal deltas.
    normal: ?u32,

    /// Optional. Accessor index for tangent deltas.
    tangent: ?u32,
    // Additional attributes can be added as required.
};

/// An accessor provides a typed view into a bufferView.
pub const Accessor = struct {
    /// Optional. Index of the bufferView containing the data.
    buffer_view: ?u32,

    /// Offset (in bytes) from the start of the bufferView.
    byte_offset: u32 = 0,

    /// Required. Data type of components (e.g., 5126 for float).
    component_type: ComponentType,

    /// Indicates whether integer data should be normalized.
    normalized: bool = false,

    /// Number of elements in the accessor.
    count: u32,

    /// Type of elements (e.g., SCALAR, VEC3) as an enum.
    type_: AccessorType,

    /// Optional. Maximum values for each component.
    max: ?[]f32,

    /// Optional. Minimum values for each component.
    min: ?[]f32,

    /// Optional. Sparse storage information.
    sparse: ?AccessorSparse,

    /// Optional. Name of the accessor.
    name: ?[]const u8,
};

/// Provides sparse storage for accessor data.
pub const AccessorSparse = struct {
    /// Number of entries stored in the sparse array.
    count: u32,

    /// Indices of the elements that are replaced.
    indices: AccessorSparseIndices,

    /// Replacement values for the sparse elements.
    values: AccessorSparseValues,
};

/// Contains indices for sparse accessor elements.
pub const AccessorSparseIndices = struct {
    /// Index of the bufferView containing the indices.
    buffer_view: u32,

    /// Offset (in bytes) into the bufferView.
    byte_offset: u32 = 0,

    /// Data type of indices (must be 5121, 5123, or 5125).
    component_type: u32,
};

/// Contains replacement values for sparse accessor elements.
pub const AccessorSparseValues = struct {
    /// Index of the bufferView containing the replacement values.
    buffer_view: u32,

    /// Offset (in bytes) into the bufferView.
    byte_offset: u32 = 0,
};

/// A bufferView represents a contiguous subset of a buffer.
pub const BufferView = struct {
    /// Index of the buffer.
    buffer: u32,

    /// Offset (in bytes) from the start of the buffer.
    byte_offset: u32 = 0,

    /// Length (in bytes) of the bufferView.
    byte_length: u32,

    /// Optional. Stride (in bytes) between elements.
    byte_stride: ?u32,

    /// Optional. Intended GPU buffer type (e.g., ARRAY_BUFFER).
    target: ?Target,

    /// Optional. Name of the bufferView.
    name: ?[]const u8,
};

/// A buffer holds binary data for vertices, animations, etc.
pub const Buffer = struct {
    /// Optional. URI to load the buffer from. If null, the data is embedded.
    uri: ?[]const u8,

    /// Total length (in bytes) of the buffer.
    byte_length: u32,

    /// Optional. Name of the buffer.
    name: ?[]const u8,

    /// Pointer to the binary data loaded at runtime.
    data: ?[]u8,
    // The data is stored as a slice of u8 because it is read-only after loading,
    // and a fixed-size allocation suffices.
};

/// A material defines surface appearance properties.
pub const Material = struct {
    /// Optional. PBR material configuration.
    pbr_metallic_roughness: ?PBRMetallicRoughness,

    /// Optional. Information about the normal map texture.
    normal_texture: ?TextureInfo,

    /// Optional. Information about the occlusion map texture.
    occlusion_texture: ?TextureInfo,

    /// Optional. Information about the emissive map texture.
    emissive_texture: ?TextureInfo,

    /// Emissive color factor.
    emissive_factor: [3]f32 = [3]f32{0.0, 0.0, 0.0},

    /// Alpha mode for the material.
    alpha_mode: AlphaMode = AlphaMode.opaque_mode,

    /// Cutoff value for alpha masking.
    alpha_cutoff: f32 = 0.5,

    /// Indicates whether the material is double sided.
    double_sided: bool = false,

    /// Optional. Name of the material.
    name: ?[]const u8,
};

/// PBR metallic-roughness material configuration.
pub const PBRMetallicRoughness = struct {
    /// RGBA multiplier for base color.
    base_color_factor: [4]f32 = [4]f32{1.0, 1.0, 1.0, 1.0},

    /// Optional. Information about the base color texture.
    base_color_texture: ?TextureInfo,

    /// Metallic factor.
    metallic_factor: f32 = 1.0,

    /// Roughness factor.
    roughness_factor: f32 = 1.0,

    /// Optional. Information about the metallic-roughness texture.
    metallic_roughness_texture: ?TextureInfo,
};

/// Contains information to reference a texture.
pub const TextureInfo = struct {
    /// Index of the texture.
    index: u32,

    /// Set index of texture coordinates.
    tex_coord: u32 = 0,
};

/// A sampler defines how a texture is sampled.
pub const Sampler = struct {
    /// Optional. Magnification filter mode.
    mag_filter: ?MagFilter,

    /// Optional. Minification filter mode.
    min_filter: ?MinFilter,

    /// S (U) wrapping mode.
    wrap_s: WrapMode = WrapMode.repeat,

    /// T (V) wrapping mode.
    wrap_t: WrapMode = WrapMode.repeat,

    /// Optional. Name of the sampler.
    name: ?[]const u8,
};

/// A texture references an image and optionally a sampler.
pub const Texture = struct {
    /// Optional. Index of the sampler.
    sampler: ?u32,

    /// Optional. Index of the image.
    source: ?u32,

    /// Optional. Name of the texture.
    name: ?[]const u8,
};

/// An image used as a texture source.
pub const Image = struct {
    /// Optional. URI of the image.
    uri: ?[]const u8,

    /// Optional. MIME type of the image.
    mime_type: ?[]const u8,

    /// Optional. BufferView index if the image is embedded.
    buffer_view: ?u32,

    /// Optional. Name of the image.
    name: ?[]const u8,

    /// Pointer to the image data loaded at runtime.
    data: ?[]u8,
};

/// An animation is a sequence that modifies node properties over time.
pub const Animation = struct {
    /// Array of animation channels.
    channels: []AnimationChannel,

    /// Array of animation samplers.
    samplers: []AnimationSampler,

    /// Optional. Name of the animation.
    name: ?[]const u8,
};

/// An animation channel targets a specific node property.
pub const AnimationChannel = struct {
    /// Index of the animation sampler providing keyframe data.
    sampler: u32,

    /// Target (node and property) for the animation.
    target: AnimationChannelTarget,
};

/// Specifies the target of an animation channel.
pub const AnimationChannelTarget = struct {
    /// Optional. Index of the node to be animated.
    node: ?u32,

    /// The property to animate.
    path: TargetProperty,
};

/// An animation sampler contains keyframe input and output data.
pub const AnimationSampler = struct {
    /// Index of an accessor containing keyframe input values (time).
    input: u32,

    /// Index of an accessor containing keyframe output values.
    output: u32,

    /// Interpolation algorithm.
    interpolation: Interpolation = Interpolation.linear,
};

/// A skin defines joints and inverse bind matrices for skeletal animations.
pub const Skin = struct {
    /// Optional. Accessor index containing inverse bind matrices.
    inverse_bind_matrices: ?u32,

    /// Optional. Index of the node that is the skeleton root.
    skeleton: ?u32,

    /// Array of node indices acting as joints.
    joints: []u32,

    /// Optional. Name of the skin.
    name: ?[]const u8,
};

/// A camera defines projection properties.
pub const Camera = struct {
    /// Optional. Orthographic projection parameters.
    orthographic: ?CameraOrthographic,

    /// Optional. Perspective projection parameters.
    perspective: ?CameraPerspective,

    /// Optional. Name of the camera.
    name: ?[]const u8,
};

/// Orthographic camera projection parameters.
pub const CameraOrthographic = struct {
    /// Horizontal magnification.
    xmag: f32,

    /// Vertical magnification.
    ymag: f32,

    /// Far clipping plane.
    zfar: f32,

    /// Near clipping plane.
    znear: f32,
};

/// Perspective camera projection parameters.
pub const CameraPerspective = struct {
    /// Vertical field of view in radians.
    yfov: f32,

    /// Optional. Far clipping plane. If undefined, an infinite projection is used.
    zfar: ?f32,

    /// Near clipping plane.
    znear: f32,

    /// Optional. Aspect ratio (width / height).
    aspect_ratio: ?f32,
};
