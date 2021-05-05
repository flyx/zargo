const std = @import("std");
const zargo = @import("zargo.zig");

export fn zargo_engine_init(window_width: u32, window_height: u32, debug: bool) ?*zargo.Engine {
  var e = std.heap.c_allocator.create(zargo.Engine) catch return null;
  errdefer std.heap.c_allocator.free(e);
  e.init(switch (std.builtin.os.tag) {
    .macos => .ogl_32, .windows => .ogl_43, else => .ogles_20,
  }, window_width, window_height, debug) catch return null;
  return e;
}