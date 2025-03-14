# Loading textures in the right color space

Here's a brief guide on which color space to use for different types of textures in a GLTF material, using the exact names from the GLTF specification:

GLTF Texture Color Spaces:

1. baseColorTexture:
    - Color Space: [sRGB](https://x.com/i/grok?text=sRGB)
    - Reason: This texture defines the surface color of the material under white light. sRGB ensures colors look correct on typical displays.

2. metallicRoughnessTexture:
    - Color Space: [Linear](https://x.com/i/grok?text=Linear)
    - Reason: This texture combines both metallic and roughness information in its channels (red for metallic, green for roughness). Linear space avoids gamma correction for accurate physical representation.

3. [normalTexture](https://x.com/i/grok?text=normalTexture):
    - Color Space: Linear
    - Reason: Encodes surface normals in RGB for light interaction calculations. Linear space is necessary since these values represent vectors, not colors.

4. [occlusionTexture](https://x.com/i/grok?text=occlusionTexture):
    - Color Space: Linear
    - Reason: Represents how much light is blocked from reaching the surface. Linear space ensures correct representation of these grayscale values.

5. [emissiveTexture](https://x.com/i/grok?text=emissiveTexture):
    - Color Space: sRGB
    - Reason: Defines areas of the material that emit light. sRGB is used to ensure the colors of emission appear as intended.

*Important Notes*:

- Conversion: Ensure textures are in their appropriate color space before being used in GLTF materials. Many authoring tools can handle this conversion directly.

- GLTF Viewer/Editor: While some tools might automatically manage color space conversions, preparing textures in the correct space initially is recommended.

# Rendering Tangents

To rendering a model without precomputed tangents and not use MikkTSpacean alternative approach used by some implementations, like the GLTF Sampler Viewer, for models without precomputed tangents, involves approximating the tangent in [screen space](https://x.com/i/grok?text=screen%20space):

Example [GLSL](https://x.com/i/grok?text=GLSL) Code for Approximating Tangents:

```glsl
vec3 uv_dx = dFdx(vec3(UV, 0.0));  // Derivative of texture coordinates in x direction
vec3 uv_dy = dFdy(vec3(UV, 0.0));  // Derivative of texture coordinates in y direction

vec3 tangent = (uv_dy.t * dFdx(v_Position) - uv_dx.t * dFdy(v_Position))
              / (uv_dx.s * uv_dy.t - uv_dy.s * uv_dx.t);
```

Explanation:
- UV here represents the texture coordinates.
- v_Position is the vertex position in screen space or world space, depending on the shader's context.
- dFdx and dFdy compute the derivative with respect to screen-space coordinates, which helps in calculating how the texture stretches or compresses on the surface.

This method leverages the fact that the normal map's influence is most visible in screen space, thus providing a visually acceptable approximation when tangents are not precomputed or when dealing with indexed mesh data directly. However, for precise normal mapping, especially in more complex scenarios, following the MikkTSpace method as suggested by the GLTF spec would yield better results.

