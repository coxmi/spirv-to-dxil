//! Zig bindings for the spirv_to_dxil C library.
//!
//! Mirrors the API in spirv_to_dxil.h with C-compatible types and extern fns.

const std = @import("std");

pub const ShaderStage = enum(c_int) {
    none = -1,
    vertex = 0,
    tess_ctrl = 1,
    tess_eval = 2,
    geometry = 3,
    fragment = 4,
    compute = 5,
    kernel = 14,
};

pub const ShaderModel = enum(c_int) {
    sm_6_0 = 0x60000,
    sm_6_1,
    sm_6_2,
    sm_6_3,
    sm_6_4,
    sm_6_5,
    sm_6_6,
    sm_6_7,
    sm_6_8,
};

pub const ValidatorVersion = enum(c_int) {
    none = 0,
    v1_0 = 0x10000,
    v1_1,
    v1_2,
    v1_3,
    v1_4,
    v1_5,
    v1_6,
    v1_7,
    v1_8,
};

pub const SysvalType = enum(c_int) {
    zero = 0,
    native = 1,
    runtime_data = 2,
};

pub const YZFlipMode = enum(c_int) {
    none = 0,
    y_flip_unconditional = 1 << 0,
    z_flip_unconditional = 1 << 1,
    yz_flip_unconditional = (1 << 0) | (1 << 1),
    y_flip_conditional = 1 << 2,
    z_flip_conditional = 1 << 3,
    yz_flip_conditional = (1 << 2) | (1 << 3),
};

pub const RuntimeConfig = extern struct {
    runtime_data_cbv: Binding,
    push_constant_cbv: Binding,
    first_vertex_and_base_instance_mode: SysvalType,
    workgroup_id_mode: SysvalType,
    yz_flip: YZFlip,
    declared_read_only_images_as_srvs: bool,
    inferred_read_only_images_as_srvs: bool,
    force_sample_rate_shading: bool,
    lower_view_index: bool,
    lower_view_index_to_rt_layer: bool,
    shader_model_max: ShaderModel,

    pub const Binding = extern struct {
        space: u32,
        base: u32,
    };

    pub const YZFlip = extern struct {
        mode: YZFlipMode,
        y_mask: u16,
        z_mask: u16,
    };

    /// zeroed config with a working default shader model
    pub fn init() RuntimeConfig {
        var c: RuntimeConfig = std.mem.zeroes(RuntimeConfig);
        c.shader_model_max = .sm_6_2;
        return c;
    }
};

pub const DebugOptions = extern struct {
    dump_nir: bool,
};

pub const Logger = extern struct {
    priv: ?*anyopaque,
    log: ?*const fn (?*anyopaque, [*:0]const u8) callconv(.c) void,
};

pub const Object = extern struct {
    metadata: Metadata,
    binary: Binary,

    pub const Binary = extern struct {
        buffer: ?*anyopaque,
        size: usize,
    };

    pub const Metadata = extern struct {
        requires_runtime_data: bool,
        needs_draw_sysvals: bool,
    };
};

pub extern fn spirv_to_dxil(
    words: [*]const u32,
    word_count: usize,
    specializations: ?*anyopaque,
    num_specializations: c_uint,
    stage: ShaderStage,
    entry_point: [*:0]const u8,
    validator_version_max: ValidatorVersion,
    debug_options: ?*const DebugOptions,
    conf: ?*const RuntimeConfig,
    logger: ?*const Logger,
    out: *Object,
) bool;

pub extern fn spirv_to_dxil_free(dxil: *Object) void;

pub extern fn spirv_to_dxil_get_version() u64;

/// one-shot conversion options, defaults match the fixture happy path
pub const Options = struct {
    entry_point: [:0]const u8 = "main",
    validator_version_max: ValidatorVersion = .v1_4,
    shader_model_max: ShaderModel = .sm_6_2,
};

/// convert SPIR-V bytes to DXIL bytes in one shot. zeroes the debug options,
/// logger, and config (shader model from `options`), and frees the library
/// binary after copying, so the caller only frees the returned slice
pub fn convert(
    allocator: std.mem.Allocator,
    spirv: []const u8,
    stage: ShaderStage,
    options: Options,
) ![]u8 {
    if (spirv.len == 0 or spirv.len % 4 != 0) return error.InvalidSpirvSize;

    // the library reads SPIR-V as u32 words, so go through an aligned copy
    const words_buf = try allocator.alignedAlloc(u8, .of(u32), spirv.len);
    defer allocator.free(words_buf);
    @memcpy(words_buf, spirv);

    var conf = RuntimeConfig.init();
    conf.shader_model_max = options.shader_model_max;
    var debug: DebugOptions = std.mem.zeroes(DebugOptions);
    var logger: Logger = std.mem.zeroes(Logger);
    var out: Object = std.mem.zeroes(Object);
    if (!spirv_to_dxil(
        @ptrCast(words_buf.ptr),
        words_buf.len / 4,
        null,
        0,
        stage,
        options.entry_point.ptr,
        options.validator_version_max,
        &debug,
        &conf,
        &logger,
        &out,
    )) return error.ConvertFailed;
    defer spirv_to_dxil_free(&out);

    const binary = out.binary.buffer orelse return error.ConvertFailed;
    return allocator.dupe(u8, @as([*]const u8, @ptrCast(binary))[0..out.binary.size]);
}

/// read `path` (relative to the cwd) then convert, in one shot
pub fn convertFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    path: []const u8,
    stage: ShaderStage,
    options: Options,
) ![]u8 {
    const data = try std.Io.Dir.cwd().readFileAllocOptions(io, path, allocator, .unlimited, .of(u32), null);
    defer allocator.free(data);
    return convert(allocator, data, stage, options);
}

// upstream spirv_to_dxil derefs debug_options/logger unconditionally
// (mesa/nir_to_dxil bug), so tests always pass non-null values

test "links and reports a version" {
    try std.testing.expect(spirv_to_dxil_get_version() != 0);
}

test "converts spv fixtures to dxil" {

    const Fixture = struct {
        path: []const u8,
        stage: ShaderStage,
    };

    const fixtures = [_]Fixture{
        .{ .path = "src/spv/array_textures.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/compute.comp.spv", .stage = .compute },
        .{ .path = "src/spv/image_atomic.comp.spv", .stage = .compute },
        .{ .path = "src/spv/multiple_render_targets.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/multisampled_combined.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/multisampled.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/phong.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/push_constants.vert.spv", .stage = .vertex },
        .{ .path = "src/spv/samplerless.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/storage_image.frag.spv", .stage = .fragment },
        // tessellation_control.tesc.spv excluded: mesa 26.2.2 can't compile a
        // standalone TCS (primitive mode only set from a linked domain shader, so
        // _primitive_mode stays UNSPECIFIED and dxil_nir_fixup_tess_level_for_domain
        // frees gl_TessLevelInner wrongly -> crash). the .tesc.spv is valid.
        .{ .path = "src/spv/tessellation_evaluation.tese.spv", .stage = .tess_eval },
        .{ .path = "src/spv/texture_displace.vert.spv", .stage = .vertex },
        .{ .path = "src/spv/texture_gather.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/triangle.frag.spv", .stage = .fragment },
        .{ .path = "src/spv/triangle.vert.spv", .stage = .vertex },
    };
    
    const t = std.testing;
    var passed: usize = 0;
    for (fixtures) |fx| {
        const dxil = convertFile(t.allocator, t.io, fx.path, fx.stage, .{}) catch {
            std.debug.print("FAIL {s}\n", .{fx.path});
            continue;
        };
        t.allocator.free(dxil);
        passed += 1;
    }
    try t.expectEqual(fixtures.len, passed);
}