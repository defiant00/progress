const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "progress",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // SDL2
    const sdl_path = "C:\\libs\\SDL2-2.30.1\\";
    exe.addIncludePath(.{ .path = sdl_path ++ "include" });
    exe.addLibraryPath(.{ .path = sdl_path ++ "lib\\x64" });
    exe.linkSystemLibrary("SDL2");
    exe.linkLibC();

    b.installArtifact(exe);
    b.installBinFile(sdl_path ++ "lib\\x64\\SDL2.dll", "SDL2.dll");

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
