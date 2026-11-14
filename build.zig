const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Shared library module for DSS functionality.
    const dss_module = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Main command-line executable.
    const exe = b.addExecutable(.{
        .name = "dss",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.root_module.addImport("dss_core", dss_module);
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.addPassthruArgs();

    const run_step = b.step("run", "Build and run DSS");
    run_step.dependOn(&run_cmd.step);

    // `zig build test` compiles and runs tests in the core module.
    const unit_tests = b.addTest(.{
        .root_module = dss_module,
    });
    const run_tests = b.addRunArtifact(unit_tests);
    const test_step = b.step("test", "Run DSS unit tests");
    test_step.dependOn(&run_tests.step);
}
