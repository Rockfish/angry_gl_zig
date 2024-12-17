
## Animations

### Key frames
 - A series of key frames with times. Three arrays with list of the following objects.
```
  pub const KeyPosition = struct {
      position: Vec3,
      time_stamp: f32,
  };

  pub const KeyRotation = struct {
      orientation: Quat,
      time_stamp: f32,
  };

  pub const KeyScale = struct {
      scale: Vec3,
      time_stamp: f32,
  };
```

### Transform
 - A transform is an object with translation, rotation, and scale.
```
  Transform = struct {
      translation: Vec3,
      rotation: Quat,
      scale: Vec3
  };
```
### Nodes
 - The model's animation is described with a hierarchical tree structure composed of nodes in a parent-child relationship.
 - Each node has a name.
 - Each node has its own local transform.
 - A node can have a list of mesh ids. 
 - A node's global transform is calculated by walking the tree from the root passing the parent's transform to the child and multiplying the parent's transform by the child's transform to get the node's global transform.
 - The node's calculated global transform is stored in a node_map<name, transform>.

 - ModelNode is the structure that is used to build the parent / child relationship of the nodes and contains each node's transform and the mesh, if any, it applies to. The child's transform is relative to its parent.
```
  ModelNode = struct {
      node_name: *String,
      transform: Transform,
      children: *ArrayList(*ModelNode),
      meshes: *ArrayList(u32),
  };
```

### Bones
 - A bone is an object that represents a deformation to the mesh.
 - A skeleton is a hierarchy of bones.
 - Bones have transforms that are offsets from nodes with the same name.
 - ModelBone is the structure for the bone's id, name, and offset transform.
 - A bone transform affects only the vertices attached to that bone through the vertices bone_id array.
 - Each vertex in the mesh has an array of bone ids and an array of bone weights. 
 - These arrays are used to calculate a weighted transform to the vertex's position based on the bone transforms. Apply these bone transforms to the vertex occurs in the shader.
```
  ModelBone = struct {
      name: *String,
      bone_index: i32,
      offset_transform: Transform,
  };
```
### Vertex
 - Each vertex in the mesh has a ModelVertex with the position, normal, uv, tangent, bi_tangent, bone_ids, and bone_weights of a vertex.
```
  ModelVertex = extern struct {
      position: Vec3,
      normal: Vec3,
      uv: Vec2,
      tangent: Vec3,
      bi_tangent: Vec3,
      bone_ids: [MAX_BONE_INFLUENCE]i32,
      bone_weights: [MAX_BONE_INFLUENCE]f32,
  };
```

### ModelNodeAnimation
 - A ModelNodeAnimation is an object with the key frames for animation a node.
```
  ModelNodeAnimation = struct {
      node_name: *String,
      positions: *ArrayList(KeyPosition),
      rotations: *ArrayList(KeyRotation),
      scales: *ArrayList(KeyScale),
  };
```
### ModelAnimation
 - ModelAnimation holds the model's list of node animation data. There can be zero or
   more model animations per model. Currently only supporting one animation per model.
```
  ModelAnimation = struct {
      animation_name: *String,
      duration: f32,
      ticks_per_second: f32,
      node_animations: *ArrayList(*ModelNodeAnimation),
  };
```
### Animator
 - The Animator holds all the animation data and drives the animation by walking the data and building a map of all the node and bone transforms for the current animation time. 
```
  Animator = struct {
      root_node: *ModelNode,
      model_animations: *ModelAnimation,
      bone_map: *StringHashMap(*ModelBone),

      node_transform_map: *StringHashMap(*NodeTransform),
  
      transitions: *ArrayList(?*AnimationTransition),
      current_animation: *PlayingAnimation,
  
      global_inverse_transform: Mat4,
      final_bone_matrices: [MAX_BONES]Mat4,
      final_node_matrices: [MAX_NODES]Mat4,
  };
```
### Model
 - The Model object connects the model's mesh with the model's animation and provides an interface for animating and rendering the model
```
  Model = struct {
      allocator: Allocator,
      name: []const u8,
      meshes: *ArrayList(*ModelMesh),
      animator: *Animator,
  };
```

## Animation
To set a model's animation:
  - 
To update the model's animation:
  - Advance the tick count
  - Walk the node tree from the root passing the inverse of the root node's transform as the first parent transform.
  - At each node:
    - using the node's name, check the list of NodeKeyframes for the current animation for one with the same name. 
    - If found, calculate the node's animation transform for the current tick. Then the node's global transform is the parent's transform multiplied by the calculated animation transform.
    - Else, the node's global transform is the parent's transform multiple by the node's transform.
    - Store the node's global transform in the node transform map.



 - Definitions
   - Animation tick is an index into the Key arrays. Each animation clip has a starting tick and end tick marking the keys that make up a particular animation sequence.
   - An animation sequence has a time line that is divided into keys. Each key has a time_stamp indicating its position 
     along the time line. 
   - The keys are the transforms that should be reached by their time_stamps.
   - As the time advances along the time line, the transforms are the interpolations between key positions. 
 - Structure
   - For model animation
 - At each update
   - Walk each key list using an index until the next key's time is greater than the animation time.
     - The index points to the key before the key with a greater time.
     - The animated transform is an interpolation between the key at the index and the next key.
   - To calculate the interpolation between the two keys:
     - Calculate the scaled time between time_stamps of the two keys given the current animation time. See get_scale_factor.
     - Used the scaled time to lerp between the two keys if they are Vec3s or slerp if they are Quats.
     - This will yields depending on the key type, new position, new scale, or new rotation.
     - Combined, yields a new Transform. 
   - 
