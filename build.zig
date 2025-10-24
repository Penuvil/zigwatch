const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const zigwatchMod = b.addModule("zigwatch", .{
        .root_source_file = .{ .cwd_relative = "src/root.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });

    const lib = b.addLibrary(.{
        .name = "zigwatch",
        .root_module = zigwatchMod,
    });

    b.installArtifact(lib);

    const example = b.addExecutable(.{ .name = "simple_example", .root_module = b.createModule(.{
        .root_source_file = .{ .cwd_relative = "examples/simple.zig" },
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    }) });

    example.linkLibrary(lib);
    example.root_module.addImport("zigwatch", zigwatchMod);
    b.installArtifact(example);

    b.default_step.dependOn(&lib.step);
    b.default_step.dependOn(&example.step);
}
