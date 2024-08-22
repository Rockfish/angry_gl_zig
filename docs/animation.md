
## Animations

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
### ModelNode
 - ModelNode is the object that is used to build the parent / child relationship of the nodes and contains each
   node's transform and the mesh it applies to.
```
  ModelNode = struct {
      node_name: *String,
      transform: Transform,
      childern: *ArrayList(*ModelNode),
      meshes: *ArrayList(u32),
  };
```
### ModelBone
 - ModelBone holds the bone's id, name, and offset transform. A bone transform affects only the vertices attached
   to that bone through the vertices bone_id array.
```
  ModelBone = struct {
      name: *String,
      bone_index: i32,
      offset_transform: Transform,
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
 - ModelAnimation holds the model's list of ModelNodeAnimation data.
```
  ModelAnimation = struct {
      duration: f32,
      ticks_per_second: f32,
      node_animations: *ArrayList(*ModelNodeAnimation),
  };
```
### Animator
 - The Animator holds all the animation data and drives the animation by walking the data and building a map
   of all the node and bone transforms for the current animation time. 
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

 - Definitions
   - Animation tick is an index into the Key arrays. Each animation clip has a starting tick and end tick marking the 
     keys that make up a particular animation sequence.
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
