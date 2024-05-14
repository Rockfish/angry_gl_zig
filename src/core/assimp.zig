pub const Assimp = @cImport({
    @cInclude("assimp/cimport.h");
    // @cInclude("assimp/mesh.h");
    @cInclude("assimp/scene.h");
    @cInclude("assimp/postprocess.h");
});

