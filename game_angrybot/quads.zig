const zopengl = @import("zopengl");
const gl = zopengl.bindings;

const SIZE_OF_FLOAT = @sizeOf(f32);

const UNIT_SQUARE: [30]f32 = .{
    -1.0, -1.0, 0.0, 0.0, 0.0,
     1.0, -1.0, 0.0, 1.0, 0.0,
     1.0,  1.0, 0.0, 1.0, 1.0,
    -1.0, -1.0, 0.0, 0.0, 0.0,
     1.0,  1.0, 0.0, 1.0, 1.0,
    -1.0,  1.0, 0.0, 0.0, 1.0,
};

const MORE_OBNOXIOUS_QUAD: [30]f32 = .{
    -1.0, -1.0, -0.9, 0.0, 0.0,
     1.0, -1.0, -0.9, 1.0, 0.0,
     1.0,  1.0, -0.9, 1.0, 1.0,
    -1.0, -1.0, -0.9, 0.0, 0.0,
     1.0,  1.0, -0.9, 1.0, 1.0,
    -1.0,  1.0, -0.9, 0.0, 1.0,
};

const OBNOXIOUS_QUAD: [30]f32 = .{
    0.5, 0.5, -0.9, 0.0, 0.0,
    1.0, 0.5, -0.9, 1.0, 0.0,
    1.0, 1.0, -0.9, 1.0, 1.0,
    0.5, 0.5, -0.9, 0.0, 0.0,
    1.0, 1.0, -0.9, 1.0, 1.0,
    0.5, 1.0, -0.9, 0.0, 1.0,
};

pub fn createObnoxiousQuadVao() gl.Uint {
    var obnoxious_quad_vao: gl.Uint = 0;
    var obnoxious_quad_vbo: gl.Uint = 0;

    gl.genVertexArrays(1, &obnoxious_quad_vao);
    gl.genBuffers(1, &obnoxious_quad_vbo);
    gl.bindVertexArray(obnoxious_quad_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, obnoxious_quad_vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        @intCast(OBNOXIOUS_QUAD.len() * SIZE_OF_FLOAT),
        &OBNOXIOUS_QUAD,
        gl.STATIC_DRAW,
    );
    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        (5 * SIZE_OF_FLOAT),
        null,
    );
    gl.EnableVertexAttribArray(0);
    gl.vertexAttribPointer(
        1,
        2,
        gl.FLOAT,
        gl.FALSE,
        (5 * SIZE_OF_FLOAT),
        @ptrFromInt(3 * SIZE_OF_FLOAT),
    );
    gl.EnableVertexAttribArray(1);
    return obnoxious_quad_vao;
}

pub fn createUnitSquareVao() gl.Uint {
    var unit_square_vao: gl.Uint = 0;
    var unit_square_vbo: gl.Uint = 0;

    gl.genVertexArrays(1, &unit_square_vao);
    gl.genBuffers(1, &unit_square_vbo);
    gl.bindVertexArray(unit_square_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, unit_square_vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        (UNIT_SQUARE.len * SIZE_OF_FLOAT),
        &UNIT_SQUARE,
        gl.STATIC_DRAW,
    );
    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        (5 * SIZE_OF_FLOAT),
        null,
    );
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(
        1,
        2,
        gl.FLOAT,
        gl.FALSE,
        (5 * SIZE_OF_FLOAT),
        @ptrFromInt(3 * SIZE_OF_FLOAT),
    );
    gl.enableVertexAttribArray(1);
    return unit_square_vao;
}

pub fn createMoreObnoxiousQuadVao() gl.Uint {
    var more_obnoxious_quad_vao: gl.Uint = 0;
    var more_obnoxious_quad_vbo: gl.Uint = 0;

    gl.genVertexArrays(1, &more_obnoxious_quad_vao);
    gl.genBuffers(1, &more_obnoxious_quad_vbo);
    gl.bindVertexArray(more_obnoxious_quad_vao);
    gl.bindBuffer(gl.ARRAY_BUFFER, more_obnoxious_quad_vbo);
    gl.bufferData(
        gl.ARRAY_BUFFER,
        (MORE_OBNOXIOUS_QUAD.len * SIZE_OF_FLOAT),
        &MORE_OBNOXIOUS_QUAD,
        gl.STATIC_DRAW,
    );
    gl.vertexAttribPointer(
        0,
        3,
        gl.FLOAT,
        gl.FALSE,
        (5 * SIZE_OF_FLOAT),
        null,
    );
    gl.enableVertexAttribArray(0);
    gl.vertexAttribPointer(
        1,
        2,
        gl.FLOAT,
        gl.FALSE,
        (5 * SIZE_OF_FLOAT),
        @ptrFromInt(3 * SIZE_OF_FLOAT),
    );
    gl.enableVertexAttribArray(1);
    return more_obnoxious_quad_vao;
}

pub fn renderQuad(quad_vao: *gl.Uint) void {
    // initialize (if necessary)
    if (*quad_vao == 0) {
        const quad_vertices: [20]f32 = .{
            // positions     // texture Coords
            -1.0,  1.0, 0.0, 0.0, 1.0,
            -1.0, -1.0, 0.0, 0.0, 0.0,
             1.0,  1.0, 0.0, 1.0, 1.0,
             1.0, -1.0, 0.0, 1.0, 0.0,
        };

        // setup plane VAO
        var quad_vbo: gl.Uint = 0;
        gl.genVertexArrays(1, quad_vao);
        gl.genBuffers(1, &quad_vbo);
        gl.bindVertexArray(*quad_vao);
        gl.bindBuffer(gl.ARRAY_BUFFER, quad_vbo);
        gl.bufferData(
            gl.ARRAY_BUFFER,
            (quad_vertices.len * SIZE_OF_FLOAT),
            &quad_vertices,
            gl.STATIC_DRAW,
        );
        gl.enableVertexAttribArray(0);
        gl.vertexAttribPointer(
            0,
            3,
            gl.FLOAT,
            gl.FALSE,
            (5 * SIZE_OF_FLOAT),
            null,
        );
        gl.enableVertexAttribArray(1);
        gl.vertexAttribPointer(
            1,
            2,
            gl.FLOAT,
            gl.FALSE,
            (5 * SIZE_OF_FLOAT),
            @ptrFromInt(3 * SIZE_OF_FLOAT),
        );
    }

    gl.bindVertexArray(*quad_vao);
    gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
    gl.bindVertexArray(0);
}
