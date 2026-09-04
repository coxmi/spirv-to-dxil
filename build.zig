const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // u_qsort (C++17) - compiled separately
    const qsort_mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libcpp = true,
    });
    qsort_mod.addCSourceFile(.{
        .file = b.path(m ++ "/src/util/u_qsort.cpp"),
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
        .{ "PACKAGE_VERSION", "\"24.3.4\"" },
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
    };
    for (defines) |d| {
        lib_mod.addCMacro(d[0], d[1] orelse "");
    }

    const os_tag = target.result.os.tag;
    if (os_tag == .windows) {
        lib_mod.addCMacro("WINDOWS_NO_FUTEX", "");
    } else if (os_tag == .linux) {
        lib_mod.addCMacro("HAVE_PTHREAD", "");
        lib_mod.addCMacro("_GNU_SOURCE", "");
        lib_mod.addCMacro("HAVE_THRD_CREATE", "");
    } else {
        lib_mod.addCMacro("HAVE_PTHREAD", "");
        lib_mod.addCMacro("_GNU_SOURCE", "");
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
        m ++ "/include",
        g,
        g ++ "/stubs",
        m ++ "/src/util",
        m ++ "/src/util/format",
        m ++ "/src/util/sha1",
        m ++ "/src",
        m ++ "/src/compiler",
        m ++ "/src/compiler/glsl",
        m ++ "/src/compiler/nir",
        m ++ "/src/compiler/spirv",
        m ++ "/src/microsoft/compiler",
    };
    for (include_dirs) |dir| {
        lib_mod.addIncludePath(b.path(dir));
    }

    lib_mod.linkLibrary(qsort);

    // all C source files
    const c_sources = c_util ++ c_compiler ++ c_spirv ++ c_dxil ++ c_spirv_to_dxil ++ c_nir ++ c_format ++ c_generated;

    for (c_sources) |file| {
        lib_mod.addCSourceFile(.{ .file = b.path(file), .flags = &c_flags });
    }

    // platform threading
    if (os_tag == .windows) {
        lib_mod.addCSourceFile(.{ .file = b.path(m ++ "/src/c11/impl/threads_win32.c"), .flags = &c_flags });
    } else if (os_tag != .linux) {
        // linux: system libc provides C11 threads via HAVE_THRD_CREATE
        lib_mod.addCSourceFile(.{ .file = b.path(m ++ "/src/c11/impl/threads_posix.c"), .flags = &c_flags });
    }

    const lib = b.addLibrary(.{
        .name = "spirv_to_dxil",
        .root_module = lib_mod,
    });

    lib.installHeader(b.path(m ++ "/src/microsoft/spirv_to_dxil/spirv_to_dxil.h"), "spirv_to_dxil.h");
    lib.installHeader(b.path(m ++ "/src/microsoft/compiler/dxil_versions.h"), "dxil_versions.h");

    b.installArtifact(lib);

    // update-mesa step
    const gen_step = b.addSystemCommand(&.{ "bash", "scripts/generate_mesa.sh" });
    gen_step.setCwd(b.path("."));
    const update_mesa = b.step("update-mesa", "regenerate Mesa Mako output after version bump");
    update_mesa.dependOn(&gen_step.step);
}

const m = "mesa";
const g = "mesa_generated";

const c_util = [_][]const u8{
    m ++ "/src/c11/impl/time.c",
    m ++ "/src/util/ralloc.c",
    m ++ "/src/util/blob.c",
    m ++ "/src/util/set.c",
    m ++ "/src/util/hash_table.c",
    m ++ "/src/util/u_worklist.c",
    m ++ "/src/util/u_vector.c",
    m ++ "/src/util/u_debug.c",
    m ++ "/src/util/u_dynarray.c",
    m ++ "/src/util/u_printf.c",
    m ++ "/src/util/u_call_once.c",
    m ++ "/src/util/sha1/sha1.c",
    m ++ "/src/util/mesa-sha1.c",
    m ++ "/src/util/memstream.c",
    m ++ "/src/util/futex.c",
    m ++ "/src/util/simple_mtx.c",
    m ++ "/src/util/log.c",
    m ++ "/src/util/rgtc.c",
    m ++ "/src/util/dag.c",
    m ++ "/src/util/bitscan.c",
    m ++ "/src/util/rb_tree.c",
    m ++ "/src/util/string_buffer.c",
    m ++ "/src/util/half_float.c",
    m ++ "/src/util/softfloat.c",
    m ++ "/src/util/double.c",
    m ++ "/src/util/fast_idiv_by_const.c",
};

const c_compiler = [_][]const u8{
    m ++ "/src/compiler/glsl_types.c",
    m ++ "/src/compiler/shader_enums.c",
};

const c_spirv = [_][]const u8{
    m ++ "/src/compiler/spirv/spirv_to_nir.c",
    m ++ "/src/compiler/spirv/vtn_alu.c",
    m ++ "/src/compiler/spirv/vtn_amd.c",
    m ++ "/src/compiler/spirv/vtn_cfg.c",
    m ++ "/src/compiler/spirv/vtn_cmat.c",
    m ++ "/src/compiler/spirv/vtn_glsl450.c",
    m ++ "/src/compiler/spirv/vtn_opencl.c",
    m ++ "/src/compiler/spirv/vtn_structured_cfg.c",
    m ++ "/src/compiler/spirv/vtn_subgroup.c",
    m ++ "/src/compiler/spirv/vtn_variables.c",
};

const c_dxil = [_][]const u8{
    m ++ "/src/microsoft/compiler/dxil_buffer.c",
    m ++ "/src/microsoft/compiler/dxil_container.c",
    m ++ "/src/microsoft/compiler/dxil_dump.c",
    m ++ "/src/microsoft/compiler/dxil_enums.c",
    m ++ "/src/microsoft/compiler/dxil_function.c",
    m ++ "/src/microsoft/compiler/dxil_module.c",
    m ++ "/src/microsoft/compiler/dxil_nir_lower_int_cubemaps.c",
    m ++ "/src/microsoft/compiler/dxil_nir_lower_int_samplers.c",
    m ++ "/src/microsoft/compiler/dxil_nir_lower_vs_vertex_conversion.c",
    m ++ "/src/microsoft/compiler/dxil_nir_tess.c",
    m ++ "/src/microsoft/compiler/dxil_nir.c",
    m ++ "/src/microsoft/compiler/dxil_signature.c",
    m ++ "/src/microsoft/compiler/nir_to_dxil.c",
};

const c_spirv_to_dxil = [_][]const u8{
    m ++ "/src/microsoft/spirv_to_dxil/dxil_spirv_nir_lower_bindless.c",
    m ++ "/src/microsoft/spirv_to_dxil/dxil_spirv_nir.c",
    m ++ "/src/microsoft/spirv_to_dxil/spirv_to_dxil.c",
};

const c_nir = [_][]const u8{
    m ++ "/src/compiler/nir/nir.c",
    m ++ "/src/compiler/nir/nir_builder.c",
    m ++ "/src/compiler/nir/nir_builtin_builder.c",
    m ++ "/src/compiler/nir/nir_clone.c",
    m ++ "/src/compiler/nir/nir_control_flow.c",
    m ++ "/src/compiler/nir/nir_deref.c",
    m ++ "/src/compiler/nir/nir_divergence_analysis.c",
    m ++ "/src/compiler/nir/nir_dominance.c",
    m ++ "/src/compiler/nir/nir_format_convert.c",
    m ++ "/src/compiler/nir/nir_from_ssa.c",
    m ++ "/src/compiler/nir/nir_functions.c",
    m ++ "/src/compiler/nir/nir_gather_info.c",
    m ++ "/src/compiler/nir/nir_gather_tcs_info.c",
    m ++ "/src/compiler/nir/nir_gather_types.c",
    m ++ "/src/compiler/nir/nir_gather_xfb_info.c",
    m ++ "/src/compiler/nir/nir_group_loads.c",
    m ++ "/src/compiler/nir/nir_gs_count_vertices.c",
    m ++ "/src/compiler/nir/nir_inline_uniforms.c",
    m ++ "/src/compiler/nir/nir_instr_set.c",
    m ++ "/src/compiler/nir/nir_legacy.c",
    m ++ "/src/compiler/nir/nir_linking_helpers.c",
    m ++ "/src/compiler/nir/nir_liveness.c",
    m ++ "/src/compiler/nir/nir_loop_analyze.c",
    m ++ "/src/compiler/nir/nir_lower_alpha_test.c",
    m ++ "/src/compiler/nir/nir_lower_alu.c",
    m ++ "/src/compiler/nir/nir_lower_alu_width.c",
    m ++ "/src/compiler/nir/nir_lower_amul.c",
    m ++ "/src/compiler/nir/nir_lower_array_deref_of_vec.c",
    m ++ "/src/compiler/nir/nir_lower_atomics.c",
    m ++ "/src/compiler/nir/nir_lower_atomics_to_ssbo.c",
    m ++ "/src/compiler/nir/nir_lower_bit_size.c",
    m ++ "/src/compiler/nir/nir_lower_bitmap.c",
    m ++ "/src/compiler/nir/nir_lower_blend.c",
    m ++ "/src/compiler/nir/nir_lower_bool_to_bitsize.c",
    m ++ "/src/compiler/nir/nir_lower_bool_to_float.c",
    m ++ "/src/compiler/nir/nir_lower_bool_to_int32.c",
    m ++ "/src/compiler/nir/nir_lower_cl_images.c",
    m ++ "/src/compiler/nir/nir_lower_clamp_color_outputs.c",
    m ++ "/src/compiler/nir/nir_lower_clip.c",
    m ++ "/src/compiler/nir/nir_lower_clip_cull_distance_arrays.c",
    m ++ "/src/compiler/nir/nir_lower_clip_disable.c",
    m ++ "/src/compiler/nir/nir_lower_clip_halfz.c",
    m ++ "/src/compiler/nir/nir_lower_const_arrays_to_uniforms.c",
    m ++ "/src/compiler/nir/nir_lower_continue_constructs.c",
    m ++ "/src/compiler/nir/nir_lower_convert_alu_types.c",
    m ++ "/src/compiler/nir/nir_lower_discard_if.c",
    m ++ "/src/compiler/nir/nir_lower_double_ops.c",
    m ++ "/src/compiler/nir/nir_lower_drawpixels.c",
    m ++ "/src/compiler/nir/nir_lower_fb_read.c",
    m ++ "/src/compiler/nir/nir_lower_flatshade.c",
    m ++ "/src/compiler/nir/nir_lower_flrp.c",
    m ++ "/src/compiler/nir/nir_lower_fp16_conv.c",
    m ++ "/src/compiler/nir/nir_lower_frag_coord_to_pixel_coord.c",
    m ++ "/src/compiler/nir/nir_lower_fragcolor.c",
    m ++ "/src/compiler/nir/nir_lower_fragcoord_wtrans.c",
    m ++ "/src/compiler/nir/nir_lower_frexp.c",
    m ++ "/src/compiler/nir/nir_lower_global_vars_to_local.c",
    m ++ "/src/compiler/nir/nir_lower_goto_ifs.c",
    m ++ "/src/compiler/nir/nir_lower_gs_intrinsics.c",
    m ++ "/src/compiler/nir/nir_lower_helper_writes.c",
    m ++ "/src/compiler/nir/nir_lower_idiv.c",
    m ++ "/src/compiler/nir/nir_lower_image.c",
    m ++ "/src/compiler/nir/nir_lower_image_atomics_to_global.c",
    m ++ "/src/compiler/nir/nir_lower_indirect_derefs.c",
    m ++ "/src/compiler/nir/nir_lower_input_attachments.c",
    m ++ "/src/compiler/nir/nir_lower_int_to_float.c",
    m ++ "/src/compiler/nir/nir_lower_int64.c",
    m ++ "/src/compiler/nir/nir_lower_interpolation.c",
    m ++ "/src/compiler/nir/nir_lower_io.c",
    m ++ "/src/compiler/nir/nir_lower_io_arrays_to_elements.c",
    m ++ "/src/compiler/nir/nir_lower_io_to_scalar.c",
    m ++ "/src/compiler/nir/nir_lower_io_to_temporaries.c",
    m ++ "/src/compiler/nir/nir_lower_io_to_vector.c",
    m ++ "/src/compiler/nir/nir_lower_is_helper_invocation.c",
    m ++ "/src/compiler/nir/nir_lower_load_const_to_scalar.c",
    m ++ "/src/compiler/nir/nir_lower_locals_to_regs.c",
    m ++ "/src/compiler/nir/nir_lower_mediump.c",
    m ++ "/src/compiler/nir/nir_lower_mem_access_bit_sizes.c",
    m ++ "/src/compiler/nir/nir_lower_memcpy.c",
    m ++ "/src/compiler/nir/nir_lower_memory_model.c",
    m ++ "/src/compiler/nir/nir_lower_multiview.c",
    m ++ "/src/compiler/nir/nir_lower_non_uniform_access.c",
    m ++ "/src/compiler/nir/nir_lower_packing.c",
    m ++ "/src/compiler/nir/nir_lower_passthrough_edgeflags.c",
    m ++ "/src/compiler/nir/nir_lower_patch_vertices.c",
    m ++ "/src/compiler/nir/nir_lower_phis_to_scalar.c",
    m ++ "/src/compiler/nir/nir_lower_pntc_ytransform.c",
    m ++ "/src/compiler/nir/nir_lower_point_size.c",
    m ++ "/src/compiler/nir/nir_lower_point_size_mov.c",
    m ++ "/src/compiler/nir/nir_lower_point_smooth.c",
    m ++ "/src/compiler/nir/nir_lower_poly_line_smooth.c",
    m ++ "/src/compiler/nir/nir_lower_printf.c",
    m ++ "/src/compiler/nir/nir_lower_readonly_images_to_tex.c",
    m ++ "/src/compiler/nir/nir_lower_reg_intrinsics_to_ssa.c",
    m ++ "/src/compiler/nir/nir_lower_returns.c",
    m ++ "/src/compiler/nir/nir_lower_robust_access.c",
    m ++ "/src/compiler/nir/nir_lower_samplers.c",
    m ++ "/src/compiler/nir/nir_lower_scratch.c",
    m ++ "/src/compiler/nir/nir_lower_shader_calls.c",
    m ++ "/src/compiler/nir/nir_lower_single_sampled.c",
    m ++ "/src/compiler/nir/nir_lower_ssbo.c",
    m ++ "/src/compiler/nir/nir_lower_subgroups.c",
    m ++ "/src/compiler/nir/nir_lower_system_values.c",
    m ++ "/src/compiler/nir/nir_lower_sysvals_to_varyings.c",
    m ++ "/src/compiler/nir/nir_lower_task_shader.c",
    m ++ "/src/compiler/nir/nir_lower_tess_coord_z.c",
    m ++ "/src/compiler/nir/nir_lower_tex.c",
    m ++ "/src/compiler/nir/nir_lower_tex_shadow.c",
    m ++ "/src/compiler/nir/nir_lower_texcoord_replace.c",
    m ++ "/src/compiler/nir/nir_lower_texcoord_replace_late.c",
    m ++ "/src/compiler/nir/nir_lower_terminate_to_demote.c",
    m ++ "/src/compiler/nir/nir_lower_two_sided_color.c",
    m ++ "/src/compiler/nir/nir_lower_ubo_vec4.c",
    m ++ "/src/compiler/nir/nir_lower_undef_to_zero.c",
    m ++ "/src/compiler/nir/nir_lower_uniforms_to_ubo.c",
    m ++ "/src/compiler/nir/nir_lower_var_copies.c",
    m ++ "/src/compiler/nir/nir_lower_variable_initializers.c",
    m ++ "/src/compiler/nir/nir_lower_vars_to_ssa.c",
    m ++ "/src/compiler/nir/nir_lower_vec_to_regs.c",
    m ++ "/src/compiler/nir/nir_lower_vec3_to_vec4.c",
    m ++ "/src/compiler/nir/nir_lower_view_index_to_device_index.c",
    m ++ "/src/compiler/nir/nir_lower_viewport_transform.c",
    m ++ "/src/compiler/nir/nir_lower_wpos_center.c",
    m ++ "/src/compiler/nir/nir_lower_wpos_ytransform.c",
    m ++ "/src/compiler/nir/nir_lower_wrmasks.c",
    m ++ "/src/compiler/nir/nir_metadata.c",
    m ++ "/src/compiler/nir/nir_mod_analysis.c",
    m ++ "/src/compiler/nir/nir_move_vec_src_uses_to_dest.c",
    m ++ "/src/compiler/nir/nir_normalize_cubemap_coords.c",
    m ++ "/src/compiler/nir/nir_opt_access.c",
    m ++ "/src/compiler/nir/nir_opt_barriers.c",
    m ++ "/src/compiler/nir/nir_opt_combine_stores.c",
    m ++ "/src/compiler/nir/nir_opt_comparison_pre.c",
    m ++ "/src/compiler/nir/nir_opt_conditional_discard.c",
    m ++ "/src/compiler/nir/nir_opt_constant_folding.c",
    m ++ "/src/compiler/nir/nir_opt_copy_prop_vars.c",
    m ++ "/src/compiler/nir/nir_opt_copy_propagate.c",
    m ++ "/src/compiler/nir/nir_opt_cse.c",
    m ++ "/src/compiler/nir/nir_opt_dce.c",
    m ++ "/src/compiler/nir/nir_opt_dead_cf.c",
    m ++ "/src/compiler/nir/nir_opt_dead_write_vars.c",
    m ++ "/src/compiler/nir/nir_opt_find_array_copies.c",
    m ++ "/src/compiler/nir/nir_opt_frag_coord_to_pixel_coord.c",
    m ++ "/src/compiler/nir/nir_opt_fragdepth.c",
    m ++ "/src/compiler/nir/nir_opt_gcm.c",
    m ++ "/src/compiler/nir/nir_opt_generate_bfi.c",
    m ++ "/src/compiler/nir/nir_opt_idiv_const.c",
    m ++ "/src/compiler/nir/nir_opt_if.c",
    m ++ "/src/compiler/nir/nir_opt_intrinsics.c",
    m ++ "/src/compiler/nir/nir_opt_large_constants.c",
    m ++ "/src/compiler/nir/nir_opt_licm.c",
    m ++ "/src/compiler/nir/nir_opt_load_store_vectorize.c",
    m ++ "/src/compiler/nir/nir_opt_loop.c",
    m ++ "/src/compiler/nir/nir_opt_loop_unroll.c",
    m ++ "/src/compiler/nir/nir_opt_memcpy.c",
    m ++ "/src/compiler/nir/nir_opt_move.c",
    m ++ "/src/compiler/nir/nir_opt_move_discards_to_top.c",
    m ++ "/src/compiler/nir/nir_opt_mqsad.c",
    m ++ "/src/compiler/nir/nir_opt_non_uniform_access.c",
    m ++ "/src/compiler/nir/nir_opt_offsets.c",
    m ++ "/src/compiler/nir/nir_opt_peephole_select.c",
    m ++ "/src/compiler/nir/nir_opt_phi_precision.c",
    m ++ "/src/compiler/nir/nir_opt_preamble.c",
    m ++ "/src/compiler/nir/nir_opt_ray_queries.c",
    m ++ "/src/compiler/nir/nir_opt_reassociate_bfi.c",
    m ++ "/src/compiler/nir/nir_opt_rematerialize_compares.c",
    m ++ "/src/compiler/nir/nir_opt_remove_phis.c",
    m ++ "/src/compiler/nir/nir_opt_shrink_stores.c",
    m ++ "/src/compiler/nir/nir_opt_shrink_vectors.c",
    m ++ "/src/compiler/nir/nir_opt_sink.c",
    m ++ "/src/compiler/nir/nir_opt_undef.c",
    m ++ "/src/compiler/nir/nir_opt_uniform_atomics.c",
    m ++ "/src/compiler/nir/nir_opt_uniform_subgroup.c",
    m ++ "/src/compiler/nir/nir_opt_varyings.c",
    m ++ "/src/compiler/nir/nir_opt_vectorize.c",
    m ++ "/src/compiler/nir/nir_opt_vectorize_io.c",
    m ++ "/src/compiler/nir/nir_passthrough_gs.c",
    m ++ "/src/compiler/nir/nir_passthrough_tcs.c",
    m ++ "/src/compiler/nir/nir_phi_builder.c",
    m ++ "/src/compiler/nir/nir_print.c",
    m ++ "/src/compiler/nir/nir_propagate_invariant.c",
    m ++ "/src/compiler/nir/nir_range_analysis.c",
    m ++ "/src/compiler/nir/nir_repair_ssa.c",
    m ++ "/src/compiler/nir/nir_remove_dead_variables.c",
    m ++ "/src/compiler/nir/nir_remove_tex_shadow.c",
    m ++ "/src/compiler/nir/nir_scale_fdiv.c",
    m ++ "/src/compiler/nir/nir_schedule.c",
    m ++ "/src/compiler/nir/nir_search.c",
    m ++ "/src/compiler/nir/nir_serialize.c",
    m ++ "/src/compiler/nir/nir_split_64bit_vec3_and_vec4.c",
    m ++ "/src/compiler/nir/nir_split_per_member_structs.c",
    m ++ "/src/compiler/nir/nir_split_var_copies.c",
    m ++ "/src/compiler/nir/nir_split_vars.c",
    m ++ "/src/compiler/nir/nir_sweep.c",
    m ++ "/src/compiler/nir/nir_to_lcssa.c",
    m ++ "/src/compiler/nir/nir_trivialize_registers.c",
    m ++ "/src/compiler/nir/nir_use_dominance.c",
    m ++ "/src/compiler/nir/nir_validate.c",
    m ++ "/src/compiler/nir/nir_worklist.c",
};

const c_format = [_][]const u8{
    m ++ "/src/util/format/u_format.c",
    m ++ "/src/util/format/u_format_bptc.c",
    m ++ "/src/util/format/u_format_etc.c",
    m ++ "/src/util/format/u_format_fxt1.c",
    m ++ "/src/util/format/u_format_latc.c",
    m ++ "/src/util/format/u_format_other.c",
    m ++ "/src/util/format/u_format_rgtc.c",
    m ++ "/src/util/format/u_format_s3tc.c",
    m ++ "/src/util/format/u_format_tests.c",
    m ++ "/src/util/format/u_format_unpack_neon.c",
    m ++ "/src/util/format/u_format_yuv.c",
    m ++ "/src/util/format/u_format_zs.c",
};

const c_generated = [_][]const u8{
    g ++ "/builtin_types.c",
    g ++ "/dxil_nir_algebraic.c",
    g ++ "/format_srgb.c",
    g ++ "/nir_constant_expressions.c",
    g ++ "/nir_intrinsics.c",
    g ++ "/nir_opcodes.c",
    g ++ "/nir_opt_algebraic.c",
    g ++ "/spirv/spirv_info.c",
    g ++ "/u_format_table.c",
    g ++ "/vtn_gather_types.c",
};
