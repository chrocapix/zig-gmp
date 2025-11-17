const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const triple = target.result.linuxTriple(b.allocator) catch @panic("OOM");

    const gmp = b.addLibrary(.{
        .name = "gmp",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    b.installArtifact(gmp);
    gmp.installHeader(
        b.path(b.pathJoin(&.{ "upstream", triple, "gmp.h" })),
        "gmp.h",
    );

    const mod = gmp.root_module;
    mod.addIncludePath(b.path("upstream/gmp-6.3.0"));
    mod.addIncludePath(b.path(b.pathJoin(&.{ "upstream", triple })));
    mod.addIncludePath(b.path(b.pathJoin(&.{ "upstream", triple, "mpn" })));

    const file_flags = loadFileFlags(b.*, triple) catch |err| {
        std.debug.panic(
            "fatal error: failed to load zon file for target {s}: {t}",
            .{ triple, err },
        );
    };

    for (file_flags) |f| {
        const path = b.path(b.pathJoin(&.{ "upstream", f.file }));

        if (std.mem.endsWith(u8, f.file, ".c")) {
            mod.addCSourceFile(.{ .file = path, .flags = f.flags });
        } else if (std.mem.endsWith(u8, f.file, ".s")) {
            mod.addAssemblyFile(path);
        }
    }

    // TODO: remove toto
    const toto = b.addExecutable(.{
        .name = "toto",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path("toto.zig"),
        }),
    });
    toto.linkLibrary(gmp);
    const run_exe = b.addRunArtifact(toto);
    const run_step = b.step("toto", "Dummy test program");
    run_step.dependOn(&run_exe.step);
}

fn loadFileFlags(b: std.Build, triple: []const u8) ![]FileFlags {
    const file_name = try std.mem.concat(b.allocator, u8, &.{ "upstream/", triple, ".zon" });
    const file = try std.fs.cwd().openFile(file_name, .{});
    defer file.close();

    var file_reader = file.reader(&.{});
    const reader = &file_reader.interface;

    var alloc_writer: std.Io.Writer.Allocating = .init(b.allocator);
    defer alloc_writer.deinit();
    const writer = &alloc_writer.writer;

    _ = try reader.stream(writer, .unlimited);
    const content = try alloc_writer.toOwnedSliceSentinel(0);
    defer b.allocator.free(content);

    return std.zon.parse.fromSlice([]FileFlags, b.allocator, content, null, .{});
}

const FileFlags = struct {
    file: []const u8,
    flags: [][]const u8,
};
