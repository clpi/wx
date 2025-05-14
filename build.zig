const std = @import("std");

pub fn libtest(b: *std.Build, t: std.Build.ResolvedTarget) *std.Build.Step.Run {
    const tests = b.addTest(.{
        .root_source_file = b.path("src/root.zig"),
        .target = t,
        .optimize = .ReleaseFast,
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
    const tests = b.addTest(.{ .root_source_file = b.path("src/main.zig"), .target = t, .optimize = .ReleaseFast, .error_tracing = true, .link_libc = true, .link_libcpp = true, .omit_frame_pointer = true, .version = version });
    const run_exe_unit_tests = b.addRunArtifact(tests);
    return run_exe_unit_tests;
}

pub fn exeopts(b: *std.Build, t: std.Build.ResolvedTarget) *std.Build.Step.Compile {
    const exe = b.addExecutable(.{
        .name = "wx",
        .root_source_file = b.path("src/main.zig"),
        .target = t,
        .sanitize_thread = true,
        .single_threaded = false,
        .error_tracing = true,
        .link_libc = true,
        .version = version,
        .linkage = .dynamic,
        .strip = true,
        .pic = true,
        .optimize = .ReleaseFast,
    });
    b.installArtifact(exe);
    return exe;
}
pub fn libopts(b: *std.Build, t: std.Build.ResolvedTarget) *std.Build.Step.Compile {
    const lib = b.addStaticLibrary(.{
        .name = "wxlib",
        .version = version,
        .code_model = .default,
        .link_libc = true,
        .strip = true,
        .pic = true,
        .omit_frame_pointer = true,
        .single_threaded = false,
        .error_tracing = true,
        .sanitize_thread = true,
        .root_source_file = b.path("src/root.zig"),
        .optimize = .ReleaseFast,
        .target = t,
    });
    b.installArtifact(lib);
    return lib;
}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    _ = libopts(b, target);
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
}
