const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const shared = b.option(bool, "shared", "Build as shared library") orelse false;
    const tools = b.option(bool, "tools", "Build tools") orelse false;

    const mod_scudo = b.addModule("scudoAllocator", .{
        .root_source_file = b.path("bindings/scudoAllocator.zig"),
    });
    const lib = if (shared) b.addSharedLibrary(.{
        .name = "scudoAllocator",
        .target = target,
        .optimize = optimize,
    }) else b.addStaticLibrary(.{
        .name = "scudoAllocator",
        .target = target,
        .optimize = optimize,
    });
    if (shared)
        lib.root_module.pic = true
    else
        lib.pie = true;
    lib.addIncludePath(b.path("include"));
    lib.addIncludePath(b.path("src"));
    lib.addCSourceFiles(.{
        .root = b.path("src"),
        .files = &.{
            "checksum.cpp",
            "common.cpp",
            "flags_parser.cpp",
            "flags.cpp",
            "mem_map.cpp",
            "release.cpp",
            "report.cpp",
            "string_utils.cpp",
            "timing.cpp",
            "wrappers_c.cpp",
            "wrappers_cpp.cpp",
        },
        .flags = &.{
            "-Werror=conversion",
            "-Wall",
            "-Wextra",
            "-pedantic",
            "-fno-exceptions",
        },
    });
    if (lib.rootModuleTarget().cpu.arch.isAARCH64()) {
        lib.addCSourceFile(.{
            .file = b.path("src/crc32_hw.cpp"),
        });
    }
    if (lib.rootModuleTarget().os.tag == .fuchsia) {
        lib.addCSourceFiles(.{
            .root = b.path("src"),
            .files = &.{
                "fuchsia.cpp",
                "mem_map_fuchsia.cpp",
            },
        });
    } else {
        lib.addCSourceFiles(.{
            .root = b.path("src"),
            .files = &.{
                "condition_variable_linux.cpp",
                "linux.cpp",
                "mem_map_linux.cpp",
                "report_linux.cpp",
            },
        });
    }
    const scudo_ostarget = if (lib.rootModuleTarget().os.tag == .fuchsia)
        "SCUDO_FUCHSIA"
    else if (lib.rootModuleTarget().isAndroid())
        "SCUDO_ANDROID"
    else
        "SCUDO_LINUX";
    lib.defineCMacro(scudo_ostarget, null);
    if (lib.rootModuleTarget().cpu.arch == .riscv64)
        lib.defineCMacro("SCUDO_RISCV64", null);
    if (optimize == .Debug) {
        lib.defineCMacro("SCUDO_DEBUG", null);
    }
    lib.linkLibC();

    mod_scudo.linkLibrary(lib);
    if (shared) b.installArtifact(lib);

    if (tools) buildExec(b, .{
        .lib = lib,
        .name = "compute_size_class_config",
        .files = &.{"tools/compute_size_class_config.cpp"},
    });
    buildtest(b, .{
        .lib = lib,
    });
}

fn buildExec(b: *std.Build, options: buildOptions) void {
    const exe = b.addExecutable(.{
        .name = options.name.?,
        .target = options.lib.root_module.resolved_target.?,
        .optimize = options.lib.root_module.optimize.?,
    });
    exe.addCSourceFiles(.{
        .files = options.files.?,
    });
    if (options.lib.rootModuleTarget().abi != .msvc) {
        exe.linkLibCpp();
    } else exe.linkLibC();
    b.installArtifact(exe);
}

fn buildtest(b: *std.Build, options: buildOptions) void {
    const test_runner = b.dependency("runner", .{}).path("test_runner.zig");

    const test_exe = b.addTest(.{
        .target = options.lib.root_module.resolved_target.?,
        .optimize = .Debug,
        .root_source_file = b.path("bindings/scudoAllocator.zig"),
        .test_runner = test_runner,
    });
    test_exe.linkLibrary(options.lib);

    const run_test = b.addRunArtifact(test_exe);
    const test_step = b.step("test", "Run test");
    test_step.dependOn(&run_test.step);
}

const buildOptions = struct {
    lib: *std.Build.Step.Compile,
    name: ?[]const u8 = null,
    files: ?[]const []const u8 = null,
};
