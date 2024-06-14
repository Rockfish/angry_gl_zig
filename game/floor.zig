
const FLOOR_SIZE: f32 = 100.0;
const TILE_SIZE: f32 = 1.0;
const NUM_TILE_WRAPS: f32 = FLOOR_SIZE / TILE_SIZE;


const FLOOR_VERTICES: [30]f32 = .{
    // Vertices                                // TexCoord
    -FLOOR_SIZE / 2.0, 0.0, -FLOOR_SIZE / 2.0, 0.0, 0.0,
    -FLOOR_SIZE / 2.0, 0.0,  FLOOR_SIZE / 2.0, NUM_TILE_WRAPS, 0.0,
     FLOOR_SIZE / 2.0, 0.0,  FLOOR_SIZE / 2.0, NUM_TILE_WRAPS, NUM_TILE_WRAPS,
    -FLOOR_SIZE / 2.0, 0.0, -FLOOR_SIZE / 2.0, 0.0, 0.0,
     FLOOR_SIZE / 2.0, 0.0,  FLOOR_SIZE / 2.0, NUM_TILE_WRAPS, NUM_TILE_WRAPS,
     FLOOR_SIZE / 2.0, 0.0, -FLOOR_SIZE / 2.0, 0.0, NUM_TILE_WRAPS
};

pub const Floor = struct {
    floor_vao: gl.Uint,
    floor_vbo: gl.Uint,
    texture_floor_diffuse: Texture,
    texture_floor_normal: Texture,
    texture_floor_spec: Texture,

    const Self = @This();

    pub fn new() Self {
        const texture_config = TextureConfig {
            flip_v: false,
            flip_h: false,
            gamma_correction: false,
            filter: TextureFilter.Linear,
            texture_type: TextureType.None,
            wrap: TextureWrap.Repeat,
        };

        const texture_floor_diffuse = Texture.new("assets/Models/Floor D.png", &texture_config);
        const texture_floor_normal = Texture.new("assets/Models/Floor N.png", &texture_config);
        const texture_floor_spec = Texture.new("assets/Models/Floor M.png", &texture_config);

        var floor_vao: gl.Uint = 0;
        var floor_vbo: gl.Uint = 0;


            gl.genVertexArrays(1, &floor_vao);
            gl.genBuffers(1, &floor_vbo);
            gl.bindVertexArray(floor_vao);
            gl.bindBuffer(gl.ARRAY_BUFFER, floor_vbo);
            gl.bufferData(
                gl.ARRAY_BUFFER,
                (FLOOR_VERTICES.len() * SIZE_OF_FLOAT),
                FLOOR_VERTICES.as_ptr(),
                gl.STATIC_DRAW,
            );
            gl.vertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, (5 * SIZE_OF_FLOAT), null);
            gl.enableVertexAttribArray(0);
            gl.vertexAttribPointer(1, 2, gl.FLOAT, gl.FALSE, (5 * SIZE_OF_FLOAT), (3 * SIZE_OF_FLOAT));
            gl.enableVertexAttribArray(1);
        }

        Self {
            floor_vao,
            floor_vbo,
            texture_floor_diffuse,
            texture_floor_normal,
            texture_floor_spec,
        }
    }

    pub fn draw(&self, shader: &Shader, projection_view: &Mat4) {
        shader.use_shader();

        bind_texture(shader, 0, "texture_diffuse", &self.texture_floor_diffuse);
        bind_texture(shader, 1, "texture_normal", &self.texture_floor_normal);
        bind_texture(shader, 2, "texture_spec", &self.texture_floor_spec);

        // angle floor
        const _model = Mat4.from_axis_angle(vec3(0.0, 1.0, 0.0), 45.0f32.to_radians());

        const model = Mat4.IDENTITY;

        shader.set_mat4("PV", projection_view);
        shader.set_mat4("model", &model);


            gl.bindVertexArray(self.floor_vao);
            gl.drawArrays(gl.TRIANGLES, 0, 6);
            gl.bindVertexArray(0);
        }
    }
}
