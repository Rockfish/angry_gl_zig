const std = @import("std");
const math = std.math;
const assert = std.debug.assert;
const glfw = @import("zglfw");
const zopengl = @import("zopengl");
const zgui = @import("zgui");
const zstbi = @import("zstbi");
const gl = zopengl.bindings;

const Allocator = std.mem.Allocator;

const content_dir = @import("build_options").content_dir;
const window_title = "gui settings";

// only works if file is in the current package
//const embedded_font_data = @embedFile("../../assets/fonts/FiraCode-Medium.ttf");

const State = struct {
    texture: *Texture,
    font_normal: zgui.Font,
    font_large: zgui.Font,
    alloced_input_text_buf: [:0]u8,
    alloced_input_text_multiline_buf: [:0]u8,
    alloced_input_text_with_hint_buf: [:0]u8,
};

//var _te: *zgui.te.TestEngine = undefined;

var frame_counter: FrameCount = undefined;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    try glfw.init();
    defer glfw.terminate();

    // Change current working directory to where the executable is located.
    {
        var buffer: [1024]u8 = undefined;
        const path = std.fs.selfExeDirPath(buffer[0..]) catch ".";
        std.posix.chdir(path) catch {};
    }

    const gl_major = 4;
    const gl_minor = 0;
    glfw.windowHintTyped(.context_version_major, gl_major);
    glfw.windowHintTyped(.context_version_minor, gl_minor);
    glfw.windowHintTyped(.opengl_profile, .opengl_core_profile);
    glfw.windowHintTyped(.opengl_forward_compat, true);
    glfw.windowHintTyped(.client_api, .opengl_api);
    glfw.windowHintTyped(.doublebuffer, true);

    const window = try glfw.Window.create(1600, 1000, window_title, null);
    defer window.destroy();

    glfw.makeContextCurrent(window);
    glfw.swapInterval(1);

    window.setSizeLimits(400, 400, -1, -1);

    try zopengl.loadCoreProfile(glfw.getProcAddress, gl_major, gl_minor);

    gl.enable(gl.DEPTH_TEST);

    const code = try create(allocator, window);
    defer destroy(allocator, code);

    frame_counter = FrameCount.new();

    while (!window.shouldClose() and window.getKey(.escape) != .press) {
        glfw.pollEvents();

        gl.clearColor(0.05, 0.4, 0.05, 1.0);
        gl.clear(gl.COLOR_BUFFER_BIT | gl.DEPTH_BUFFER_BIT);

        try update(code);

        draw(code);

        window.swapBuffers();
    }
}

fn create(allocator: std.mem.Allocator, window: *glfw.Window) !*State {
    const texture = try Texture.new(allocator, content_dir ++ "images/genart_0025_5.png");

    zgui.init(allocator);

    const scale_factor = scale_factor: {
        const scale = window.getContentScale();
        break :scale_factor @max(scale[0], scale[1]);
    };

    const font_size = 16.0 * scale_factor;
    const font_large = zgui.io.addFontFromFile(content_dir ++ "fonts/FiraCode-Medium.ttf", math.floor(font_size));
    const font_normal = zgui.io.addFontFromFile(content_dir ++ "fonts/Roboto-Medium.ttf", math.floor(font_size));

    assert(zgui.io.getFont(0) == font_large);
    assert(zgui.io.getFont(1) == font_normal);

    // This needs to be called *after* adding your custom fonts.
    zgui.backend.init(window);

    // This call is optional. Initially, zgui.io.getFont(0) is a default font.
    zgui.io.setDefaultFont(font_normal);

    // You can directly manipulate zgui.Style *before* `newFrame()` call.
    // Once frame is started (after `newFrame()` call) you have to use
    // zgui.pushStyleColor*()/zgui.pushStyleVar*() functions.
    const style = zgui.getStyle();

    style.window_min_size = .{ 320.0, 240.0 };
    style.scrollbar_size = 6.0;
    var color = style.getColor(.scrollbar_grab);
    color[1] = 0.8;
    style.setColor(.scrollbar_grab, color);
    style.scaleAllSizes(scale_factor);

    const state = try allocator.create(State);
    state.* = .{
        .texture = texture,
        .font_normal = font_normal,
        .font_large = font_large,
        .alloced_input_text_buf = try allocator.allocSentinel(u8, 4, 0),
        .alloced_input_text_multiline_buf = try allocator.allocSentinel(u8, 4, 0),
        .alloced_input_text_with_hint_buf = try allocator.allocSentinel(u8, 4, 0),
    };

    state.alloced_input_text_buf[0] = 0;
    state.alloced_input_text_multiline_buf[0] = 0;
    state.alloced_input_text_with_hint_buf[0] = 0;

    return state;
}

fn destroy(allocator: std.mem.Allocator, state: *State) void {
    zgui.backend.deinit();
    zgui.deinit();
    state.texture.deinit();
    allocator.free(state.alloced_input_text_buf);
    allocator.free(state.alloced_input_text_multiline_buf);
    allocator.free(state.alloced_input_text_with_hint_buf);
    allocator.destroy(state);
}

var check_b = false;

const SimpleEnum = enum {
    first,
    second,
    third,
};
const SparseEnum = enum(i32) {
    first = 10,
    second = 100,
    third = 1000,
};
const NonExhaustiveEnum = enum(i32) {
    first = 10,
    second = 100,
    third = 1000,
    _,
};

fn update(state: *State) !void {
    frame_counter.update();

    zgui.backend.newFrame(
        1600.0,
        1000.0,
    );

    zgui.setNextWindowPos(.{ .x = 20.0, .y = 20.0, .cond = .first_use_ever });
    zgui.setNextWindowSize(.{ .w = -1.0, .h = -1.0, .cond = .first_use_ever });

    zgui.pushStyleVar1f(.{ .idx = .window_rounding, .v = 5.0 });
    zgui.pushStyleVar2f(.{ .idx = .window_padding, .v = .{ 5.0, 5.0 } });
    defer zgui.popStyleVar(.{ .count = 2 });

    if (zgui.begin("Settings", .{})) {
        zgui.bullet();
        zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Average :");
        zgui.sameLine(.{});
        zgui.text(
            "{d:.3} ms/frame ({d:.1} fps)",
            .{ frame_counter.frame_time, frame_counter.fps }, // todo: fix
        );

        zgui.pushFont(state.font_large);
        zgui.separator();
        zgui.dummy(.{ .w = -1.0, .h = 20.0 });
        zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "zgui -");
        zgui.sameLine(.{});
        zgui.textWrapped("Zig bindings for 'dear imgui' library. " ++
            "Easy to use, hand-crafted API with default arguments, " ++
            "named parameters and Zig style text formatting.", .{});
        zgui.dummy(.{ .w = -1.0, .h = 20.0 });
        zgui.separator();
        zgui.popFont();

        if (zgui.collapsingHeader("Widgets: Main", .{})) {
            zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Button");
            if (zgui.button("Button 1", .{ .w = 200.0 })) {
                // 'Button 1' pressed.
            }
            zgui.sameLine(.{ .spacing = 20.0 });
            if (zgui.button("Button 2", .{ .h = 60.0 })) {
                // 'Button 2' pressed.
            }
            zgui.sameLine(.{});
            {
                const label = "Button 3 is special ;)";
                const s = zgui.calcTextSize(label, .{});
                _ = zgui.button(label, .{ .w = s[0] + 30.0 });
            }
            zgui.sameLine(.{});
            _ = zgui.button("Button 4", .{});
            _ = zgui.button("Button 5", .{ .w = -1.0, .h = 100.0 });

            zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 1.0, 0.0, 0.0, 1.0 } });
            _ = zgui.button("  Red Text Button  ", .{});
            zgui.popStyleColor(.{});

            zgui.sameLine(.{});
            zgui.pushStyleColor4f(.{ .idx = .text, .c = .{ 1.0, 1.0, 0.0, 1.0 } });
            _ = zgui.button("  Yellow Text Button  ", .{});
            zgui.popStyleColor(.{});

            _ = zgui.smallButton("  Small Button  ");
            zgui.sameLine(.{});
            _ = zgui.arrowButton("left_button_id", .{ .dir = .left });
            zgui.sameLine(.{});
            _ = zgui.arrowButton("right_button_id", .{ .dir = .right });
            zgui.spacing();

            const static = struct {
                var check0: bool = true;
                var bits: u32 = 0xf;
                var radio_value: u32 = 1;
                var month: i32 = 1;
                var progress: f32 = 0.0;
            };
            zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Checkbox");
            _ = zgui.checkbox("Magic Is Everywhere", .{ .v = &static.check0 });
            zgui.spacing();

            zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Checkbox bits");
            zgui.text("Bits value: {b} ({d})", .{ static.bits, static.bits });
            _ = zgui.checkboxBits("Bit 0", .{ .bits = &static.bits, .bits_value = 0x1 });
            _ = zgui.checkboxBits("Bit 1", .{ .bits = &static.bits, .bits_value = 0x2 });
            _ = zgui.checkboxBits("Bit 2", .{ .bits = &static.bits, .bits_value = 0x4 });
            _ = zgui.checkboxBits("Bit 3", .{ .bits = &static.bits, .bits_value = 0x8 });
            zgui.spacing();

            zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Radio buttons");
            if (zgui.radioButton("One", .{ .active = static.radio_value == 1 })) static.radio_value = 1;
            if (zgui.radioButton("Two", .{ .active = static.radio_value == 2 })) static.radio_value = 2;
            if (zgui.radioButton("Three", .{ .active = static.radio_value == 3 })) static.radio_value = 3;
            if (zgui.radioButton("Four", .{ .active = static.radio_value == 4 })) static.radio_value = 4;
            if (zgui.radioButton("Five", .{ .active = static.radio_value == 5 })) static.radio_value = 5;
            zgui.spacing();

            _ = zgui.radioButtonStatePtr("January", .{ .v = &static.month, .v_button = 1 });
            zgui.sameLine(.{});
            _ = zgui.radioButtonStatePtr("February", .{ .v = &static.month, .v_button = 2 });
            zgui.sameLine(.{});
            _ = zgui.radioButtonStatePtr("March", .{ .v = &static.month, .v_button = 3 });
            zgui.spacing();

            zgui.textUnformattedColored(.{ 0, 0.8, 0, 1 }, "Progress bar");
            zgui.progressBar(.{ .fraction = static.progress });
            static.progress += 0.005;
            if (static.progress > 1.0) static.progress = 0.0;
            zgui.spacing();

            zgui.bulletText("keep going...", .{});
        }

        if (zgui.collapsingHeader("Widgets: Combo Box", .{})) {
            const static = struct {
                var selection_index: u32 = 0;
                var current_item: i32 = 0;
                var simple_enum_value: SimpleEnum = .first;
                var sparse_enum_value: SparseEnum = .first;
                var non_exhaustive_enum_value: NonExhaustiveEnum = .first;
            };

            const items = [_][:0]const u8{ "aaa", "bbb", "ccc", "ddd", "eee", "FFF", "ggg", "hhh" };
            if (zgui.beginCombo("Combo 0", .{ .preview_value = items[static.selection_index] })) {
                for (items, 0..) |item, index| {
                    const i = @as(u32, @intCast(index));
                    if (zgui.selectable(item, .{ .selected = static.selection_index == i }))
                        static.selection_index = i;
                }
                zgui.endCombo();
            }

            _ = zgui.combo("Combo 1", .{
                .current_item = &static.current_item,
                .items_separated_by_zeros = "Item 0\x00Item 1\x00Item 2\x00Item 3\x00\x00",
            });

            _ = zgui.comboFromEnum("simple enum", &static.simple_enum_value);
            _ = zgui.comboFromEnum("sparse enum", &static.sparse_enum_value);
            _ = zgui.comboFromEnum("non-exhaustive enum", &static.non_exhaustive_enum_value);
        }

        if (zgui.collapsingHeader("Widgets: Drag Sliders", .{})) {
            const static = struct {
                var v1: f32 = 0.0;
                var v2: [2]f32 = .{ 0.0, 0.0 };
                var v3: [3]f32 = .{ 0.0, 0.0, 0.0 };
                var v4: [4]f32 = .{ 0.0, 0.0, 0.0, 0.0 };
                var range: [2]f32 = .{ 0.0, 0.0 };
                var v1i: i32 = 0.0;
                var v2i: [2]i32 = .{ 0, 0 };
                var v3i: [3]i32 = .{ 0, 0, 0 };
                var v4i: [4]i32 = .{ 0, 0, 0, 0 };
                var rangei: [2]i32 = .{ 0, 0 };
                var si8: i8 = 123;
                var vu16: [3]u16 = .{ 10, 11, 12 };
                var sd: f64 = 0.0;
            };
            _ = zgui.dragFloat("Drag float 1", .{ .v = &static.v1 });
            _ = zgui.dragFloat2("Drag float 2", .{ .v = &static.v2 });
            _ = zgui.dragFloat3("Drag float 3", .{ .v = &static.v3 });
            _ = zgui.dragFloat4("Drag float 4", .{ .v = &static.v4 });
            _ = zgui.dragFloatRange2(
                "Drag float range 2",
                .{ .current_min = &static.range[0], .current_max = &static.range[1] },
            );
            _ = zgui.dragInt("Drag int 1", .{ .v = &static.v1i });
            _ = zgui.dragInt2("Drag int 2", .{ .v = &static.v2i });
            _ = zgui.dragInt3("Drag int 3", .{ .v = &static.v3i });
            _ = zgui.dragInt4("Drag int 4", .{ .v = &static.v4i });
            _ = zgui.dragIntRange2(
                "Drag int range 2",
                .{ .current_min = &static.rangei[0], .current_max = &static.rangei[1] },
            );
            _ = zgui.dragScalar("Drag scalar (i8)", i8, .{ .v = &static.si8, .min = -20 });
            _ = zgui.dragScalarN(
                "Drag scalar N ([3]u16)",
                @TypeOf(static.vu16),
                .{ .v = &static.vu16, .max = 100 },
            );
            _ = zgui.dragScalar(
                "Drag scalar (f64)",
                f64,
                .{ .v = &static.sd, .min = -1.0, .max = 1.0, .speed = 0.005 },
            );
        }

        if (zgui.collapsingHeader("Widgets: Regular Sliders", .{})) {
            const static = struct {
                var v1: f32 = 0;
                var v2: [2]f32 = .{ 0, 0 };
                var v3: [3]f32 = .{ 0, 0, 0 };
                var v4: [4]f32 = .{ 0, 0, 0, 0 };
                var v1i: i32 = 0;
                var v2i: [2]i32 = .{ 0, 0 };
                var v3i: [3]i32 = .{ 10, 10, 10 };
                var v4i: [4]i32 = .{ 0, 0, 0, 0 };
                var su8: u8 = 1;
                var vu16: [3]u16 = .{ 10, 11, 12 };
                var vsf: f32 = 0;
                var vsi: i32 = 0;
                var vsu8: u8 = 1;
                var angle: f32 = 0;
            };
            _ = zgui.sliderFloat("Slider float 1", .{ .v = &static.v1, .min = 0.0, .max = 1.0 });
            _ = zgui.sliderFloat2("Slider float 2", .{ .v = &static.v2, .min = -1.0, .max = 1.0 });
            _ = zgui.sliderFloat3("Slider float 3", .{ .v = &static.v3, .min = 0.0, .max = 1.0 });
            _ = zgui.sliderFloat4("Slider float 4", .{ .v = &static.v4, .min = 0.0, .max = 1.0 });
            _ = zgui.sliderInt("Slider int 1", .{ .v = &static.v1i, .min = 0, .max = 100 });
            _ = zgui.sliderInt2("Slider int 2", .{ .v = &static.v2i, .min = -20, .max = 20 });
            _ = zgui.sliderInt3("Slider int 3", .{ .v = &static.v3i, .min = 10, .max = 50 });
            _ = zgui.sliderInt4("Slider int 4", .{ .v = &static.v4i, .min = 0, .max = 10 });
            _ = zgui.sliderScalar(
                "Slider scalar (u8)",
                u8,
                .{ .v = &static.su8, .min = 0, .max = 100, .cfmt = "%Xh" },
            );
            _ = zgui.sliderScalarN(
                "Slider scalar N ([3]u16)",
                [3]u16,
                .{ .v = &static.vu16, .min = 1, .max = 100 },
            );
            _ = zgui.sliderAngle("Slider angle", .{ .vrad = &static.angle });
            _ = zgui.vsliderFloat(
                "VSlider float",
                .{ .w = 80.0, .h = 200.0, .v = &static.vsf, .min = 0.0, .max = 1.0 },
            );
            zgui.sameLine(.{});
            _ = zgui.vsliderInt(
                "VSlider int",
                .{ .w = 80.0, .h = 200.0, .v = &static.vsi, .min = 0, .max = 100 },
            );
            zgui.sameLine(.{});
            _ = zgui.vsliderScalar(
                "VSlider scalar (u8)",
                u8,
                .{ .w = 80.0, .h = 200.0, .v = &static.vsu8, .min = 0, .max = 200 },
            );
        }

        if (zgui.collapsingHeader("Widgets: Input with Keyboard", .{})) {
            const static = struct {
                var input_text_buf = [_:0]u8{0} ** 4;
                var input_text_multiline_buf = [_:0]u8{0} ** 4;
                var input_text_with_hint_buf = [_:0]u8{0} ** 4;
                var v1: f32 = 0;
                var v2: [2]f32 = .{ 0, 0 };
                var v3: [3]f32 = .{ 0, 0, 0 };
                var v4: [4]f32 = .{ 0, 0, 0, 0 };
                var v1i: i32 = 0;
                var v2i: [2]i32 = .{ 0, 0 };
                var v3i: [3]i32 = .{ 0, 0, 0 };
                var v4i: [4]i32 = .{ 0, 0, 0, 0 };
                var sf64: f64 = 0.0;
                var si8: i8 = 0;
                var v3u8: [3]u8 = .{ 0, 0, 0 };
            };
            zgui.separatorText("static input text");
            _ = zgui.inputText("Input text", .{ .buf = static.input_text_buf[0..] });
            _ = zgui.text("length of Input text {}", .{std.mem.len(@as([*:0]u8, static.input_text_buf[0..]))});

            _ = zgui.inputTextMultiline("Input text multiline", .{ .buf = static.input_text_multiline_buf[0..] });
            _ = zgui.text("length of Input text multiline {}", .{std.mem.len(@as([*:0]u8, static.input_text_multiline_buf[0..]))});
            _ = zgui.inputTextWithHint("Input text with hint", .{
                .hint = "Enter your name",
                .buf = static.input_text_with_hint_buf[0..],
            });
            _ = zgui.text("length of Input text with hint {}", .{std.mem.len(@as([*:0]u8, static.input_text_with_hint_buf[0..]))});

            zgui.separatorText("alloced input text");
            _ = zgui.inputText("Input text alloced", .{ .buf = state.alloced_input_text_buf });
            _ = zgui.text("length of Input text alloced {}", .{std.mem.len(state.alloced_input_text_buf.ptr)});
            _ = zgui.inputTextMultiline("Input text multiline alloced", .{ .buf = state.alloced_input_text_multiline_buf });
            _ = zgui.text("length of Input text multiline {}", .{std.mem.len(state.alloced_input_text_multiline_buf.ptr)});
            _ = zgui.inputTextWithHint("Input text with hint alloced", .{
                .hint = "Enter your name",
                .buf = state.alloced_input_text_with_hint_buf,
            });
            _ = zgui.text("length of Input text with hint alloced {}", .{std.mem.len(state.alloced_input_text_with_hint_buf.ptr)});

            zgui.separatorText("input numeric");
            _ = zgui.inputFloat("Input float 1", .{ .v = &static.v1 });
            _ = zgui.inputFloat2("Input float 2", .{ .v = &static.v2 });
            _ = zgui.inputFloat3("Input float 3", .{ .v = &static.v3 });
            _ = zgui.inputFloat4("Input float 4", .{ .v = &static.v4 });
            _ = zgui.inputInt("Input int 1", .{ .v = &static.v1i });
            _ = zgui.inputInt2("Input int 2", .{ .v = &static.v2i });
            _ = zgui.inputInt3("Input int 3", .{ .v = &static.v3i });
            _ = zgui.inputInt4("Input int 4", .{ .v = &static.v4i });
            _ = zgui.inputDouble("Input double", .{ .v = &static.sf64 });
            _ = zgui.inputScalar("Input scalar (i8)", i8, .{ .v = &static.si8 });
            _ = zgui.inputScalarN("Input scalar N ([3]u8)", [3]u8, .{ .v = &static.v3u8 });
        }

        if (zgui.collapsingHeader("Widgets: Color Editor/Picker", .{})) {
            const static = struct {
                var col3: [3]f32 = .{ 0, 0, 0 };
                var col4: [4]f32 = .{ 0, 1, 0, 0 };
                var col3p: [3]f32 = .{ 0, 0, 0 };
                var col4p: [4]f32 = .{ 0, 0, 0, 0 };
            };
            _ = zgui.colorEdit3("Color edit 3", .{ .col = &static.col3 });
            _ = zgui.colorEdit4("Color edit 4", .{ .col = &static.col4 });
            _ = zgui.colorEdit4("Color edit 4 float", .{ .col = &static.col4, .flags = .{ .float = true } });
            _ = zgui.colorPicker3("Color picker 3", .{ .col = &static.col3p });
            _ = zgui.colorPicker4("Color picker 4", .{ .col = &static.col4p });
            _ = zgui.colorButton("color_button_id", .{ .col = .{ 0, 1, 0, 1 } });
        }

        if (zgui.collapsingHeader("Widgets: Trees", .{})) {
            if (zgui.treeNodeStrId("tree_id", "My Tree {d}", .{1})) {
                zgui.textUnformatted("Some content...");
                zgui.treePop();
            }
            if (zgui.collapsingHeader("Collapsing header 1", .{})) {
                zgui.textUnformatted("Some content...");
            }
        }

        if (zgui.collapsingHeader("Widgets: List Boxes", .{})) {
            const static = struct {
                var selection_index: u32 = 0;
            };
            const items = [_][:0]const u8{ "aaa", "bbb", "ccc", "ddd", "eee", "FFF", "ggg", "hhh" };
            if (zgui.beginListBox("List Box 0", .{})) {
                for (items, 0..) |item, index| {
                    const i = @as(u32, @intCast(index));
                    if (zgui.selectable(item, .{ .selected = static.selection_index == i }))
                        static.selection_index = i;
                }
                zgui.endListBox();
            }
        }

        if (zgui.collapsingHeader("Widgets: Image", .{})) {
            const tex_id = state.texture.id;
            _ = zgui.imageButton(
                "image_button_id",
                @ptrFromInt(tex_id),
                .{ .w = 100.0, .h = 100.0 },
            );
            zgui.image(
                @ptrFromInt(tex_id),
                .{ .w = @floatFromInt(state.texture.width), .h = @floatFromInt(state.texture.height) },
            );
        }
    }
    zgui.end();
}

fn draw(state: *State) void {
    _ = state;

    zgui.backend.draw();
}

pub const Texture = struct {
    id: u32,
    width: u32,
    height: u32,
    allocator: Allocator,

    const Self = @This();

    pub fn deinit(self: *const Texture) void {
        self.allocator.destroy(self);
    }

    pub fn new(allocator: std.mem.Allocator, path: [:0]const u8) !*Texture {
        zstbi.init(allocator);
        defer zstbi.deinit();

        // zstbi.setFlipVerticallyOnLoad(texture_config.flip_v);

        var image = zstbi.Image.loadFromFile(path, 0) catch |err| {
            std.debug.print("Texture loadFromFile error: {any}  filepath: {s}\n", .{ err, path });
            @panic(@errorName(err));
        };
        defer image.deinit();

        const format: u32 = switch (image.num_components) {
            0 => gl.RED,
            3 => gl.RGB,
            4 => gl.RGBA,
            else => gl.RED,
        };

        var texture_id: gl.Uint = undefined;

        // std.debug.print("Texture: generating a texture\n", .{});
        gl.genTextures(1, &texture_id);

        // std.debug.print("Texture: binding a texture\n", .{});
        gl.bindTexture(gl.TEXTURE_2D, texture_id);

        gl.texImage2D(
            gl.TEXTURE_2D,
            0,
            format,
            @intCast(image.width),
            @intCast(image.height),
            0,
            format,
            gl.UNSIGNED_BYTE,
            image.data.ptr,
        );

        gl.generateMipmap(gl.TEXTURE_2D);

        const wrap_param: i32 = gl.REPEAT;

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, wrap_param);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, wrap_param);

        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR_MIPMAP_LINEAR);
        gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);

        const texture = try allocator.create(Texture);
        texture.* = Texture{
            .id = texture_id,
            .width = image.width,
            .height = image.height,
            .allocator = allocator,
        };
        return texture;
    }
};

pub const FrameCount = struct {
    last_printed_instant: i64,
    frame_count: f32,
    fps: f32,
    frame_time: f32,

    const Self = @This();

    pub fn new() Self {
        return .{
            .last_printed_instant = std.time.milliTimestamp(),
            .frame_count = 0.0,
            .frame_time = 0.0,
            .fps = 0.0,
        };
    }

    pub fn update(self: *Self) void {
        self.frame_count += 1.0;

        const new_instant = std.time.milliTimestamp();
        const diff: f32 = @floatFromInt(new_instant - self.last_printed_instant);
        const elapsed_secs: f32 = diff / 1000.0;

        if (elapsed_secs > 1.0) {
            const elapsed_ms = elapsed_secs * 1000.0;
            self.frame_time = elapsed_ms / self.frame_count;
            self.fps = self.frame_count / elapsed_secs;
            //std.debug.print("FPS: {d:.4}  Frame time {d:.2}ms\n", .{self.fps, self.frame_time});
            self.last_printed_instant = new_instant;
            self.frame_count = 0.0;
        }
    }
};
