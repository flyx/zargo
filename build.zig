const std = @import("std");
const Builder = std.build.Builder;
const pkgs = @import("deps.zig").pkgs;

const Artifacts = enum {
  library, tests, all
};

const ContextErrors = error {
  UnsupportedGLESVersion
};

const Context = struct {
  library_path: ?[]const u8,
  include_path: ?[]const u8,
  mode: std.builtin.Mode,
  target: std.zig.CrossTarget,
  artifacts: Artifacts,
  use_gles: u8,

  fn addDeps(self: Context, s: *std.build.LibExeObjStep) !void {
    s.setBuildMode(self.mode);
    s.setTarget(self.target);

    if (self.library_path) |value| {
      s.addLibPath(value);
    }
    if (self.include_path) |value| {
      s.addIncludeDir(value);
      var ft_path: [256]u8 = undefined;
      s.addIncludeDir(try std.fmt.bufPrint(&ft_path, "{s}/freetype2", .{value}));
    }

    s.linkLibC();
    s.linkSystemLibrary("epoxy");
    s.linkSystemLibrary("freetype");
    if (self.target.isDarwin()) {
      s.addFrameworkDir("/System/Library/Frameworks");
      s.linkFramework("OpenGL");
    } else if (self.target.isWindows()) {
      s.linkSystemLibrary("OpenGL32");
    } else {
      switch (self.use_gles) {
        0 => s.linkSystemLibrary("GL"),
        2 => s.linkSystemLibrary("GLESv2"),
        3 => s.linkSystemLibrary("GLESv3"),
        else => return ContextErrors.UnsupportedGLESVersion,
      }
    }

    s.addIncludeDir("src");
    s.addCSourceFile("src/stb_image.c", &[_][]const u8{
      "-isystem",
      "/Library/Developer/CommandLineTools/SDKs/MacOSX11.0.sdk",
      "-Wall",
      "-Wextra",
      "-Werror",
      "-Wno-sign-compare"
    });
  }
};

pub fn build(b: *Builder) !void {
  const context = Context{
    .mode = b.standardReleaseOptions(),
    .target = b.standardTargetOptions(.{}),
    .library_path = b.option([]const u8, "library_path", "search path for libraries"),
    .include_path = b.option([]const u8, "include_path", "include path for headers"),
    .artifacts = b.option(Artifacts, "artifacts", "`library`, `tests`, or `all`") orelse .all,
    .use_gles = b.option(u8, "gles", "`0`, `2` or `3`. use `0` (default) to link to normal OpenGL. ignored on Windows and macOS.") orelse 0,
  };

  const lib = b.addStaticLibrary("zargo", "src/libzargo.zig");
  try context.addDeps(lib);
  pkgs.addAllTo(lib);

  if (context.artifacts != .tests) {
    lib.install();
  }

  const exe = b.addExecutable("test", "tests/test.zig");
  try context.addDeps(exe);
  if (context.target.isWindows()) {
    exe.linkSystemLibrary("glfw3");
  } else {
    exe.linkSystemLibrary("glfw");
  }
  exe.addPackage(.{
    .name = "zargo",
    .path = "src/zargo.zig",
    .dependencies = &.{pkgs.zgl}
  });
  exe.strip = true;

  if (context.artifacts != .library) {
    exe.install();
  }

  const cexe = b.addExecutable("ctest", null);
  try context.addDeps(cexe);
  cexe.addIncludeDir("include");
  cexe.addCSourceFile("tests/test.c", &[_][]const u8{"-std=c99"});
  if (context.target.isWindows()) {
    cexe.linkSystemLibrary("glfw3");
  } else {
    cexe.linkSystemLibrary("glfw");
  }
  cexe.linkLibrary(lib);

  if (context.artifacts == .all) {
    cexe.install();
  }
}