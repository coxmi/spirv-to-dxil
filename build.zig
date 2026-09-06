const std = @import("std");

pub fn build(b: *std.Build) !void {
    b.dependOnFileContents(b.path("mesa/VERSION"));
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // u_qsort (C++17) - compiled separately
    const qsort_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    qsort_mod.addCSourceFile(.{
        .file = b.path("mesa/src/util/u_qsort.cpp"),
        .flags = &.{"-std=c++17"},
    });
    const qsort = b.addLibrary(.{
        .name = "u_qsort",
        .root_module = qsort_mod,
    });

    // spirv_to_dxil (C11)
    const lib_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = false,
        .sanitize_c = .off,
        .sanitize_thread = false,
    });

    const c_flags = [_][]const u8{
        "-std=c11",
        "-fpermissive",
        "-Wno-unused-command-line-argument",
        "-Wno-unused-variable",
        "-Wno-missing-exception-spec",
        "-Wno-macro-redefined",
        "-Wno-unknown-attributes",
        "-Wno-implicit-fallthrough",
        "-fms-extensions",
    };

    // defines
    const defines = [_]struct { []const u8, ?[]const u8 }{
        .{ "HAVE_STRUCT_TIMESPEC", null },
        .{ "PACKAGE_VERSION", b.fmt("\"{s}\"", .{mesaVersion(b)}) },
        .{ "__STDC_CONSTANT_MACROS", null },
        .{ "__STDC_FORMAT_MACROS", null },
        .{ "__STDC_LIMIT_MACROS", null },
        .{ "M_E", "2.71828182845904523536" },
        .{ "M_LOG2E", "1.44269504088896340736" },
        .{ "M_LOG10E", "0.434294481903251827651" },
        .{ "M_LN2", "0.693147180559945309417" },
        .{ "M_LN10", "2.30258509299404568402" },
        .{ "M_PI", "3.14159265358979323846" },
        .{ "M_PI_2", "1.57079632679489661923" },
        .{ "M_PI_4", "0.785398163397448309616" },
        .{ "M_1_PI", "0.318309886183790671538" },
        .{ "M_2_PI", "0.636619772367581343076" },
        .{ "M_2_SQRTPI", "1.12837916709551257390" },
        .{ "M_SQRT2", "1.41421356237309504880" },
        .{ "M_SQRT1_2", "0.707106781186547524401" },
        .{ "BLAKE3_NO_AVX512", null },
        .{ "BLAKE3_NO_AVX2", null },
        .{ "BLAKE3_NO_SSE41", null },
        .{ "BLAKE3_NO_SSE2", null },
        .{ "BLAKE3_USE_NEON", "0" },
    };
    for (defines) |d| {
        lib_mod.addCMacro(d[0], d[1] orelse "");
    }

    const os_tag = target.result.os.tag;
    if (os_tag == .windows) {
        lib_mod.addCMacro("WINDOWS_NO_FUTEX", "");
    } else {
        lib_mod.addCMacro("HAVE_PTHREAD", "");
        lib_mod.addCMacro("HAVE_SYSCONF", "1");
        lib_mod.addCMacro("_GNU_SOURCE", "");
        if (os_tag == .linux) lib_mod.addCMacro("HAVE_THRD_CREATE", "");
    }

    if (target.result.cpu.arch.endian() == .big) {
        lib_mod.addCMacro("UTIL_ARCH_BIG_ENDIAN", "1");
        lib_mod.addCMacro("UTIL_ARCH_LITTLE_ENDIAN", "0");
    } else {
        lib_mod.addCMacro("UTIL_ARCH_BIG_ENDIAN", "0");
        lib_mod.addCMacro("UTIL_ARCH_LITTLE_ENDIAN", "1");
    }

    // include paths
    const include_dirs = [_][]const u8{
        "mesa/include",
        "mesa_generated",
        "mesa_stubs",
        "mesa_generated/spirv",
        "mesa/src/util",
        "mesa/src/util/format",
        "mesa/src",
        "mesa/src/compiler",
        "mesa/src/compiler/glsl",
        "mesa/src/compiler/nir",
        "mesa/src/compiler/spirv",
        "mesa/src/microsoft/compiler",
    };
    for (include_dirs) |dir| {
        lib_mod.addIncludePath(b.path(dir));
    }

    lib_mod.linkLibrary(qsort);

    // all C source files
    const c_sources = c_util ++ c_compiler ++ c_spirv ++ c_dxil ++ c_spirv_to_dxil ++ c_nir ++ c_format ++ c_generated;
    for (c_sources) |file| {
        lib_mod.addCSourceFile(.{ 
            .file = b.path(file), 
            .flags = &c_flags 
        });
    }

    // platform threading
    if (os_tag == .windows) {
        lib_mod.addCSourceFile(.{ .file = b.path("mesa/src/c11/impl/threads_win32.c"), .flags = &c_flags });
    } else if (os_tag != .linux) {
        // linux: system libc provides C11 threads via HAVE_THRD_CREATE
        lib_mod.addCSourceFile(.{ .file = b.path("mesa/src/c11/impl/threads_posix.c"), .flags = &c_flags });
    }

    // output library and header files
    const lib = b.addLibrary(.{
        .name = "spirv_to_dxil",
        .root_module = lib_mod,
    });
    lib.installHeader(b.path("mesa/src/microsoft/spirv_to_dxil/spirv_to_dxil.h"), "spirv_to_dxil.h");
    lib.installHeader(b.path("mesa/src/microsoft/compiler/dxil_versions.h"), "dxil_versions.h");
    b.installArtifact(lib);

    // same module doubles as public api (dep.module) and as test root
    const bindings = b.addModule("spirv_to_dxil", .{
        .root_source_file = b.path("src/spirv_to_dxil.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });

    // linking it catches undefined symbols per matrix target, running it tests the api
    const bindings_test = b.addTest(.{ .root_module = bindings });
    bindings_test.root_module.linkLibrary(lib);
    b.getInstallStep().dependOn(&bindings_test.step);
    const run_bindings_test = b.addRunArtifact(bindings_test);
    run_bindings_test.setCwd(b.path("."));
    const test_step = b.step("test", "run bindings tests (version + spv to dxil)");
    test_step.dependOn(&run_bindings_test.step);
}

fn mesaVersion(b: *std.Build) []const u8 {
    const file = b.root.openFile(b.graph.io, "mesa/VERSION", .{}) catch return "0.0.0";
    defer file.close(b.graph.io);
    var read_buf: [128]u8 = undefined;
    var reader = file.reader(b.graph.io, &read_buf);
    const size = reader.getSize() catch return "0.0.0";
    const content = reader.interface.readAlloc(b.allocator, size) catch return "0.0.0";
    return std.mem.trim(u8, content, " \t\r\n");
}

const c_util = [_][]const u8{
    "mesa/src/c11/impl/time.c",
    "mesa/src/util/ralloc.c",
    "mesa/src/util/blob.c",
    "mesa/src/util/set.c",
    "mesa/src/util/hash_table.c",
    "mesa/src/util/u_worklist.c",
    "mesa/src/util/u_vector.c",
    "mesa/src/util/u_debug.c",
    "mesa/src/util/u_cpu_detect.c",
    "mesa/src/util/u_thread.c",
    "mesa/src/util/u_dynarray.c",
    "mesa/src/util/u_printf.c",
    "mesa/src/util/u_call_once.c",
    "mesa/src/util/memstream.c",
    "mesa/src/util/futex.c",
    "mesa/src/util/simple_mtx.c",
    "mesa/src/util/log.c",
    "mesa/src/util/rgtc.c",
    "mesa/src/util/dag.c",
    "mesa/src/util/bitscan.c",
    "mesa/src/util/rb_tree.c",
    "mesa/src/util/string_buffer.c",
    "mesa/src/util/half_float.c",
    "mesa/src/util/float8.c",
    "mesa/src/util/softfloat.c",
    "mesa/src/util/double.c",
    "mesa/src/util/fast_idiv_by_const.c",
    "mesa/src/util/range_minimum_query.c",
    "mesa/src/util/u_process.c",
    "mesa/src/util/os_misc.c",
    "mesa/src/util/os_file.c",
    "mesa/src/util/mesa-blake3.c",
    "mesa/src/util/blake3/blake3.c",
    "mesa/src/util/blake3/blake3_dispatch.c",
    "mesa/src/util/blake3/blake3_portable.c",
};

const c_compiler = [_][]const u8{
    "mesa/src/compiler/glsl_types.c",
    "mesa/src/compiler/shader_enums.c",
};

const c_spirv = [_][]const u8{
    "mesa/src/compiler/spirv/spirv_to_nir.c",
    "mesa/src/compiler/spirv/vtn_alu.c",
    "mesa/src/compiler/spirv/vtn_amd.c",
    "mesa/src/compiler/spirv/vtn_cfg.c",
    "mesa/src/compiler/spirv/vtn_cmat.c",
    "mesa/src/compiler/spirv/vtn_debug.c",
    "mesa/src/compiler/spirv/vtn_glsl450.c",
    "mesa/src/compiler/spirv/vtn_opencl.c",
    "mesa/src/compiler/spirv/vtn_structured_cfg.c",
    "mesa/src/compiler/spirv/vtn_subgroup.c",
    "mesa/src/compiler/spirv/vtn_variables.c",
};

const c_dxil = [_][]const u8{
    "mesa/src/microsoft/compiler/dxil_buffer.c",
    "mesa/src/microsoft/compiler/dxil_container.c",
    "mesa/src/microsoft/compiler/dxil_dump.c",
    "mesa/src/microsoft/compiler/dxil_enums.c",
    "mesa/src/microsoft/compiler/dxil_function.c",
    "mesa/src/microsoft/compiler/dxil_module.c",
    "mesa/src/microsoft/compiler/dxil_nir_lower_int_cubemaps.c",
    "mesa/src/microsoft/compiler/dxil_nir_lower_int_samplers.c",
    "mesa/src/microsoft/compiler/dxil_nir_lower_vs_vertex_conversion.c",
    "mesa/src/microsoft/compiler/dxil_nir_tess.c",
    "mesa/src/microsoft/compiler/dxil_nir.c",
    "mesa/src/microsoft/compiler/dxil_signature.c",
    "mesa/src/microsoft/compiler/nir_to_dxil.c",
};

const c_spirv_to_dxil = [_][]const u8{
    "mesa/src/microsoft/spirv_to_dxil/dxil_spirv_nir_lower_bindless.c",
    "mesa/src/microsoft/spirv_to_dxil/dxil_spirv_nir.c",
    "mesa/src/microsoft/spirv_to_dxil/spirv_to_dxil.c",
};

const c_nir = [_][]const u8{
    "mesa/src/compiler/nir/nir.c",
    "mesa/src/compiler/nir/nir_builder.c",
    "mesa/src/compiler/nir/nir_builtin_builder.c",
    "mesa/src/compiler/nir/nir_clip_cull_distance_io_utils.c",
    "mesa/src/compiler/nir/nir_clone.c",
    "mesa/src/compiler/nir/nir_control_flow.c",
    "mesa/src/compiler/nir/nir_convert_address_format.c",
    "mesa/src/compiler/nir/nir_deref.c",
    "mesa/src/compiler/nir/nir_divergence_analysis.c",
    "mesa/src/compiler/nir/nir_dominance.c",
    "mesa/src/compiler/nir/nir_dominance_lca.c",
    "mesa/src/compiler/nir/nir_downgrade_pls_vars.c",
    "mesa/src/compiler/nir/nir_fixup_is_exported.c",
    "mesa/src/compiler/nir/nir_format_convert.c",
    "mesa/src/compiler/nir/nir_from_ssa.c",
    "mesa/src/compiler/nir/nir_functions.c",
    "mesa/src/compiler/nir/nir_gather_info.c",
    "mesa/src/compiler/nir/nir_gather_output_deps.c",
    "mesa/src/compiler/nir/nir_gather_tcs_info.c",
    "mesa/src/compiler/nir/nir_gather_types.c",
    "mesa/src/compiler/nir/nir_gather_xfb_info.c",
    "mesa/src/compiler/nir/nir_gs_count_vertices.c",
    "mesa/src/compiler/nir/nir_inline_sysval.c",
    "mesa/src/compiler/nir/nir_inline_uniforms.c",
    "mesa/src/compiler/nir/nir_instr_set.c",
    "mesa/src/compiler/nir/nir_io_add_xfb_info.c",
    "mesa/src/compiler/nir/nir_legacy.c",
    "mesa/src/compiler/nir/nir_linking_helpers.c",
    "mesa/src/compiler/nir/nir_liveness.c",
    "mesa/src/compiler/nir/nir_loop_analyze.c",
    "mesa/src/compiler/nir/nir_lower_abort.c",
    "mesa/src/compiler/nir/nir_lower_alpha.c",
    "mesa/src/compiler/nir/nir_lower_alu.c",
    "mesa/src/compiler/nir/nir_lower_alu_width.c",
    "mesa/src/compiler/nir/nir_lower_amul.c",
    "mesa/src/compiler/nir/nir_lower_array_deref_of_vec.c",
    "mesa/src/compiler/nir/nir_lower_atomics.c",
    "mesa/src/compiler/nir/nir_lower_atomics_to_ssbo.c",
    "mesa/src/compiler/nir/nir_lower_bit_size.c",
    "mesa/src/compiler/nir/nir_lower_bitmap.c",
    "mesa/src/compiler/nir/nir_lower_blend.c",
    "mesa/src/compiler/nir/nir_lower_bool_to_float.c",
    "mesa/src/compiler/nir/nir_lower_bool_to_int32.c",
    "mesa/src/compiler/nir/nir_lower_calls_to_builtins.c",
    "mesa/src/compiler/nir/nir_lower_cl_images.c",
    "mesa/src/compiler/nir/nir_lower_clamp_color_outputs.c",
    "mesa/src/compiler/nir/nir_lower_clip.c",
    "mesa/src/compiler/nir/nir_lower_clip_disable.c",
    "mesa/src/compiler/nir/nir_lower_clip_halfz.c",
    "mesa/src/compiler/nir/nir_lower_const_arrays_to_uniforms.c",
    "mesa/src/compiler/nir/nir_lower_continue_constructs.c",
    "mesa/src/compiler/nir/nir_lower_convert_alu_types.c",
    "mesa/src/compiler/nir/nir_lower_cooperative_matrix.c",
    "mesa/src/compiler/nir/nir_lower_discard_if.c",
    "mesa/src/compiler/nir/nir_lower_double_ops.c",
    "mesa/src/compiler/nir/nir_lower_explicit_io.c",
    "mesa/src/compiler/nir/nir_lower_fb_read.c",
    "mesa/src/compiler/nir/nir_lower_flatshade.c",
    "mesa/src/compiler/nir/nir_lower_floats.c",
    "mesa/src/compiler/nir/nir_lower_flrp.c",
    "mesa/src/compiler/nir/nir_lower_fp16_conv.c",
    "mesa/src/compiler/nir/nir_lower_frag_coord_to_pixel_coord.c",
    "mesa/src/compiler/nir/nir_lower_fragcolor.c",
    "mesa/src/compiler/nir/nir_lower_fragcoord_wtrans.c",
    "mesa/src/compiler/nir/nir_lower_frexp.c",
    "mesa/src/compiler/nir/nir_lower_global_vars_to_local.c",
    "mesa/src/compiler/nir/nir_lower_goto_ifs.c",
    "mesa/src/compiler/nir/nir_lower_gs_intrinsics.c",
    "mesa/src/compiler/nir/nir_lower_halt_to_return.c",
    "mesa/src/compiler/nir/nir_lower_helper_writes.c",
    "mesa/src/compiler/nir/nir_lower_idiv.c",
    "mesa/src/compiler/nir/nir_lower_image.c",
    "mesa/src/compiler/nir/nir_lower_image_atomics_to_global.c",
    "mesa/src/compiler/nir/nir_lower_indirect_derefs_to_if_else_trees.c",
    "mesa/src/compiler/nir/nir_lower_input_attachments.c",
    "mesa/src/compiler/nir/nir_lower_int_to_float.c",
    "mesa/src/compiler/nir/nir_lower_int64.c",
    "mesa/src/compiler/nir/nir_lower_interpolation.c",
    "mesa/src/compiler/nir/nir_lower_io.c",
    "mesa/src/compiler/nir/nir_lower_io_array_vars_to_elements.c",
    "mesa/src/compiler/nir/nir_lower_io_indirect_loads.c",
    "mesa/src/compiler/nir/nir_lower_io_to_scalar.c",
    "mesa/src/compiler/nir/nir_lower_io_vars_to_scalar.c",
    "mesa/src/compiler/nir/nir_lower_io_vars_to_temporaries.c",
    "mesa/src/compiler/nir/nir_lower_is_helper_invocation.c",
    "mesa/src/compiler/nir/nir_lower_load_const_to_scalar.c",
    "mesa/src/compiler/nir/nir_lower_locals_to_regs.c",
    "mesa/src/compiler/nir/nir_lower_mediump.c",
    "mesa/src/compiler/nir/nir_lower_mem_access_bit_sizes.c",
    "mesa/src/compiler/nir/nir_lower_memcpy.c",
    "mesa/src/compiler/nir/nir_lower_memory_model.c",
    "mesa/src/compiler/nir/nir_lower_multiview.c",
    "mesa/src/compiler/nir/nir_lower_non_uniform_access.c",
    "mesa/src/compiler/nir/nir_lower_packing.c",
    "mesa/src/compiler/nir/nir_lower_passthrough_edgeflags.c",
    "mesa/src/compiler/nir/nir_lower_patch_vertices.c",
    "mesa/src/compiler/nir/nir_lower_phis_to_scalar.c",
    "mesa/src/compiler/nir/nir_lower_pntc_ytransform.c",
    "mesa/src/compiler/nir/nir_lower_point_size.c",
    "mesa/src/compiler/nir/nir_lower_point_smooth.c",
    "mesa/src/compiler/nir/nir_lower_poly_line_smooth.c",
    "mesa/src/compiler/nir/nir_lower_printf.c",
    "mesa/src/compiler/nir/nir_lower_readonly_images_to_tex.c",
    "mesa/src/compiler/nir/nir_lower_reg_intrinsics_to_ssa.c",
    "mesa/src/compiler/nir/nir_lower_returns.c",
    "mesa/src/compiler/nir/nir_lower_robust_access.c",
    "mesa/src/compiler/nir/nir_lower_sample_shading.c",
    "mesa/src/compiler/nir/nir_lower_samplers.c",
    "mesa/src/compiler/nir/nir_lower_scratch.c",
    "mesa/src/compiler/nir/nir_lower_scratch_to_var.c",
    "mesa/src/compiler/nir/nir_lower_shader_calls.c",
    "mesa/src/compiler/nir/nir_lower_single_sampled.c",
    "mesa/src/compiler/nir/nir_lower_ssbo.c",
    "mesa/src/compiler/nir/nir_lower_subgroups.c",
    "mesa/src/compiler/nir/nir_lower_system_values.c",
    "mesa/src/compiler/nir/nir_lower_sysvals_to_varyings.c",
    "mesa/src/compiler/nir/nir_lower_task_shader.c",
    "mesa/src/compiler/nir/nir_lower_tess_coord_z.c",
    "mesa/src/compiler/nir/nir_lower_tex.c",
    "mesa/src/compiler/nir/nir_lower_tex_shadow.c",
    "mesa/src/compiler/nir/nir_lower_texcoord_replace.c",
    "mesa/src/compiler/nir/nir_lower_texcoord_replace_late.c",
    "mesa/src/compiler/nir/nir_lower_terminate_to_demote.c",
    "mesa/src/compiler/nir/nir_lower_two_sided_color.c",
    "mesa/src/compiler/nir/nir_lower_ubo_vec4.c",
    "mesa/src/compiler/nir/nir_lower_undef_to_zero.c",
    "mesa/src/compiler/nir/nir_lower_uniforms_to_ubo.c",
    "mesa/src/compiler/nir/nir_lower_var_copies.c",
    "mesa/src/compiler/nir/nir_lower_variable_initializers.c",
    "mesa/src/compiler/nir/nir_lower_vars_to_ssa.c",
    "mesa/src/compiler/nir/nir_lower_vec_to_regs.c",
    "mesa/src/compiler/nir/nir_lower_vec3_to_vec4.c",
    "mesa/src/compiler/nir/nir_lower_view_index_to_device_index.c",
    "mesa/src/compiler/nir/nir_lower_viewport_transform.c",
    "mesa/src/compiler/nir/nir_lower_workgroup_size.c",
    "mesa/src/compiler/nir/nir_lower_wpos_center.c",
    "mesa/src/compiler/nir/nir_lower_wpos_ytransform.c",
    "mesa/src/compiler/nir/nir_lower_wrmasks.c",
    "mesa/src/compiler/nir/nir_metadata.c",
    "mesa/src/compiler/nir/nir_mod_analysis.c",
    "mesa/src/compiler/nir/nir_move_output_stores_to_end.c",
    "mesa/src/compiler/nir/nir_move_vec_src_uses_to_dest.c",
    "mesa/src/compiler/nir/nir_normalize_cubemap_coords.c",
    "mesa/src/compiler/nir/nir_normalize_sin_cos.c",
    "mesa/src/compiler/nir/nir_opt_access.c",
    "mesa/src/compiler/nir/nir_opt_barriers.c",
    "mesa/src/compiler/nir/nir_opt_barycentric.c",
    "mesa/src/compiler/nir/nir_opt_call.c",
    "mesa/src/compiler/nir/nir_opt_clip_cull_const.c",
    "mesa/src/compiler/nir/nir_opt_combine_stores.c",
    "mesa/src/compiler/nir/nir_opt_comparison_pre.c",
    "mesa/src/compiler/nir/nir_opt_constant_folding.c",
    "mesa/src/compiler/nir/nir_opt_copy_prop_vars.c",
    "mesa/src/compiler/nir/nir_opt_copy_propagate.c",
    "mesa/src/compiler/nir/nir_opt_cse.c",
    "mesa/src/compiler/nir/nir_opt_dce.c",
    "mesa/src/compiler/nir/nir_opt_dead_cf.c",
    "mesa/src/compiler/nir/nir_opt_dead_write_vars.c",
    "mesa/src/compiler/nir/nir_opt_find_array_copies.c",
    "mesa/src/compiler/nir/nir_opt_fp_math_ctrl.c",
    "mesa/src/compiler/nir/nir_opt_frag_coord_to_pixel_coord.c",
    "mesa/src/compiler/nir/nir_opt_fragdepth.c",
    "mesa/src/compiler/nir/nir_opt_gcm.c",
    "mesa/src/compiler/nir/nir_opt_generate_bfi.c",
    "mesa/src/compiler/nir/nir_opt_group_loads.c",
    "mesa/src/compiler/nir/nir_opt_idiv_const.c",
    "mesa/src/compiler/nir/nir_opt_if.c",
    "mesa/src/compiler/nir/nir_opt_intrinsics.c",
    "mesa/src/compiler/nir/nir_opt_large_constants.c",
    "mesa/src/compiler/nir/nir_opt_licm.c",
    "mesa/src/compiler/nir/nir_opt_load_skip_helpers.c",
    "mesa/src/compiler/nir/nir_opt_load_store_vectorize.c",
    "mesa/src/compiler/nir/nir_opt_loop.c",
    "mesa/src/compiler/nir/nir_opt_loop_unroll.c",
    "mesa/src/compiler/nir/nir_opt_memcpy.c",
    "mesa/src/compiler/nir/nir_opt_move.c",
    "mesa/src/compiler/nir/nir_opt_move_discards_to_top.c",
    "mesa/src/compiler/nir/nir_opt_move_to_top.c",
    "mesa/src/compiler/nir/nir_opt_mqsad.c",
    "mesa/src/compiler/nir/nir_opt_non_uniform_access.c",
    "mesa/src/compiler/nir/nir_opt_offsets.c",
    "mesa/src/compiler/nir/nir_opt_peephole_select.c",
    "mesa/src/compiler/nir/nir_opt_phi_precision.c",
    "mesa/src/compiler/nir/nir_opt_phi_to_bool.c",
    "mesa/src/compiler/nir/nir_opt_preamble.c",
    "mesa/src/compiler/nir/nir_opt_ray_queries.c",
    "mesa/src/compiler/nir/nir_opt_reassociate.c",
    "mesa/src/compiler/nir/nir_opt_reassociate_bfi.c",
    "mesa/src/compiler/nir/nir_opt_rematerialize_compares.c",
    "mesa/src/compiler/nir/nir_opt_remove_phis.c",
    "mesa/src/compiler/nir/nir_opt_shared_vars_to_subgroup.c",
    "mesa/src/compiler/nir/nir_opt_shrink_stores.c",
    "mesa/src/compiler/nir/nir_opt_shrink_vectors.c",
    "mesa/src/compiler/nir/nir_opt_sink.c",
    "mesa/src/compiler/nir/nir_opt_undef.c",
    "mesa/src/compiler/nir/nir_opt_uniform_atomics.c",
    "mesa/src/compiler/nir/nir_opt_uniform_subgroup.c",
    "mesa/src/compiler/nir/nir_opt_uub.c",
    "mesa/src/compiler/nir/nir_opt_varyings.c",
    "mesa/src/compiler/nir/nir_opt_vectorize.c",
    "mesa/src/compiler/nir/nir_opt_vectorize_io.c",
    "mesa/src/compiler/nir/nir_opt_vectorize_io_vars.c",
    "mesa/src/compiler/nir/nir_passthrough_gs.c",
    "mesa/src/compiler/nir/nir_passthrough_tcs.c",
    "mesa/src/compiler/nir/nir_phi_builder.c",
    "mesa/src/compiler/nir/nir_print.c",
    "mesa/src/compiler/nir/nir_propagate_invariant.c",
    "mesa/src/compiler/nir/nir_range_analysis.c",
    "mesa/src/compiler/nir/nir_recompute_io_bases.c",
    "mesa/src/compiler/nir/nir_remove_outputs.c",
    "mesa/src/compiler/nir/nir_repair_ssa.c",
    "mesa/src/compiler/nir/nir_remove_dead_variables.c",
    "mesa/src/compiler/nir/nir_remove_tex_shadow.c",
    "mesa/src/compiler/nir/nir_scale_fdiv.c",
    "mesa/src/compiler/nir/nir_schedule.c",
    "mesa/src/compiler/nir/nir_search.c",
    "mesa/src/compiler/nir/nir_separate_merged_clip_cull_io.c",
    "mesa/src/compiler/nir/nir_serialize.c",
    "mesa/src/compiler/nir/nir_shader_bisect.c",
    "mesa/src/compiler/nir/nir_split_64bit_vec3_and_vec4.c",
    "mesa/src/compiler/nir/nir_split_conversions.c",
    "mesa/src/compiler/nir/nir_split_per_member_structs.c",
    "mesa/src/compiler/nir/nir_split_var_copies.c",
    "mesa/src/compiler/nir/nir_split_vars.c",
    "mesa/src/compiler/nir/nir_stub.c",
    "mesa/src/compiler/nir/nir_sweep.c",
    "mesa/src/compiler/nir/nir_to_lcssa.c",
    "mesa/src/compiler/nir/nir_trivialize_registers.c",
    "mesa/src/compiler/nir/nir_unlower_io_to_vars.c",
    "mesa/src/compiler/nir/nir_use_dominance.c",
    "mesa/src/compiler/nir/nir_validate.c",
    "mesa/src/compiler/nir/nir_worklist.c",
};

const c_format = [_][]const u8{
    "mesa/src/util/format/u_format.c",
    "mesa/src/util/format/u_format_bptc.c",
    "mesa/src/util/format/u_format_etc.c",
    "mesa/src/util/format/u_format_fxt1.c",
    "mesa/src/util/format/u_format_latc.c",
    "mesa/src/util/format/u_format_other.c",
    "mesa/src/util/format/u_format_rgtc.c",
    "mesa/src/util/format/u_format_s3tc.c",
    "mesa/src/util/format/u_format_tests.c",
    "mesa/src/util/format/u_format_unpack_neon.c",
    "mesa/src/util/format/u_format_yuv.c",
    "mesa/src/util/format/u_format_zs.c",
};

const c_generated = [_][]const u8{
    "mesa_generated/builtin_types.c",
    "mesa_generated/dxil_nir_algebraic.c",
    "mesa_generated/format_srgb.c",
    "mesa_generated/nir_constant_expressions.c",
    "mesa_generated/nir_intrinsics.c",
    "mesa_generated/nir_opcodes.c",
    "mesa_generated/nir_opt_algebraic.c",
    "mesa_generated/spirv/spirv_info.c",
    "mesa_generated/u_format_table.c",
    "mesa_generated/vtn_gather_types.c",
};
