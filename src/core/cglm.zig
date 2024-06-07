
pub const CGLM = @cImport({
    @cInclude("cglm/cglm.h");
    @cInclude("cglm/call.h");
    @cInclude("cglm/call/clipspace/ortho_rh_no.h");
    @cInclude("cglm/call/clipspace/persp_rh_no.h");
    @cInclude("cglm/call/clipspace/view_rh_no.h");
    // @cInclude("cglm/call/handed/euler_to_quat_rh.h");
});

