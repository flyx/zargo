const std = @import("std");
const Builder = std.build.Builder;
const pkgs = @import("deps.zig").pkgs;

fn addCCode(s: *std.build.LibExeObjStep) void {
  s.addIncludeDir("src");
  s.addCSourceFile("src/stb_image.c", &[_][]const u8{
    "-Isrc",
    "-Wall",
    "-Wextra",
    "-Werror",
    "-Wno-sign-compare"
  });
}

pub fn build(b: *Builder) void {
  const mode = b.standardReleaseOptions();

  const lib = b.addSharedLibrary("zargo", "src/libzargo.zig", b.version(0,1,0));
  lib.setBuildMode(mode);
  lib.addIncludeDir("/usr/local/include");
  lib.linkSystemLibrary("epoxy");
  lib.linkSystemLibrary("c");
  pkgs.addAllTo(lib);
  addCCode(lib);
  lib.install();

  const exe = b.addExecutable("test", "tests/test.zig");
  exe.setBuildMode(mode);
  exe.addIncludeDir("/usr/local/include");
  exe.linkSystemLibrary("c");
  exe.linkSystemLibrary("epoxy");
  exe.linkSystemLibrary("glfw");

  exe.addIncludeDir("/usr/local/include");
  if (std.Target.current.os.tag.isDarwin()) {
    exe.addFrameworkDir("/System/Library/Frameworks");
    exe.linkFramework("OpenGL");
  } else if (std.Target.current.os.tag == .windows) {
    exe.linkSystemLibrary("OpenGL32");
  } else {
    exe.linkSystemLibrary("GL");
  }
  addCCode(exe);
  exe.addPackage(.{
    .name = "zargo",
    .path = "src/zargo.zig",
    .dependencies = &.{pkgs.zgl}
  });
  exe.install();
}