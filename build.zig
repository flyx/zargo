const std = @import("std");
const builtin = @import("builtin");
const Builder = std.build.Builder;
const pkgs = @import("deps.zig").pkgs;

const Context = struct {
  library_path: ?[]const u8,
  include_path: ?[]const u8,
  mode: builtin.Mode,
  target: std.zig.CrossTarget,

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
    if (std.Target.current.os.tag.isDarwin()) {
      s.addFrameworkDir("/System/Library/Frameworks");
      s.linkFramework("OpenGL");
    } else if (std.Target.current.os.tag == .windows) {
      s.linkSystemLibrary("OpenGL32");
    } else {
      s.linkSystemLibrary("GL");
    }

    s.addIncludeDir("src");
    s.addCSourceFile("src/stb_image.c", &[_][]const u8{
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
    .include_path = b.option([]const u8, "include_path", "include path for headers")
  };

  const lib = b.addStaticLibrary("zargo", "src/libzargo.zig");
  context.addDeps(lib);
  pkgs.addAllTo(lib);
  lib.install();

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
  exe.install();
}