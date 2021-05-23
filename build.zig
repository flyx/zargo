const std = @import("std");
const Builder = std.build.Builder;
const pkgs = @import("deps.zig").pkgs;

const Artifacts = enum {
  library, tests, all
};

const Context = struct {
  library_path: ?[]const u8,
  include_path: ?[]const u8,
  mode: std.builtin.Mode,
  target: std.zig.CrossTarget,
  artifacts: Artifacts,

  fn addDeps(self: Context, s: *std.build.LibExeObjStep) void {
    s.setBuildMode(self.mode);
    s.setTarget(self.target);

    if (self.library_path) |value| {
      s.addLibPath(value);
    }
    if (self.include_path) |value| {
      s.addIncludeDir(value);
    }

    s.linkLibC();
    s.linkSystemLibrary("epoxy");
    s.linkSystemLibrary("freetype");
    if (self.target.isDarwin()) {
      s.addFrameworkDir("/System/Library/Frameworks");
      s.linkFramework("OpenGL");
      s.addIncludeDir("/usr/local/include/freetype2");
    } else if (self.target.isWindows()) {
      s.linkSystemLibrary("OpenGL32");
    } else {
      s.linkSystemLibrary("GL");
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

pub fn build(b: *Builder) void {
  const context = Context{
    .mode = b.standardReleaseOptions(),
    .target = b.standardTargetOptions(.{}),
    .library_path = b.option([]const u8, "library_path", "search path for libraries"),
    .include_path = b.option([]const u8, "include_path", "include path for headers"),
    .artifacts = b.option(Artifacts, "artifacts", "`library`, `tests`, or `all`") orelse .all,
  };

  const lib = b.addStaticLibrary("zargo", "src/libzargo.zig");
  context.addDeps(lib);
  pkgs.addAllTo(lib);

  if (context.artifacts != .tests) {
    lib.install();
  }

  const exe = b.addExecutable("test", "tests/test.zig");
  context.addDeps(exe);
  if (std.Target.current.os.tag == .windows) {
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
  context.addDeps(cexe);
  cexe.addIncludeDir("include");
  cexe.addCSourceFile("tests/test.c", &[_][]const u8{"-std=c99"});
  if (std.Target.current.os.tag == .windows) {
    cexe.linkSystemLibrary("glfw3");
  } else {
    cexe.linkSystemLibrary("glfw");
  }
  cexe.linkLibrary(lib);

  if (context.artifacts == .all) {
    cexe.install();
  }
}