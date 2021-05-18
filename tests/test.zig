const std = @import("std");

const zargo = @import("zargo");

const c = @cImport({
  @cInclude("GLFW/glfw3.h");
});

fn errorCallback(err: c_int, description: [*c]const u8) callconv(.C) void {
  std.debug.panic("Error: {s}\n", .{description});
}

fn keyCallback(win: ?*c.GLFWwindow, key: c_int, scancode: c_int, action: c_int, mods: c_int) callconv(.C) void {
  if (action != c.GLFW_PRESS) return;

  switch (key) {
    c.GLFW_KEY_ESCAPE => c.glfwSetWindowShouldClose(win, c.GL_TRUE),
    else => {},
  }
}

pub fn testOpenFile(allocator: *std.mem.Allocator, file_path: []const u8) !std.fs.File {
  const cwd = std.fs.cwd();

  var resolved_path = try std.fs.path.resolve(allocator, &[_][]const u8{file_path});
  defer allocator.free(resolved_path);

  return cwd.openFile(resolved_path, .{});
}

pub fn main() !u8 {
  _ = c.glfwSetErrorCallback(errorCallback);

  if (c.glfwInit() == c.GL_FALSE) {
    std.debug.warn("Failed to initialize GLFW\n", .{});
    return 1;
  }

  c.glfwWindowHint(c.GLFW_SAMPLES, 4);
  c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MAJOR, 3);
  c.glfwWindowHint(c.GLFW_CONTEXT_VERSION_MINOR, 2);
  c.glfwWindowHint(c.GLFW_OPENGL_FORWARD_COMPAT, c.GL_TRUE);
  c.glfwWindowHint(c.GLFW_OPENGL_PROFILE, c.GLFW_OPENGL_CORE_PROFILE);

  var window = c.glfwCreateWindow(800, 600, "test", null, null) orelse {
    std.debug.panic("unable to create window\n", .{});
  };

  _ = c.glfwSetKeyCallback(window, keyCallback);
  c.glfwMakeContextCurrent(window);
  c.glfwSwapInterval(1);

  var w: c_int = undefined;
  var h: c_int = undefined;
  c.glfwGetFramebufferSize(window, &w, &h);

  var e: zargo.Engine = undefined;
  try e.init(switch (std.builtin.os.tag) {
    .macos => .ogl_32,
    .windows => .ogl_43,
    else => .ogles_20,
  }, @intCast(u32, w), @intCast(u32, h), false);

  var tex = e.loadImage("test.png");
  std.debug.print("loaded texture: w = {}, h = {}, alpha= {}\n", .{tex.width, tex.height, tex.has_alpha});

  var angle: f32 = 0;
  var iangle: f32 = 0;

  var iw = @intCast(i32, w);
  var ih = @intCast(i32, h);

  var r1 = zargo.Rectangle{.x = @divTrunc(iw, 4) - 50,     .y = @divTrunc(ih, 4) - 50,     .width = 100, .height = 100};
  var r2 = zargo.Rectangle{.x = @divTrunc(iw * 3, 4) - 50, .y = @divTrunc(ih * 3, 4) - 50, .width = 100, .height = 100};
  while (c.glfwWindowShouldClose(window) == c.GL_FALSE) {
    e.clear([_]u8{0,0,0,255});
    e.fillRect(r1, [_]u8{255,0,0,255}, true);
    e.fillUnit(r2.transformation().rotate(angle), [_]u8{0,255,0,255}, true);
    e.drawImage(tex, tex.area().move(500, 400).transformation(),
      zargo.Transform.identity().rotate(iangle).compose(tex.area().transformation()), 255);
    angle = @rem((angle + 0.01), 2*3.14159);
    iangle = @rem((iangle + 0.001), 2*3.14159);

    c.glfwSwapBuffers(window);
    c.glfwPollEvents();
  }
  return 0;
}