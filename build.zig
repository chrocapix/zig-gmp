const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const triple = target.result.linuxTriple(b.allocator) catch @panic("OOM");

    std.debug.print("zig_gmp: target {s} optimize {t}\n", .{ triple, optimize });

    const gmp_lib = b.addLibrary(.{
        .name = "gmp",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });
    b.installArtifact(gmp_lib);
    const gmp_mod = b.addModule("gmp", .{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    });
    gmp_mod.linkLibrary(gmp_lib);

    gmp_lib.installHeader(
        b.path(b.pathJoin(&.{ "upstream", triple, "gmp.h" })),
        "gmp.h",
    );

    const mod = gmp_lib.root_module;
    mod.addIncludePath(b.path("upstream/gmp-6.3.0"));
    mod.addIncludePath(b.path(b.pathJoin(&.{ "upstream", triple })));
    mod.addIncludePath(b.path(b.pathJoin(&.{ "upstream", triple, "mpn" })));

    const file_flags = loadFileFlags(b, triple) catch |err| {
        std.debug.panic(
            "fatal error: failed to load zon file for target {s}: {t}",
            .{ triple, err },
        );
    };
    defer b.allocator.free(file_flags);

    for (file_flags) |f| {
        const path = b.path(b.pathJoin(&.{ "upstream", f.file }));

        if (std.mem.endsWith(u8, f.file, ".c")) {
            mod.addCSourceFile(.{ .file = path, .flags = f.flags });
        } else if (std.mem.endsWith(u8, f.file, ".s")) {
            mod.addAssemblyFile(path);
        }
    }
}

fn loadFileFlags(b: *std.Build, triple: []const u8) ![]FileFlags {
    const file_name = try std.mem.concat(b.allocator, u8, &.{ triple, ".zon" });
    defer b.allocator.free(file_name);
    const path = b.path("upstream").getPath3(b, null);
    const file = try path.openFile(file_name, .{});
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
