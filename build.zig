const std = @import("std");

pub fn libtest(b: *std.Build, t: std.Build.ResolvedTarget) *std.Build.Step.Run {
    const tests = b.addTest(.{
        .root_module = b.createModule(.{ 
            .root_source_file = b.path("src/root.zig"),
            .target = t,
            .optimize = .ReleaseFast,
        }),
    });
    const run_lib_unit_tests = b.addRunArtifact(tests);
    return run_lib_unit_tests;
}

pub const version: std.SemanticVersion = .{
    .build = "0",
    .major = 0,
    .patch = 0,
    .minor = 0,
    .pre = "alpha",
};

pub fn exetest(b: *std.Build, t: std.Build.ResolvedTarget) *std.Build.Step.Run {
    const tests = b.addTest(.{ 
        .root_module = b.createModule(.{ 
            .root_source_file = b.path("src/main.zig"),
            .target = t,
            .optimize = .ReleaseFast,
        }), 
    });
    tests.root_module.error_tracing = true;
    tests.linkLibC();
    tests.linkLibCpp();
    tests.root_module.omit_frame_pointer = true;
    const run_exe_unit_tests = b.addRunArtifact(tests);
    return run_exe_unit_tests;
}

pub fn exeopts(b: *std.Build, t: std.Build.ResolvedTarget) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "wx",
        .root_module = b.createModule(.{ 
            .root_source_file = b.path("src/main.zig"),
            .target = t,
            .optimize = .ReleaseFast,
        }),
        .version = version,
        .linkage = .dynamic,
    });
    exe.pie = true;
    exe.root_module.strip = true;
    exe.root_module.sanitize_thread = false;
    exe.root_module.single_threaded = true;
    exe.root_module.omit_frame_pointer = true;
    exe.root_module.error_tracing = true;
    exe.linkLibC();
    b.installArtifact(exe);
    return exe;
}
pub fn libopts(b: *std.Build, t: std.Build.ResolvedTarget) *std.Build.Step.Compile {
    const lib = b.addSharedLibrary(.{
        .name = "wxlib",
        .version = version,
        .root_module = b.createModule(.{ 
            .root_source_file = b.path("src/root.zig"),
            .target = t,
            .optimize = .ReleaseFast,
        }),
    });
    lib.pie = true;
    lib.root_module.strip = true;
    lib.linkLibC();
    lib.root_module.omit_frame_pointer = true;
    lib.root_module.single_threaded = true;
    lib.root_module.error_tracing = true;
    lib.root_module.sanitize_thread = false;
    b.installArtifact(lib);
    return lib;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // _ = libopts(b, target);
    const exe = exeopts(b, target);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args|
        run_cmd.addArgs(args);

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&libtest(b, target).step);
    test_step.dependOn(&exetest(b, target).step);

    // Build a WASI WASM CLI that exercises opcodes
    const wasm_target = b.resolveTargetQuery(.{ .cpu_arch = .wasm32, .os_tag = .wasi });
    const opcodes_cli = b.addExecutable(.{
        .name = "opcodes_cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/opcodes_cli/main.zig"),
            .target = wasm_target,
            .optimize = .ReleaseSmall,
        }),
    });
    // WASI entry point; no libc needed
    b.installArtifact(opcodes_cli);

    const build_wasm = b.step("opcodes-wasm", "Build WASI opcodes CLI (.wasm)");
    build_wasm.dependOn(&opcodes_cli.step);
}
